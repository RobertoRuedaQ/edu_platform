require "test_helper"

class SchedulesTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_grade_level!(institution, name:, level_number:)
    GroupManagement::GradeLevel.create!(institution: institution, name: name, level_number: level_number)
  end

  def build_subject!(institution, name:, code:, grade_level:, term: "2026-1")
    Schedules::Subject.create!(institution: institution, name: name, code: code, term: term, grade_level: grade_level)
  end

  setup do
    @user, @institution = sign_in_as_member

    @grado_9 = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado 9", level_number: 9) }
    @grado_10 = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado 10", level_number: 10) }

    @algebra = within_tenant(@institution) { build_subject!(@institution, name: "Álgebra", code: "MAT-901", grade_level: @grado_9) }
    @historia = within_tenant(@institution) { build_subject!(@institution, name: "Historia", code: "SOC-901", grade_level: @grado_9) }
    @calculo = within_tenant(@institution) { build_subject!(@institution, name: "Cálculo", code: "MAT-1001", grade_level: @grado_10) }
    @sociologia = within_tenant(@institution) { build_subject!(@institution, name: "Sociología", code: "SOC-1101", grade_level: @grado_10) }
  end

  # Teaches/leads only Grado 9: can read+write grades for that grade level,
  # and (separately, real Subject has no group/section link, only
  # grade_level/program — #4 barrido) view their own group's schedule, via
  # the still-stub :group scope dimension schedule.view uses.
  def as_teacher_9a(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[schedule.view],
                                     scope_type: :group, scope_id: GroupManagement::GroupRoster::SECTION_9A_ID),
      Authorization::Assignment.new(role_key: "teacher", permission_keys: %w[grades.read grades.write],
                                     scope_type: :grade_level, scope_id: @grado_9.id),
      &block
    )
  end

  # Reads grades institution-wide but never writes them (e.g. a secretary).
  def as_grades_reader(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "secretary", permission_keys: %w[grades.read],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # Registrar: builds the institutional timetable and manages rooms.
  def as_registrar(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "registrar",
                                     permission_keys: %w[timetable.manage rooms.view],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "grades index filters to the actor's own grade level" do
    as_teacher_9a do
      get "/schedules/grades"
      assert_response :success
      assert_select "a", text: "Álgebra"
      assert_select "a", text: "Historia"
      assert_select "a", text: "Cálculo", count: 0
      assert_select "a", text: "Sociología", count: 0
    end
  end

  test "an actor with no grants is denied the grades index (403)" do
    with_grants { get "/schedules/grades"; assert_response :forbidden }
  end

  test "authorize! denies viewing a subject outside the actor's grade level" do
    as_teacher_9a do
      get "/schedules/grades/#{@calculo.id}" # Grado 10
      assert_response :forbidden
    end
  end

  test "can? shows 'Registrar calificación' only for a role holding grades.write" do
    as_teacher_9a do
      get "/schedules/grades/#{@algebra.id}"
      assert_response :success
      assert_select "a.btn", text: "Registrar calificación"
    end

    as_grades_reader do
      get "/schedules/grades/#{@algebra.id}"
      assert_response :success
      assert_select "a.btn", text: "Registrar calificación", count: 0
    end
  end

  test "authorize! denies the grade entry form for a read-only role, matching can?" do
    as_grades_reader do
      get "/schedules/grades/#{@algebra.id}/grade_entries/new"
      assert_response :forbidden
    end
  end

  test "teacher can open the grade entry form for their own subject" do
    as_teacher_9a do
      get "/schedules/grades/#{@algebra.id}/grade_entries/new"
      assert_response :success
    end
  end

  # #4 barrido: Schedules::Assessment already exists, so — unlike
  # teacher.evaluate — this really persists, not just gates.
  test "registering a grade really creates an Enrollment + Assessment" do
    student = within_tenant(@institution) do
      GroupManagement::Student.create!(institution: @institution, first_name: "Valentina", last_name: "Suárez",
        gender: "female", birthdate: Date.new(2012, 4, 1), student_code: "COL-E-201", entry_year: 2023,
        grade_level: @grado_9)
    end

    as_teacher_9a do
      post "/schedules/grades/#{@algebra.id}/grade_entries",
        params: { student_id: "COL-E-201", title: "Parcial 1", score: "4.2" }
      assert_redirected_to schedules_subject_path(@algebra)

      enrollment = Schedules::Enrollment.find_by(institution_id: @institution.id, student_id: student.id, subject_id: @algebra.id)
      assert_not_nil enrollment
      # No Core::AcademicTerm exists in this test's institution at all — a
      # nil academic_term_id here is the honest, normal state (v1.15.0), not
      # a bug: nothing was resolvable to attach.
      assert_nil enrollment.academic_term_id
      assessment = enrollment.assessments.sole
      assert_equal "Parcial 1", assessment.title
      assert_equal 4.2, assessment.score.to_f
    end
  end

  # v1.15.0: when an active term DOES exist, the real write path populates
  # academic_term_id — the join isn't purely theoretical.
  test "registering a grade sets academic_term_id when an active term exists" do
    active_term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end
    student = within_tenant(@institution) do
      GroupManagement::Student.create!(institution: @institution, first_name: "Camila", last_name: "Vargas",
        gender: "female", birthdate: Date.new(2012, 4, 1), student_code: "COL-E-202", entry_year: 2023,
        grade_level: @grado_9)
    end

    as_teacher_9a do
      post "/schedules/grades/#{@algebra.id}/grade_entries",
        params: { student_id: "COL-E-202", title: "Parcial 1", score: "3.5" }
      assert_redirected_to schedules_subject_path(@algebra)

      enrollment = Schedules::Enrollment.find_by(institution_id: @institution.id, student_id: student.id, subject_id: @algebra.id)
      assert_equal active_term.id, enrollment.academic_term_id
    end
  end

  test "registering a grade for an unknown student code shows an error, not a 500" do
    as_teacher_9a do
      post "/schedules/grades/#{@algebra.id}/grade_entries",
        params: { student_id: "NOPE", title: "Parcial 1", score: "4.2" }
      assert_response :unprocessable_entity
    end
  end

  test "cross-tenant: a subject seeded in a different institution never leaks into this one's index" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "sched-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(other_institution) do
      grade = build_grade_level!(other_institution, name: "Grado 9 Otro Colegio", level_number: 9)
      build_subject!(other_institution, name: "Álgebra Otro Colegio", code: "MAT-901", grade_level: grade)
    end

    as_grades_reader do
      get "/schedules/grades"
      assert_response :success
      assert_no_match(/Álgebra Otro Colegio/, response.body)
      assert_select ".table tbody tr", count: 4
    end
  end

  test "mi horario filters events to the actor's own group" do
    as_teacher_9a do
      get "/schedules/my_schedule"
      assert_response :success
      assert_select "td", text: "Álgebra"
      assert_select "td", text: "Cálculo", count: 0
    end
  end

  test "a role without schedule.view is denied mi horario" do
    as_grades_reader { get "/schedules/my_schedule"; assert_response :forbidden }
  end

  test "institutional timetable is denied to a role without timetable.manage" do
    as_teacher_9a { get "/schedules/timetable"; assert_response :forbidden }
  end

  test "registrar sees the institutional timetable with every event, conflicts marked as text" do
    as_registrar do
      get "/schedules/timetable"
      assert_response :success
      assert_select "td", text: "Cálculo"
      assert_select "td", text: "Sociología"
      # Conflict is never color-only: the word itself must be in the markup.
      assert_select ".badge", text: "Conflicto"
    end
  end

  test "rooms index/show require rooms.view" do
    as_teacher_9a { get "/schedules/rooms"; assert_response :forbidden }

    as_registrar do
      get "/schedules/rooms"
      assert_response :success
      assert_select "a", text: "Aula 101"

      get "/schedules/rooms/room-101"
      assert_response :success
    end
  end
end
