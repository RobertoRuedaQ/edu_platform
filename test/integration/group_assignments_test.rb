require "test_helper"

# assignments (v1.23.0, item #6 of the MVP critical path: group work).
# Generalizes v1.22.0's per-student Submission to belong to a student XOR a
# SubmissionGroup. Publisher's per-student fan-out (v1.21.0) is UNCHANGED —
# a group grade is a bulk-set over those same rows (Assignments::GroupGrader),
# never a second grade store.
class GroupAssignmentsTest < ActionDispatch::IntegrationTest
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

    @grade_level = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado Grupal", level_number: 9) }
    @subject = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level, name: "Historia", code: "GRP-1") }

    @student_a = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Ana", last_name: "Uno", student_code: "GRP-001")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
    @student_b = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Beto", last_name: "Dos", student_code: "GRP-002")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
    @student_c = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Carla", last_name: "Tres", student_code: "GRP-003")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
    @student_unassigned = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Dario", last_name: "Suelto", student_code: "GRP-004")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
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

  def create_group_assignment!(title: "Investigación en equipo", due_date: Date.new(2026, 3, 20))
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments",
        params: { assignment: { title: title, due_date: due_date.iso8601, group_work: "1" } }
    end
    Assignments::Assignment.find_by!(institution_id: @institution.id, subject_id: @subject.id, title: title)
  end

  def publish!(assignment)
    as_teacher { post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/publish" }
    assignment.reload
  end

  def form_group!(assignment, name:, student_ids:)
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/submission_groups",
        params: { name: name, student_ids: student_ids }
    end
    Assignments::SubmissionGroup.find_by!(institution_id: @institution.id, assignment_id: assignment.id, name: name)
  end

  # --- forming groups ------------------------------------------------

  test "acceptance: the teacher marks group_work, forms groups, and a student lands in exactly one" do
    assignment = create_group_assignment!
    assert assignment.group_work?
    assignment = publish!(assignment)

    group = form_group!(assignment, name: "Equipo 1", student_ids: [ @student_a.id, @student_b.id ])
    assert_equal 2, group.students.count

    membership = Assignments::GroupMembership.find_by!(institution_id: @institution.id, assignment_id: assignment.id,
      student_id: @student_a.id)
    assert_equal group.id, membership.submission_group_id

    # exactly one group per student per assignment — the unique index guarantees it
    assert_equal 1, Assignments::GroupMembership.where(institution_id: @institution.id, assignment_id: assignment.id,
      student_id: @student_a.id).count
  end

  test "group_work is locked after publish — the toggle in an edit has no effect" do
    assignment = create_group_assignment!(title: "Trabajo bloqueado")
    assignment = publish!(assignment)
    assert assignment.group_work?

    as_teacher do
      patch "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}",
        params: { assignment: { group_work: "0" } }
    end
    assert assignment.reload.group_work?, "group_work must stay locked once published"
  end

  # --- shared submission ------------------------------------------------

  test "acceptance: any group member can submit/edit the SAME shared entrega" do
    assignment = publish!(create_group_assignment!)
    form_group!(assignment, name: "Equipo 1", student_ids: [ @student_a.id, @student_b.id ])

    user_a = within_tenant(@institution) { link_as_student_user!(@institution, student: @student_a, email: "a-#{SecureRandom.hex(4)}@member.test", name: "Ana") }
    user_b = within_tenant(@institution) { link_as_student_user!(@institution, student: @student_b, email: "b-#{SecureRandom.hex(4)}@member.test", name: "Beto") }

    sign_in_as(user_a, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Borrador de Ana" }

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id)
    assert_equal "Borrador de Ana", submission.body
    assert_nil submission.student_id
    assert_not_nil submission.submission_group_id

    sign_in_as(user_b, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Versión final de Beto" }

    assert_equal 1, Assignments::Submission.where(institution_id: @institution.id, assignment_id: assignment.id).count,
      "editing the shared entrega must never create a second row"
    assert_equal "Versión final de Beto", submission.reload.body
    assert_equal user_b.id, submission.submitted_by_user_id
  end

  test "a guardian submits on behalf of a group member (B1) — same shared entrega" do
    assignment = publish!(create_group_assignment!)
    form_group!(assignment, name: "Equipo 1", student_ids: [ @student_a.id, @student_b.id ])

    guardian_user = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @student_a, email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente de Ana")
    end
    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    post "/portal/guardian/students/#{@student_a.id}/assignments/#{assignment.id}/submission",
      params: { body: "Entrego por mi hija" }

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id)
    assert_equal guardian_user.id, submission.submitted_by_user_id
    assert_nil submission.student_id
    assert_equal Assignments::GroupMembership.find_by!(assignment_id: assignment.id, student_id: @student_a.id).submission_group_id,
      submission.submission_group_id
  end

  test "a student with no group yet sees the empty state and cannot submit" do
    assignment = publish!(create_group_assignment!)
    form_group!(assignment, name: "Equipo 1", student_ids: [ @student_a.id, @student_b.id ])
    # @student_c and @student_unassigned remain ungrouped.

    user_c = within_tenant(@institution) { link_as_student_user!(@institution, student: @student_c, email: "c-#{SecureRandom.hex(4)}@member.test", name: "Carla") }
    sign_in_as(user_c, institution: @institution, password: "password-123456")

    get "/portal/student/assignments/#{assignment.id}"
    assert_response :success
    assert_match(/Aún no tienes grupo asignado/, response.body)
    assert_select "form", count: 0

    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "No debería poder" }
    assert_response :not_found
    assert_empty Assignments::Submission.where(assignment_id: assignment.id)
  end

  test "a student cannot edit another group's entrega (relation-gated, 404)" do
    assignment = publish!(create_group_assignment!)
    group_1 = form_group!(assignment, name: "Equipo 1", student_ids: [ @student_a.id ])
    form_group!(assignment, name: "Equipo 2", student_ids: [ @student_b.id, @student_c.id ])

    user_b = within_tenant(@institution) { link_as_student_user!(@institution, student: @student_b, email: "b2-#{SecureRandom.hex(4)}@member.test", name: "Beto") }
    sign_in_as(user_b, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Entrega de equipo 2" }

    # student_b's own group (Equipo 2) got a submission — group_1 (Equipo 1) did not.
    assert_nil Assignments::Submission.find_by(submission_group_id: group_1.id)
    assert_not_nil Assignments::Submission.find_by(institution_id: @institution.id, assignment_id: assignment.id,
      submitted_by_user_id: user_b.id)
  end

  # --- grading -----------------------------------------------------------

  test "acceptance: a group grade bulk-sets every member's Assessment; override changes only one; re-applying resets all" do
    assignment = publish!(create_group_assignment!)
    group = form_group!(assignment, name: "Equipo 1", student_ids: [ @student_a.id, @student_b.id, @student_c.id ])

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { group_scores: { group.id => "4.0" } }
    end

    [ @student_a, @student_b, @student_c ].each do |student|
      assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
        enrollments: { student_id: student.id })
      assert_equal BigDecimal("4.0"), assessment.score
    end

    # override just one member
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student_b.id => "2.0" } }
    end
    assert_equal BigDecimal("2.0"), Schedules::Assessment.joins(:enrollment)
      .find_by!(assignment_id: assignment.id, enrollments: { student_id: @student_b.id }).score
    assert_equal BigDecimal("4.0"), Schedules::Assessment.joins(:enrollment)
      .find_by!(assignment_id: assignment.id, enrollments: { student_id: @student_a.id }).score

    # re-applying the group grade resets everyone, including the override
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { group_scores: { group.id => "5.0" } }
    end
    [ @student_a, @student_b, @student_c ].each do |student|
      assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
        enrollments: { student_id: student.id })
      assert_equal BigDecimal("5.0"), assessment.score
    end
  end

  test "grading is unaffected for a student with no group yet" do
    assignment = publish!(create_group_assignment!)
    form_group!(assignment, name: "Equipo 1", student_ids: [ @student_a.id ])

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { scores: { @student_unassigned.id => "3.5" } }
    end
    assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
      enrollments: { student_id: @student_unassigned.id })
    assert_equal BigDecimal("3.5"), assessment.score
  end

  # --- DB-level invariant ------------------------------------------------

  test "the DB itself rejects a submission row with neither identity, and with both" do
    within_tenant(@institution) do
      assignment = Assignments::Assignment.create!(institution: @institution, subject: @subject, title: "x",
        due_date: Date.new(2026, 5, 1), status: "draft")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) do
          ActiveRecord::Base.connection.execute(<<~SQL)
            INSERT INTO submissions (id, institution_id, assignment_id, body, submitted_at, created_at, updated_at)
            VALUES (gen_random_uuid(), '#{@institution.id}', '#{assignment.id}', 'x', now(), now(), now())
          SQL
        end
      end

      group = Assignments::SubmissionGroup.create!(institution: @institution, assignment: assignment, name: "G")
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) do
          ActiveRecord::Base.connection.execute(<<~SQL)
            INSERT INTO submissions (id, institution_id, assignment_id, student_id, submission_group_id, body, submitted_at, created_at, updated_at)
            VALUES (gen_random_uuid(), '#{@institution.id}', '#{assignment.id}', '#{@student_a.id}', '#{group.id}', 'x', now(), now(), now())
          SQL
        end
      end
    end
  end

  # --- regression: individual assignments unaffected ---------------------

  test "REGRESSION: a non-group assignment still works exactly like v1.22.0" do
    assignment = publish!(create_group_assignment!(title: "Individual").tap { |a| a.update_columns(group_work: false) })
    assert_not assignment.group_work?

    student_user = within_tenant(@institution) { link_as_student_user!(@institution, student: @student_a, email: "solo-#{SecureRandom.hex(4)}@member.test", name: "Ana") }
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    post "/portal/student/assignments/#{assignment.id}/submission", params: { body: "Entrega individual" }

    submission = Assignments::Submission.find_by!(institution_id: @institution.id, assignment_id: assignment.id)
    assert_equal @student_a.id, submission.student_id
    assert_nil submission.submission_group_id
  end

  # --- cross-tenant --------------------------------------------------

  test "cross-tenant: a submission group seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "grp-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      grade_level = build_grade_level!(other_institution, name: "Grado Otro", level_number: 9)
      subject = build_subject!(other_institution, grade_level: grade_level, name: "Materia Ajena", code: "AJENA-GRP")
      assignment = Assignments::Assignment.create!(institution: other_institution, subject: subject,
        title: "Tarea ajena", due_date: Date.new(2026, 4, 1), status: "published", published_at: Time.current,
        group_work: true)
      Assignments::SubmissionGroup.create!(institution: other_institution, assignment: assignment, name: "Grupo Ajeno")
    end

    assignment = publish!(create_group_assignment!)
    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_no_match(/Grupo Ajeno/, response.body)
    end

    within_tenant(@institution) do
      assert_empty Assignments::SubmissionGroup.where(institution_id: other_institution.id)
    end
  end
end
