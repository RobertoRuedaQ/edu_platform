require "test_helper"

class SchedulesTest < ActionDispatch::IntegrationTest
  setup { @user, @institution = sign_in_as_member }

  # Teaches/leads only 9°A: can read+write grades and view schedule for that group.
  def as_teacher_9a(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "teacher",
                                     permission_keys: %w[grades.read grades.write schedule.view],
                                     scope_type: :group, scope_id: GroupManagement::GroupRoster::SECTION_9A_ID),
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

  test "grades index filters to the actor's own group" do
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

  test "authorize! denies viewing a subject outside the actor's group" do
    as_teacher_9a do
      get "/schedules/grades/sub-3" # Cálculo, 10°A
      assert_response :forbidden
    end
  end

  test "can? shows 'Registrar calificación' only for a role holding grades.write" do
    as_teacher_9a do
      get "/schedules/grades/sub-1"
      assert_response :success
      assert_select "a.btn", text: "Registrar calificación"
    end

    as_grades_reader do
      get "/schedules/grades/sub-1"
      assert_response :success
      assert_select "a.btn", text: "Registrar calificación", count: 0
    end
  end

  test "authorize! denies the grade entry form for a read-only role, matching can?" do
    as_grades_reader do
      get "/schedules/grades/sub-1/grade_entries/new"
      assert_response :forbidden
    end
  end

  test "teacher can open the grade entry form for their own subject" do
    as_teacher_9a do
      get "/schedules/grades/sub-1/grade_entries/new"
      assert_response :success
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
