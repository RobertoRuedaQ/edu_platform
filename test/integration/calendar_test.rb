require "test_helper"

# calendar (net-new domain, v1.27.0, item #7 of the MVP critical path).
# Shared calendar with caregivers. The delicate piece: the audience chosen on
# the form decides WHICH resource is passed to authorize!("calendar.manage",
# ...), so one permission scopes three ways off the SAME grant mechanism —
# a group actor can publish to their section but NOT institution-wide. The
# portal timeline merges real events with derived assignment deadlines
# (Calendar::Timeline), by relation, never RBAC.
class CalendarTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_grade_level!(institution, name:, level_number:)
    GroupManagement::GradeLevel.create!(institution: institution, name: name, level_number: level_number)
  end

  def build_section!(institution, grade_level:, name:)
    GroupManagement::Section.create!(institution: institution, grade_level: grade_level, name: name, academic_year: 2026)
  end

  def build_student!(institution, first_name:, last_name:, student_code:, section:, grade_level:)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: student_code, entry_year: 2023,
      section: section, grade_level: grade_level)
  end

  def build_subject!(institution, grade_level:, name:, code:)
    Schedules::Subject.create!(institution: institution, grade_level: grade_level, name: name, code: code, term: "2026-1")
  end

  def enroll!(institution, student:, subject:)
    Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      term: @active_term.code, academic_term: @active_term, status: "enrolled")
  end

  def link_as_guardian!(institution, student:, email:, name:)
    user = Core::User.create!(email: email, name: name, password: "password-123456")
    institution.memberships.create!(user: user)
    Core::GuardianStudent.create!(institution: institution, guardian_user_id: user.id, student: student,
      relationship: "madre", status: "active")
    user
  end

  setup do
    @user, @institution = sign_in_as_member # calendar entitled by default (grant_full_entitlements)

    @active_term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    @grade_a = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado 9", level_number: 9) }
    @grade_b = within_tenant(@institution) { build_grade_level!(@institution, name: "Grado 10", level_number: 10) }
    @section_a = within_tenant(@institution) { build_section!(@institution, grade_level: @grade_a, name: "9°A") }
    @section_b = within_tenant(@institution) { build_section!(@institution, grade_level: @grade_b, name: "10°B") }

    @subject_a = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_a, name: "Álgebra", code: "MAT-CAL-A") }
    @subject_b = within_tenant(@institution) { build_subject!(@institution, grade_level: @grade_b, name: "Física", code: "MAT-CAL-B") }

    @child = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Valentina", last_name: "Suárez",
        student_code: "CAL-001", section: @section_a, grade_level: @grade_a)
      enroll!(@institution, student: s, subject: @subject_a)
      s
    end
    @other_child = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Otro", last_name: "Grupo",
        student_code: "CAL-002", section: @section_b, grade_level: @grade_b)
      enroll!(@institution, student: s, subject: @subject_b)
      s
    end
  end

  def as_homeroom_a(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[calendar.manage],
                                     scope_type: :group, scope_id: @section_a.id),
      &block
    )
  end

  def as_grade_a_lead(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "coordinator", permission_keys: %w[calendar.manage],
                                     scope_type: :grade_level, scope_id: @grade_a.id),
      &block
    )
  end

  def as_director(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "director", permission_keys: %w[calendar.manage],
                                     scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def event_params(title:, audience:, **extra)
    { audience: audience,
      event: { title: title, starts_at: "2026-03-10T09:00", ends_at: "2026-03-10T10:00" } }.merge(extra)
  end

  # (1) group actor creates an event for their OWN section — ok.
  test "a homeroom with group scope creates an event for their own section" do
    as_homeroom_a do
      post "/calendar/events", params: event_params(title: "Reunión 9A", audience: "group", scope_group_id: @section_a.id)
      assert_redirected_to calendar_events_path

      event = Calendar::Event.find_by!(institution_id: @institution.id, title: "Reunión 9A")
      assert_equal @section_a.id, event.scope_group_id
      assert_nil event.scope_grade_level_id
      assert_not event.institution_wide?
    end
  end

  # (2) the SAME group actor cannot create an institution-wide event — 403.
  test "a homeroom with group scope cannot create an institution-wide event (403)" do
    as_homeroom_a do
      post "/calendar/events", params: event_params(title: "Evento global", audience: "institution")
      assert_response :forbidden
      assert_nil Calendar::Event.find_by(institution_id: @institution.id, title: "Evento global")
    end
  end

  # (3) grade actor creates for their grade — ok; and cannot for a foreign grade — 403.
  test "a grade-scoped actor creates for their own grade, but not for another grade" do
    as_grade_a_lead do
      post "/calendar/events", params: event_params(title: "Salida grado 9", audience: "grade_level", scope_grade_level_id: @grade_a.id)
      assert_redirected_to calendar_events_path
      assert_equal @grade_a.id, Calendar::Event.find_by!(institution_id: @institution.id, title: "Salida grado 9").scope_grade_level_id

      post "/calendar/events", params: event_params(title: "Salida grado 10", audience: "grade_level", scope_grade_level_id: @grade_b.id)
      assert_response :forbidden
      assert_nil Calendar::Event.find_by(institution_id: @institution.id, title: "Salida grado 10")
    end
  end

  # (4) institution-wide actor creates an institution-wide event — ok.
  test "an institution-wide actor creates an institution-wide event" do
    as_director do
      post "/calendar/events", params: event_params(title: "Feria institucional", audience: "institution")
      assert_redirected_to calendar_events_path

      event = Calendar::Event.find_by!(institution_id: @institution.id, title: "Feria institucional")
      assert event.institution_wide?
    end
  end

  test "the management index lists only events within the actor's scope" do
    within_tenant(@institution) do
      Calendar::Event.create!(institution: @institution, title: "Reunión 9A", group: @section_a,
        starts_at: Time.zone.local(2026, 3, 10, 9), ends_at: Time.zone.local(2026, 3, 10, 10))
      Calendar::Event.create!(institution: @institution, title: "Reunión 10B", group: @section_b,
        starts_at: Time.zone.local(2026, 3, 11, 9), ends_at: Time.zone.local(2026, 3, 11, 10))
    end

    as_homeroom_a do
      get "/calendar/events"
      assert_response :success
      assert_match(/Reunión 9A/, response.body)
      assert_no_match(/Reunión 10B/, response.body)
    end
  end

  test "an actor with no calendar grant is denied the management index (403)" do
    with_grants { get "/calendar/events"; assert_response :forbidden }
  end

  test "entitlement gate #1 runs before RBAC gate #2: not entitled shows the friendly module page" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id, addons: { key: "calendar" })
    entitlement.revoke!

    as_director do
      get "/calendar/events"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  # (5) cross-tenant isolation is RLS-real, not just query scope.
  test "cross-tenant: an event seeded in another institution never leaks under RLS" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "cal-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(other_institution) do
      Calendar::Event.create!(institution: other_institution, title: "Evento Ajeno",
        starts_at: Time.zone.local(2026, 3, 10, 9), ends_at: Time.zone.local(2026, 3, 10, 10))
    end

    # Under I's own GUC, a raw query that explicitly asks for J's institution_id
    # must still return zero rows — RLS itself blocking it, never current_setting.
    within_tenant(@institution) do
      assert_empty Calendar::Event.where(institution_id: other_institution.id, title: "Evento Ajeno")
    end
  end

  # (6) guardian portal sees institution-wide + their child's grade/section, never another's.
  test "the guardian portal shows institution-wide + the child's grade/section events, never another's" do
    within_tenant(@institution) do
      Calendar::Event.create!(institution: @institution, title: "Feria institucional",
        starts_at: Time.zone.local(2026, 3, 9, 9), ends_at: Time.zone.local(2026, 3, 9, 10))
      Calendar::Event.create!(institution: @institution, title: "Salida grado 9", grade_level: @grade_a,
        starts_at: Time.zone.local(2026, 3, 10, 9), ends_at: Time.zone.local(2026, 3, 10, 10))
      Calendar::Event.create!(institution: @institution, title: "Reunión 9A", group: @section_a,
        starts_at: Time.zone.local(2026, 3, 11, 9), ends_at: Time.zone.local(2026, 3, 11, 10))
      Calendar::Event.create!(institution: @institution, title: "Salida grado 10", grade_level: @grade_b,
        starts_at: Time.zone.local(2026, 3, 12, 9), ends_at: Time.zone.local(2026, 3, 12, 10))
      Calendar::Event.create!(institution: @institution, title: "Reunión 10B", group: @section_b,
        starts_at: Time.zone.local(2026, 3, 13, 9), ends_at: Time.zone.local(2026, 3, 13, 10))
    end

    guardian = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @child, email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente")
    end
    sign_in_as(guardian, institution: @institution, password: "password-123456")

    get portal_guardian_student_calendar_path(@child)
    assert_response :success
    assert_match(/Feria institucional/, response.body)
    assert_match(/Salida grado 9/, response.body)
    assert_match(/Reunión 9A/, response.body)
    assert_no_match(/Salida grado 10/, response.body)
    assert_no_match(/Reunión 10B/, response.body)
  end

  test "GET new renders the audience form" do
    as_director do
      get "/calendar/events/new"
      assert_response :success
      assert_select "input[name=audience][value=institution]"
      assert_select "input[name=audience][value=grade_level]"
      assert_select "input[name=audience][value=group]"
    end
  end

  test "an institution-wide actor updates an event" do
    event = within_tenant(@institution) do
      Calendar::Event.create!(institution: @institution, title: "Original",
        starts_at: Time.zone.local(2026, 3, 10, 9), ends_at: Time.zone.local(2026, 3, 10, 10))
    end

    as_director do
      patch "/calendar/events/#{event.id}",
        params: { audience: "institution", event: { title: "Actualizado", starts_at: "2026-03-10T09:00", ends_at: "2026-03-10T10:00" } }
      assert_redirected_to calendar_events_path
      assert_equal "Actualizado", event.reload.title
    end
  end

  test "an institution-wide actor destroys an event" do
    event = within_tenant(@institution) do
      Calendar::Event.create!(institution: @institution, title: "A eliminar",
        starts_at: Time.zone.local(2026, 3, 10, 9), ends_at: Time.zone.local(2026, 3, 10, 10))
    end

    as_director do
      delete "/calendar/events/#{event.id}"
      assert_redirected_to calendar_events_path
      assert_nil Calendar::Event.find_by(institution_id: @institution.id, id: event.id)
    end
  end

  test "a group actor cannot edit an institution-wide event (403)" do
    event = within_tenant(@institution) do
      Calendar::Event.create!(institution: @institution, title: "Solo dirección",
        starts_at: Time.zone.local(2026, 3, 10, 9), ends_at: Time.zone.local(2026, 3, 10, 10))
    end

    as_homeroom_a do
      get "/calendar/events/#{event.id}/edit"
      assert_response :forbidden
    end
  end

  # (7) the guardian timeline merges a real event with the child's published
  # assignment deadline, ordered chronologically, and never another student's.
  test "the guardian timeline merges a real event with the child's assignment deadline, chronologically" do
    within_tenant(@institution) do
      Calendar::Event.create!(institution: @institution, title: "Feria de ciencias",
        starts_at: Time.zone.local(2026, 3, 10, 9), ends_at: Time.zone.local(2026, 3, 10, 12))
      Assignments::Assignment.create!(institution: @institution, subject: @subject_a, title: "Ensayo de funciones",
        due_date: Date.new(2026, 3, 20), status: "published")
      # The OTHER child's subject — @child is NOT enrolled, so it must not appear.
      Assignments::Assignment.create!(institution: @institution, subject: @subject_b, title: "Tarea de otro estudiante",
        due_date: Date.new(2026, 3, 15), status: "published")
    end

    guardian = within_tenant(@institution) do
      link_as_guardian!(@institution, student: @child, email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente")
    end
    sign_in_as(guardian, institution: @institution, password: "password-123456")

    get portal_guardian_student_calendar_path(@child)
    assert_response :success
    assert_match(/Feria de ciencias/, response.body)
    assert_match(/Ensayo de funciones/, response.body)
    assert_no_match(/Tarea de otro estudiante/, response.body)
    # Event (Mar 10) sorts before the deadline (Mar 20).
    assert_operator response.body.index("Feria de ciencias"), :<, response.body.index("Ensayo de funciones"),
      "the real event (Mar 10) must sort before the assignment deadline (Mar 20)"
  end
end
