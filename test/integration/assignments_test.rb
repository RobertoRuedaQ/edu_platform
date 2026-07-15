require "test_helper"

# assignments (v1.21.0, item #6 of the MVP critical path, slice 1/4: publish
# + view + grade directly). The grade lives ONLY in schedules::Assessment —
# an assignment is a template that fans out to one Assessment per roster
# student on publish (Assignments::Publisher); grading UPDATES that same
# row (Assignments::GradeRecorder), never a parallel store.
class AssignmentsTest < ActionDispatch::IntegrationTest
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

  setup do
    @user, @institution = sign_in_as_member # assignments entitled by default (grant_full_entitlements)

    @active_term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    @grade_level_a = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado 9 A-scope", level_number: 9) }
    @grade_level_b = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado 9 B-scope", level_number: 10) }

    @subject_a = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level_a, name: "Álgebra", code: "MAT-ASG-A") }
    @subject_b = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level_b, name: "Física", code: "MAT-ASG-B") }

    @student_in_subject = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Valentina", last_name: "Suárez", student_code: "ASG-001")
      enroll!(@institution, student: s, subject: @subject_a, active_term: @active_term)
      s
    end
    @student_not_enrolled = within_tenant(@institution) do
      build_student!(@institution, first_name: "Sin", last_name: "Matricula", student_code: "ASG-002")
    end
  end

  def as_teacher(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[assignment.manage],
                                     scope_type: :grade_level, scope_id: @grade_level_a.id),
      &block
    )
  end

  def as_plain_staff(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[grades.read],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def create_assignment!(subject: @subject_a, title: "Ensayo sobre funciones", due_date: Date.new(2026, 3, 15))
    as_teacher do
      post "/assignments/subjects/#{subject.id}/assignments",
        params: { assignment: { title: title, instructions: "Escribir 2 páginas.", due_date: due_date.iso8601 } }
    end
    Assignments::Assignment.find_by!(institution_id: @institution.id, subject_id: subject.id, title: title)
  end

  test "creating an assignment starts as a draft with no fanned-out grades" do
    assignment = create_assignment!
    assert_equal "draft", assignment.status
    assert_equal Date.new(2026, 3, 15), assignment.due_date
    assert_empty Schedules::Assessment.where(assignment_id: assignment.id)
  end

  test "acceptance: publishing fans out one Assessment per roster student, ungraded" do
    assignment = create_assignment!

    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/publish" }

    assignment.reload
    assert_equal "published", assignment.status
    assert_not_nil assignment.published_at

    assessment = Schedules::Assessment.find_by!(institution_id: @institution.id, assignment_id: assignment.id)
    assert_nil assessment.score, "a freshly-published assignment must start ungraded, never a zero"
    assert_equal @student_in_subject.id, assessment.enrollment.student_id

    # The student NOT enrolled in the subject never got a row at all.
    assert_equal 1, Schedules::Assessment.where(assignment_id: assignment.id).count
  end

  test "an ungraded fanned-out assessment does not break ReportCards::Computation" do
    assignment = create_assignment!
    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/publish" }

    result = ReportCards::Computation.call(student: @student_in_subject, academic_term: @active_term, institution: @institution)
    assert_empty result.lines, "a subject with only an ungraded assessment must contribute no line, never a zero"
  end

  test "acceptance: grading writes to the SAME gradebook row report_cards reads — never a duplicate" do
    assignment = create_assignment!
    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/publish" }

    as_teacher do
      post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student_in_subject.id => "4.5" } }
    end

    assert_equal 1, Schedules::Assessment.where(assignment_id: assignment.id).count, "grading must never duplicate the gradebook row"
    assessment = Schedules::Assessment.find_by!(institution_id: @institution.id, assignment_id: assignment.id)
    assert_equal BigDecimal("4.5"), assessment.score

    result = ReportCards::Computation.call(student: @student_in_subject, academic_term: @active_term, institution: @institution)
    assert_equal 1, result.lines.size
    assert_equal BigDecimal("4.5"), result.lines.first.average
  end

  test "re-grading updates the existing row instead of creating a second one" do
    assignment = create_assignment!
    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/publish" }

    as_teacher do
      post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student_in_subject.id => "3.0" } }
      post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student_in_subject.id => "4.0" } }
    end

    assert_equal 1, Schedules::Assessment.where(assignment_id: assignment.id).count
    assert_equal BigDecimal("4.0"), Schedules::Assessment.find_by!(assignment_id: assignment.id).score
  end

  test "three-layer roster: the roster excludes a student not enrolled in the subject/active term" do
    assignment = create_assignment!
    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/publish" }

    as_teacher do
      get "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_match(/Valentina Suárez/, response.body)
      assert_no_match(/Sin Matricula/, response.body)
    end
  end

  test "a teacher scoped to grade_level A cannot manage assignments for subject B (403)" do
    as_teacher do
      get "/assignments/subjects/#{@subject_b.id}/assignments"
      assert_response :forbidden

      post "/assignments/subjects/#{@subject_b.id}/assignments",
        params: { assignment: { title: "X", due_date: "2026-04-01" } }
      assert_response :forbidden
    end
  end

  test "the subjects index shows only the actor's own scope" do
    as_teacher do
      get "/assignments/subjects"
      assert_response :success
      assert_match(/Álgebra/, response.body)
      assert_no_match(/Física/, response.body)
    end
  end

  test "supervision RBAC: without assignment.manage, 403 and no nav tile" do
    as_plain_staff do
      get "/assignments/subjects"
      assert_response :forbidden

      get "/"
      assert_select "a.app-nav__link", text: "Tareas", count: 0
    end
  end

  test "grading before publishing is rejected — a draft has nothing in the gradebook yet" do
    assignment = create_assignment!

    as_teacher do
      post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student_in_subject.id => "5.0" } }
    end

    assert_empty Schedules::Assessment.where(assignment_id: assignment.id)
  end

  test "a draft can be deleted, but a published assignment cannot (must be archived instead)" do
    draft = create_assignment!(title: "Borrador descartable")
    as_teacher { delete "/assignments/subjects/#{@subject_a.id}/assignments/#{draft.id}" }
    assert_nil Assignments::Assignment.find_by(id: draft.id)

    published = create_assignment!(title: "Ya publicada")
    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{published.id}/publish" }
    as_teacher { delete "/assignments/subjects/#{@subject_a.id}/assignments/#{published.id}" }
    assert_not_nil Assignments::Assignment.find_by(id: published.id), "a published assignment must never hard-delete"
    assert_equal "published", published.reload.status

    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{published.id}/archive" }
    assert_equal "archived", published.reload.status
    assert_not_nil Schedules::Assessment.find_by(assignment_id: published.id), "archiving must never touch already-fanned-out grades"
  end

  test "portal (student): sees only published assignments, with their own grade from the shared gradebook" do
    assignment = create_assignment!
    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/publish" }
    as_teacher do
      post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student_in_subject.id => "4.2" } }
    end
    draft = create_assignment!(title: "Todavía no publicada")

    student_user = within_tenant(@institution) do
      user = Core::User.create!(email: "student-#{SecureRandom.hex(4)}@member.test", name: "Valentina",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      @student_in_subject.update!(user: user)
      user
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/assignments"
    assert_response :success
    assert_match(/Ensayo sobre funciones/, response.body)
    assert_match(/4\.2/, response.body)
    assert_no_match(/Todavía no publicada/, response.body)
  end

  test "portal (guardian): sees only their child's published assignments, never another family's" do
    assignment = create_assignment!
    as_teacher { post "/assignments/subjects/#{@subject_a.id}/assignments/#{assignment.id}/publish" }

    guardian_user = within_tenant(@institution) do
      user = Core::User.create!(email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente",
        password: "password-123456")
      @institution.memberships.create!(user: user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: user.id, student: @student_in_subject,
        relationship: "madre", status: "active")
      user
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/students/#{@student_in_subject.id}/assignments"
    assert_response :success
    assert_match(/Ensayo sobre funciones/, response.body)

    get "/portal/guardian/students/#{@student_not_enrolled.id}/assignments"
    assert_response :not_found
  end

  test "entitlement gate #1 runs before RBAC gate #2: not entitled shows the friendly module page" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "assignments" })
    entitlement.revoke!

    as_teacher do
      get "/assignments/subjects"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "cross-tenant: a subject/assignment seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "asg-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      grade_level = build_grade_level!(other_institution, name: "Grado Otro", level_number: 9)
      subject = build_subject!(other_institution, grade_level: grade_level, name: "Materia Ajena", code: "AJENA-1")
      Assignments::Assignment.create!(institution: other_institution, subject: subject, title: "Tarea ajena",
        due_date: Date.new(2026, 4, 1), status: "draft")
    end

    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[assignment.manage],
                                     scope_type: :institution, scope_id: nil)
    ) do
      get "/assignments/subjects"
      assert_response :success
      assert_no_match(/Materia Ajena/, response.body)
    end

    within_tenant(@institution) do
      assert_empty Assignments::Assignment.where(institution_id: other_institution.id)
    end
  end
end
