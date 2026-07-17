require "test_helper"

# assignments (v1.22.0, item #6 of the MVP critical path, slice 2/4: text
# submission). The FIRST write from a portal — gated by RELATION
# (StudentSelfScope/GuardianScope composed with Assignments::StudentView),
# never RBAC. Grading and submitting are independent axes: submitting never
# creates a grade, grading never requires a submission — paired only at
# read time (Assignments::GradingView).
class SubmissionsTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_grade_level!(institution, name:, level_number:)
    GroupManagement::GradeLevel.create!(institution: institution, name: name, level_number: level_number)
  end

  def build_subject!(institution, grade_level:, name:, code:, term: "2026-1")
    Schedules::Subject.create!(institution: institution, grade_level: grade_level, name: name, code: code, term: term)
  end

  def build_student!(institution, first_name:, last_name:, student_code:)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: student_code, entry_year: 2023)
  end

  def enroll!(institution, student:, subject:, active_term:)
    Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      term: active_term.code, academic_term: active_term, status: "enrolled")
  end

  def link_as_student_user!(institution, student:, email:, name:)
    user = Core::User.create!(email: email, name: name, password: "password-123456")
    institution.memberships.create!(user: user)
    student.update!(user: user)
    user
  end

  def link_as_guardian!(institution, student:, email:, name:)
    user = Core::User.create!(email: email, name: name, password: "password-123456")
    institution.memberships.create!(user: user)
    Core::GuardianStudent.create!(institution: institution, guardian_user_id: user.id, student: student,
      relationship: "madre", status: "active")
    user
  end

  setup do
    @user, @institution = sign_in_as_member # assignments entitled by default

    @active_term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    @grade_level = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado Sub", level_number: 9) }
    @subject = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level, name: "Biología", code: "SUB-1") }
    @other_subject = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level, name: "Química", code: "SUB-2") }

    @student = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Valentina", last_name: "Suárez", student_code: "SUB-001")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
    @other_student = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Otro", last_name: "Estudiante", student_code: "SUB-002")
      enroll!(@institution, student: s, subject: @other_subject, active_term: @active_term)
      s
    end
  end

  def as_teacher(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[assignment.manage],
                                     scope_type: :grade_level, scope_id: @grade_level.id),
      &block
    )
  end

  def create_and_publish_assignment!(subject: @subject, title: "Ensayo de fotosíntesis", due_date: Date.new(2026, 3, 10))
    as_teacher do
      post "/assignments/subjects/#{subject.id}/assignments",
        params: { assignment: { title: title, due_date: due_date.iso8601 } }
    end
    assignment = Assignments::Assignment.find_by!(institution_id: @institution.id, subject_id: subject.id, title: title)
    as_teacher { post "/assignments/subjects/#{subject.id}/assignments/#{assignment.id}/publish" }
    assignment.reload
  end

  test "acceptance: a student submits text on their own published assignment, and the teacher sees it" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "La fotosíntesis convierte luz en energía." }
    assert_redirected_to portal_student_assignment_path(assignment)

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal "La fotosíntesis convierte luz en energía.", submission.body
    assert_equal student_user.id, submission.submitted_by_user_id

    # Switch the session back to the teacher (@user) — sign_in_as above
    # replaced the active browser session with the student's; with_grants
    # only edits @user's RoleAssignment rows, it never re-authenticates.
    sign_in_as(@user, institution: @institution, password: "password-123456")
    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_match(/La fotosíntesis convierte luz en energía\./, response.body)
    end
  end

  test "acceptance: a guardian submits on behalf of their child (B1) — attribution records the guardian, ownership stays the student's" do
    assignment = create_and_publish_assignment!
    guardian_user = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @student, email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente")
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    post "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}/submission",
      params: { body: "Entrega hecha por la mamá." }
    assert_redirected_to portal_guardian_student_assignment_path(@student, assignment)

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal guardian_user.id, submission.submitted_by_user_id
    assert_equal @student.id, submission.student_id, "the submission belongs to the student regardless of who typed it"
  end

  test "a student cannot submit on an assignment outside their own enrolled subjects" do
    assignment = create_and_publish_assignment! # published for @subject, @other_student is NOT enrolled in it
    other_student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @other_student, email: "otherstudent-#{SecureRandom.hex(4)}@member.test", name: "Otro")
    end

    sign_in_as(other_student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "No debería poder" }
    assert_response :not_found
    assert_empty Assignments::Submission.where(assignment_id: assignment.id)
  end

  test "a guardian cannot submit for a student who is not their child" do
    assignment = create_and_publish_assignment!
    unrelated_guardian = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @other_student, email: "unrelated-#{SecureRandom.hex(4)}@member.test", name: "Ajeno")
    end

    sign_in_as(unrelated_guardian, institution: @institution, password: "password-123456")
    post "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}/submission",
      params: { body: "No debería poder" }
    assert_response :not_found
    assert_empty Assignments::Submission.where(assignment_id: assignment.id)
  end

  test "editing/resubmitting is last-write-wins: exactly one submission per (assignment, student)" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student2-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Primer intento" }
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Segundo intento, mejor" }

    submissions = Assignments::Submission.where(institution_id: @institution.id, assignment_id: assignment.id, student_id: @student.id)
    assert_equal 1, submissions.count, "resubmitting must never duplicate"
    assert_equal "Segundo intento, mejor", submissions.sole.body
  end

  test "a student cannot submit on a draft assignment" do
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments", params: { assignment: { title: "Borrador", due_date: "2026-04-01" } }
    end
    draft = Assignments::Assignment.find_by!(institution_id: @institution.id, subject_id: @subject.id, title: "Borrador")

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student3-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{draft.id}/submission", params: { body: "No debería poder" }
    assert_response :not_found
    assert_empty Assignments::Submission.where(assignment_id: draft.id)
  end

  test "a student cannot submit on an archived assignment" do
    assignment = create_and_publish_assignment!
    as_teacher { post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/archive" }

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student4-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "No debería poder" }
    assert_response :not_found
    assert_empty Assignments::Submission.where(assignment_id: assignment.id)
  end

  test "a late submission is accepted and flagged, never blocked" do
    assignment = create_and_publish_assignment!(due_date: Date.new(2020, 1, 1)) # already in the past
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student5-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Tarde pero llegó" }
    assert_response :redirect

    submission = Assignments::Submission.find_by!(assignment_id: assignment.id, student_id: @student.id)
    assert submission.late?, "a submission after due_date must be flagged late"

    get "/portal/student/assignments/#{assignment.id}"
    assert_response :success
    assert_match(/tardía/, response.body)
  end

  test "grading and submitting are independent axes: grading works with no submission, and vice versa" do
    assignment = create_and_publish_assignment!

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student.id => "4.0" } }
    end
    assert_equal BigDecimal("4.0"), Schedules::Assessment.find_by!(assignment_id: assignment.id).score
    assert_nil Assignments::Submission.find_by(assignment_id: assignment.id, student_id: @student.id)

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student6-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Entrego sin que afecte mi nota" }

    assert_equal BigDecimal("4.0"), Schedules::Assessment.find_by!(assignment_id: assignment.id).score,
      "submitting must never change the already-recorded grade"
  end

  test "only text — no attachment field exists on the submission form" do
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student7-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")

    get "/portal/student/assignments/#{assignment.id}"
    assert_response :success
    assert_select "input[type=file]", count: 0
  end

  test "entitlement gate #1: not entitled still lets a portal submission through (accepted gap, same as other portal writes reads)" do
    assignment = create_and_publish_assignment!
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "assignments" })
    entitlement.revoke!

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student8-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Sigue funcionando" }
    assert_response :redirect # NOT forbidden — Portals::* is never registered in Entitlement::Registry
    assert_not_nil Assignments::Submission.find_by(institution_id: @institution.id, assignment_id: assignment.id,
      student_id: @student.id)
  end

  test "cross-tenant: a submission seeded in a different institution never leaks into the teacher's view" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "sub-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      grade_level = build_grade_level!(other_institution, name: "Grado Otro", level_number: 9)
      subject = build_subject!(other_institution, grade_level: grade_level, name: "Materia Ajena", code: "AJENA-SUB")
      assignment = Assignments::Assignment.create!(institution: other_institution, subject: subject,
        title: "Tarea ajena", due_date: Date.new(2026, 4, 1), status: "published", published_at: Time.current)
      student = build_student!(other_institution, first_name: "Fantasma", last_name: "Ajeno", student_code: "GHOST-SUB")
      Assignments::Submission.create!(institution: other_institution, assignment: assignment, student: student,
        body: "Contenido ajeno", submitted_at: Time.current)
    end

    assignment = create_and_publish_assignment!
    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_no_match(/Contenido ajeno/, response.body)
    end

    within_tenant(@institution) do
      assert_empty Assignments::Submission.where(institution_id: other_institution.id)
    end
  end

  # S3b (v1.30.0): one "entregas" usage event per Submission saved, and
  # resubmitting (upsert, same row/id) never re-emits.
  test "S3b: submitting emits one usage event, and resubmitting never duplicates it" do
    ControlPlane::Addon.find_by!(key: "assignments").update!( # sign_in_as_member already seeded this, unmetered
      metered: true, unit: "entregas", included_quota: 50, overage_unit_price_cents: 10
    )
    assignment = create_and_publish_assignment!
    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student-s3b-#{SecureRandom.hex(4)}@member.test", name: "Valentina")
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Primer intento" }
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Segundo intento" }

    events = ControlPlane::UsageEvent.where(institution_id: @institution.id)
    assert_equal 1, events.count
    assert_equal "entregas", events.sole.unit
  end
end
