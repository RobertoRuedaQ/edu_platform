require "test_helper"

# assignments (v1.26.0, item #6 of the MVP critical path, slice 4/4:
# rúbricas — CLOSES the assignments track). A rubric NEVER stores the
# grade — it's a producer toward schedules::Assessment via
# Assignments::RubricGrader/GroupRubricGrader (which reuse GradeRecorder/
# GroupGrader, v1.21.0/v1.23.0, unchanged). The rubric STRUCTURE freezes
# as an immutable jsonb snapshot on the Assignment at publish time (same
# molde as ControlPlane::Subscription#price_tiers_snapshot/ReportCards'
# lines_snapshot) — editing the live template library afterward never
# touches an already-published assignment.
class RubricsTest < ActionDispatch::IntegrationTest
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

    @grade_level = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado Rub", level_number: 9) }
    @subject = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_level, name: "Ética", code: "RUB-1") }

    @student = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Mateo", last_name: "Ponce", student_code: "RUB-001")
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

  # --- rubric library helpers ---------------------------------------------

  def create_template!(name: "Ensayo argumentativo")
    as_teacher { post "/assignments/rubric_templates", params: { rubric_template: { name: name } } }
    Assignments::RubricTemplate.find_by!(institution_id: @institution.id, authored_by_user_id: @user.id, name: name)
  end

  def add_criterion!(template, name:, weight:)
    as_teacher do
      post "/assignments/rubric_templates/#{template.id}/rubric_criteria",
        params: { rubric_criterion: { name: name, weight: weight } }
    end
    template.rubric_criteria.reload.find_by!(name: name)
  end

  def add_level!(template, label:, points:)
    as_teacher do
      post "/assignments/rubric_templates/#{template.id}/rubric_levels",
        params: { rubric_level: { label: label, points: points } }
    end
    template.rubric_levels.reload.find_by!(label: label)
  end

  def set_descriptor!(template, criterion, level, text)
    as_teacher do
      patch "/assignments/rubric_templates/#{template.id}/cell_descriptors",
        params: { descriptors: { criterion.id => { level.id => text } } }
    end
  end

  # Two criteria (weight 2 and 1), three levels (0/3/5 points) — a template
  # simple enough to hand-verify the arithmetic.
  def build_standard_template!
    template = create_template!
    content = add_criterion!(template, name: "Contenido", weight: "2.0")
    form = add_criterion!(template, name: "Forma", weight: "1.0")
    incompleto = add_level!(template, label: "Incompleto", points: "0.0")
    bueno = add_level!(template, label: "Bueno", points: "3.0")
    excelente = add_level!(template, label: "Excelente", points: "5.0")
    set_descriptor!(template, content, excelente, "Argumenta con evidencia sólida")
    { template: template, content: content, form: form, incompleto: incompleto, bueno: bueno, excelente: excelente }
  end

  def create_rubric_assignment!(template:, title: "Ensayo sobre ética", due_date: Date.new(2026, 3, 10), group_work: false)
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments",
        params: { assignment: { title: title, due_date: due_date.iso8601, evaluation_method: "rubric",
          rubric_template_id: template.id, group_work: group_work ? "1" : "0" } }
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

  # --- calculation ---------------------------------------------------------

  test "acceptance: grading by rubric computes the score and writes it ONLY to schedules::Assessment" do
    parts = build_standard_template!
    assignment = publish!(create_rubric_assignment!(template: parts[:template]))

    # Contenido (weight 2, Excelente=5) + Forma (weight 1, Bueno=3):
    # (5*2 + 3*1) / (5*2 + 5*1) * 5 = 13/15*5 = 4.333... -> 4.3
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { rubric_evaluations: { @student.id => {
          parts[:content].id => parts[:excelente].id,
          parts[:form].id => parts[:bueno].id
        } } }
    end

    assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
      enrollments: { student_id: @student.id })
    assert_equal BigDecimal("4.3"), assessment.score

    evaluation = Assignments::RubricEvaluation.find_by!(institution_id: @institution.id, assignment_id: assignment.id,
      student_id: @student.id)
    assert_equal parts[:excelente].id, evaluation.levels_by_criterion[parts[:content].id.to_s]

    # The management show page renders the interactive grading grid
    # (already-picked levels checked) without error.
    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_match(/Contenido/, response.body)
      assert_match(/Excelente/, response.body)
    end

    # Re-grading updates the SAME rows — never a second Assessment/evaluation.
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { rubric_evaluations: { @student.id => {
          parts[:content].id => parts[:bueno].id,
          parts[:form].id => parts[:bueno].id
        } } }
    end
    assert_equal 1, Schedules::Assessment.where(assignment_id: assignment.id, enrollment_id: assessment.enrollment_id).count
    assert_equal 1, Assignments::RubricEvaluation.where(assignment_id: assignment.id, student_id: @student.id).count
    assert_equal BigDecimal("3.0"), assessment.reload.score # (3*2+3*1)/(5*2+5*1)*5 = 15/15*5
  end

  test "weights that do not sum to 100 still produce the expected ratio" do
    template = create_template!
    a = add_criterion!(template, name: "A", weight: "3.0")
    b = add_criterion!(template, name: "B", weight: "7.0")
    low = add_level!(template, label: "Bajo", points: "1.0")
    high = add_level!(template, label: "Alto", points: "4.0")
    assignment = publish!(create_rubric_assignment!(template: template))

    # (1*3 + 4*7) / (4*3 + 4*7) * 5 = 31/40*5 = 3.875 -> 3.9 (weights sum to 10, not 100)
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { rubric_evaluations: { @student.id => { a.id => low.id, b.id => high.id } } }
    end

    assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
      enrollments: { student_id: @student.id })
    assert_equal BigDecimal("3.9"), assessment.score
  end

  test "an incomplete evaluation (a criterion with no level picked) writes no score" do
    parts = build_standard_template!
    assignment = publish!(create_rubric_assignment!(template: parts[:template]))

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { rubric_evaluations: { @student.id => { parts[:content].id => parts[:excelente].id } } }
    end

    assert_nil Schedules::Assessment.joins(:enrollment).find_by(assignment_id: assignment.id,
      enrollments: { student_id: @student.id }).score
  end

  # --- group ---------------------------------------------------------------

  test "acceptance: evaluating a group bulk-sets every member, and an individual override survives until the group is re-applied" do
    parts = build_standard_template!
    student_b = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Sofía", last_name: "Vidal", student_code: "RUB-002")
      enroll!(@institution, student: s, subject: @subject, active_term: @active_term)
      s
    end
    assignment = publish!(create_rubric_assignment!(template: parts[:template], title: "Ensayo en equipo", group_work: true))
    group = form_group!(assignment, name: "Equipo 1", student_ids: [ @student.id, student_b.id ])

    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { group_rubric_evaluations: { group.id => {
          parts[:content].id => parts[:excelente].id, parts[:form].id => parts[:excelente].id
        } } }
    end
    [ @student, student_b ].each do |student|
      assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
        enrollments: { student_id: student.id })
      assert_equal BigDecimal("5.0"), assessment.score
    end
    group_evaluation = Assignments::RubricEvaluation.find_by!(institution_id: @institution.id,
      assignment_id: assignment.id, submission_group_id: group.id)
    assert_nil group_evaluation.student_id

    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success, "the group-work grading page (group cards + rubric grids) must render"
    end

    # Individual override for student_b only.
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { rubric_evaluations: { student_b.id => {
          parts[:content].id => parts[:incompleto].id, parts[:form].id => parts[:incompleto].id
        } } }
    end
    assert_equal BigDecimal("0.0"), Schedules::Assessment.joins(:enrollment)
      .find_by!(assignment_id: assignment.id, enrollments: { student_id: student_b.id }).score
    assert_equal BigDecimal("5.0"), Schedules::Assessment.joins(:enrollment)
      .find_by!(assignment_id: assignment.id, enrollments: { student_id: @student.id }).score

    # Re-applying the group evaluation resets EVERYONE, including the override.
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { group_rubric_evaluations: { group.id => {
          parts[:content].id => parts[:bueno].id, parts[:form].id => parts[:bueno].id
        } } }
    end
    [ @student, student_b ].each do |student|
      assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
        enrollments: { student_id: student.id })
      assert_equal BigDecimal("3.0"), assessment.score
    end
  end

  test "a draft rubric assignment's management page renders the live-template structure preview" do
    parts = build_standard_template!
    assignment = create_rubric_assignment!(template: parts[:template], title: "Sin publicar")

    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}"
      assert_response :success
      assert_match(/Contenido/, response.body)
      assert_match(/Argumenta con evidencia sólida/, response.body)
    end
  end

  # --- toggle/freeze ---------------------------------------------------------

  test "evaluation_method and the chosen template are locked once published — a later attempt to change them has no effect" do
    parts = build_standard_template!
    assignment = publish!(create_rubric_assignment!(template: parts[:template]))
    assert assignment.rubric?

    other_template = create_template!(name: "Otra rúbrica")
    as_teacher do
      patch "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}",
        params: { assignment: { evaluation_method: "direct", rubric_template_id: other_template.id } }
    end
    assignment.reload
    assert assignment.rubric?, "evaluation_method must stay locked once published"
    assert_equal parts[:template].id, assignment.rubric_template_id
  end

  test "editing the template's library afterward never changes an already-published assignment (frozen snapshot)" do
    parts = build_standard_template!
    assignment = publish!(create_rubric_assignment!(template: parts[:template]))
    frozen_criteria = assignment.rubric_snapshot["criteria"]

    # Edit the LIVE template: rename a criterion, change its weight, add a new one.
    as_teacher do
      patch "/assignments/rubric_templates/#{parts[:template].id}/rubric_criteria/#{parts[:content].id}",
        params: { rubric_criterion: { name: "Contenido (editado)", weight: "99.0" } }
    end
    add_criterion!(parts[:template], name: "Criterio nuevo", weight: "1.0")

    assignment.reload
    assert_equal frozen_criteria, assignment.rubric_snapshot["criteria"],
      "the assignment's frozen snapshot must be untouched by editing the live library"

    # Grading still works off the frozen snapshot, unaffected by the live edit.
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { rubric_evaluations: { @student.id => {
          parts[:content].id => parts[:excelente].id, parts[:form].id => parts[:bueno].id
        } } }
    end
    assessment = Schedules::Assessment.joins(:enrollment).find_by!(assignment_id: assignment.id,
      enrollments: { student_id: @student.id })
    assert_equal BigDecimal("4.3"), assessment.score
  end

  # --- portal ---------------------------------------------------------------

  test "a guardian sees the level obtained and its descriptor per criterion for their child's rubric-graded assignment" do
    parts = build_standard_template!
    assignment = publish!(create_rubric_assignment!(template: parts[:template]))
    as_teacher do
      post "/assignments/subjects/#{@subject.id}/assignments/#{assignment.id}/grade",
        params: { rubric_evaluations: { @student.id => {
          parts[:content].id => parts[:excelente].id, parts[:form].id => parts[:bueno].id
        } } }
    end

    guardian_user = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @student, email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente")
    end
    sign_in_as(guardian_user, institution: @institution, password: "password-123456")

    get "/portal/guardian/students/#{@student.id}/assignments/#{assignment.id}"
    assert_response :success
    assert_match(/Excelente/, response.body)
    assert_match(/Argumenta con evidencia sólida/, response.body)
  end

  test "a draft rubric-graded assignment is invisible to the portal (no separate check — the assignment itself isn't in scope)" do
    parts = build_standard_template!
    assignment = create_rubric_assignment!(template: parts[:template], title: "Aún sin publicar")

    student_user = within_tenant(@institution) do
      link_as_student_user!(@institution, student: @student, email: "student-#{SecureRandom.hex(4)}@member.test", name: "Mateo")
    end
    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/assignments/#{assignment.id}"
    assert_response :not_found
  end

  test "the assignment form offers the docente's own rubric templates" do
    template = create_template!(name: "Mi rúbrica")

    as_teacher do
      get "/assignments/subjects/#{@subject.id}/assignments/new"
      assert_response :success
      assert_match(/Mi rúbrica/, response.body)
    end
  end

  test "the rubric library's index/new/edit pages render" do
    parts = build_standard_template!

    as_teacher do
      get "/assignments/rubric_templates"
      assert_response :success
      assert_match(/Ensayo argumentativo/, response.body)

      get "/assignments/rubric_templates/new"
      assert_response :success

      get "/assignments/rubric_templates/#{parts[:template].id}/edit"
      assert_response :success
      assert_match(/Contenido/, response.body)
      assert_match(/Excelente/, response.body)
    end
  end

  # --- cross-tenant ----------------------------------------------------------

  test "cross-tenant: a rubric template/evaluation seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "rubric-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    within_tenant(other_institution) do
      other_user = Core::User.create!(email: "otherteacher-#{SecureRandom.hex(4)}@member.test", name: "Otro Docente",
        password: "password-123456")
      other_institution.memberships.create!(user: other_user)
      grade_level = build_grade_level!(other_institution, name: "Grado Otro", level_number: 9)
      subject = build_subject!(other_institution, grade_level: grade_level, name: "Materia Ajena", code: "AJENA-RUB")
      ghost_template = Assignments::RubricTemplate.create!(institution: other_institution, authored_by: other_user,
        name: "Rúbrica ajena")
      other_assignment = Assignments::Assignment.create!(institution: other_institution, subject: subject,
        title: "Tarea ajena", due_date: Date.new(2026, 4, 1), status: "published", published_at: Time.current,
        evaluation_method: "rubric", rubric_template: ghost_template,
        rubric_snapshot: { "criteria" => [], "levels" => [], "descriptors" => {} })
      ghost_student = build_student!(other_institution, first_name: "Fantasma", last_name: "Ajeno", student_code: "GHOST-RUB")
      Assignments::RubricEvaluation.create!(institution: other_institution, assignment: other_assignment,
        student: ghost_student, levels_by_criterion: {})
    end

    as_teacher do
      get "/assignments/rubric_templates"
      assert_response :success
      assert_no_match(/Rúbrica ajena/, response.body)
    end

    within_tenant(@institution) do
      assert_empty Assignments::RubricTemplate.where(institution_id: other_institution.id)
      assert_empty Assignments::RubricEvaluation.where(institution_id: other_institution.id)
    end
  end
end
