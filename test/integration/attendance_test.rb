require "test_helper"

# attendance (net-new domain, v1.16.0, item #2 of the MVP critical path).
# Copies the teacher_management canonical mold (§6.6): per-row can?,
# authorize!, Navigation::Registry. Roster tomable = Schedules::
# ActiveTermEnrollmentScope ∩ group (A1) — never re-derives the term join.
class AttendanceTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_section!(institution, name:)
    GroupManagement::Section.create!(institution: institution, name: name, academic_year: 2026)
  end

  def build_student!(institution, first_name:, last_name:, student_code:, section:)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: student_code, entry_year: 2023, section: section)
  end

  # Enrolls the student in a subject for the institution's active term — the
  # ONLY real signal Schedules::ActiveTermEnrollmentScope reads.
  def enroll_in_active_term!(institution, student:, active_term:)
    subject = Schedules::Subject.find_or_create_by!(institution: institution, code: "MAT-ATT") do |s|
      s.name = "Álgebra"
      s.term = active_term.code
    end
    Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      term: active_term.code, academic_term: active_term, status: "enrolled")
  end

  setup do
    @user, @institution = sign_in_as_member # attendance entitled by default (grant_full_entitlements)

    @active_term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    @section_a = within_tenant(@institution) { build_section!(@institution, name: "9°A") }
    @section_b = within_tenant(@institution) { build_section!(@institution, name: "9°B") }

    @student_in_term = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Valentina", last_name: "Suárez", student_code: "AT-001", section: @section_a)
      enroll_in_active_term!(@institution, student: s, active_term: @active_term)
      s
    end
    @student_not_enrolled = within_tenant(@institution) do
      build_student!(@institution, first_name: "Sin", last_name: "Matricula", student_code: "AT-002", section: @section_a)
    end
    @student_in_b = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Otro", last_name: "Grupo", student_code: "AT-003", section: @section_b)
      enroll_in_active_term!(@institution, student: s, active_term: @active_term)
      s
    end
  end

  def as_homeroom_a(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[attendance.record],
                                     scope_type: :group, scope_id: @section_a.id),
      &block
    )
  end

  test "index shows only the actor's own group" do
    as_homeroom_a do
      get "/attendance/groups"
      assert_response :success
      assert_select "td", text: "9°A"
      assert_select "td", text: "9°B", count: 0
    end
  end

  test "an actor with no grants is denied the index (403)" do
    with_grants { get "/attendance/groups"; assert_response :forbidden }
  end

  test "roster tomable is the intersection: enrolled-this-term students of the group, excluding one not enrolled" do
    as_homeroom_a do
      get "/attendance/groups/#{@section_a.id}/records/new"
      assert_response :success
      assert_match(/Valentina Suárez/, response.body)
      assert_no_match(/Sin Matricula/, response.body)
    end
  end

  test "acceptance: taking attendance persists one record per roster student" do
    as_homeroom_a do
      post "/attendance/groups/#{@section_a.id}/records",
        params: { date: "2026-03-10", statuses: { @student_in_term.id => "absent" } }
      assert_redirected_to attendance_groups_path

      record = Attendance::AttendanceRecord.find_by!(institution_id: @institution.id,
        student_id: @student_in_term.id, date: Date.new(2026, 3, 10))
      assert_equal "absent", record.status
      assert_equal @section_a.id, record.group_id

      # The non-enrolled student never gets a row at all — the roster never included them.
      assert_nil Attendance::AttendanceRecord.find_by(institution_id: @institution.id,
        student_id: @student_not_enrolled.id, date: Date.new(2026, 3, 10))
    end
  end

  test "re-taking the same (group, date) updates the existing record, never duplicates" do
    as_homeroom_a do
      post "/attendance/groups/#{@section_a.id}/records",
        params: { date: "2026-03-11", statuses: { @student_in_term.id => "present" } }
      assert_equal 1, Attendance::AttendanceRecord.where(institution_id: @institution.id,
        student_id: @student_in_term.id, date: Date.new(2026, 3, 11)).count

      post "/attendance/groups/#{@section_a.id}/records",
        params: { date: "2026-03-11", statuses: { @student_in_term.id => "late" } }

      records = Attendance::AttendanceRecord.where(institution_id: @institution.id,
        student_id: @student_in_term.id, date: Date.new(2026, 3, 11))
      assert_equal 1, records.count, "re-taking attendance must update, never duplicate"
      assert_equal "late", records.sole.status
    end
  end

  test "a homeroom teacher cannot take attendance for a group outside their scope (403)" do
    as_homeroom_a do
      get "/attendance/groups/#{@section_b.id}/records/new"
      assert_response :forbidden

      post "/attendance/groups/#{@section_b.id}/records", params: { date: "2026-03-10", statuses: {} }
      assert_response :forbidden
    end
  end

  test "entitlement gate #1 runs before RBAC gate #2: not entitled shows the friendly module page, not a bare 403" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id, addons: { key: "attendance" })
    entitlement.revoke!

    as_homeroom_a do
      get "/attendance/groups"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "no student search surface anywhere in the roster-taking view" do
    as_homeroom_a do
      get "/attendance/groups/#{@section_a.id}/records/new"
      assert_response :success
      # Scoped to #main to deliberately exclude the staff shell's pre-existing
      # global app search in the header (unrelated to this page, out of
      # scope — same call every prior slice's test already made).
      assert_select "main#main input[type=search]", count: 0
      assert_select "main#main input[name=q]", count: 0
    end
  end

  test "cross-tenant: a group/roster seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "att-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    other_term = within_tenant(other_institution) do
      Core::AcademicTerm.create!(institution: other_institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end
    within_tenant(other_institution) do
      section = build_section!(other_institution, name: "9°A Otro Colegio")
      student = build_student!(other_institution, first_name: "Fantasma", last_name: "Ajeno",
        student_code: "GHOST-1", section: section)
      enroll_in_active_term!(other_institution, student: student, active_term: other_term)
    end

    as_homeroom_a do
      get "/attendance/groups"
      assert_response :success
      assert_no_match(/9°A Otro Colegio/, response.body)
    end

    # Model-layer, under I's own GUC: a raw query that explicitly asks for J's
    # institution_id must still return zero rows — RLS itself blocking it.
    within_tenant(@institution) do
      assert_empty GroupManagement::Section.where(institution_id: other_institution.id, name: "9°A Otro Colegio")
    end
  end

  # Regression: confirm this slice never touched the headcount source or
  # re-derived the term join (guardrail v1.15.0).
  test "REGRESSION: headcount is unaffected by attendance records" do
    within_tenant(@institution) do
      Attendance::AttendanceRecord.create!(institution: @institution, student: @student_in_term,
        group: @section_a, date: Date.new(2026, 3, 10), status: "absent")

      snapshot = Core::Headcount::Snapshotter.call(institution: @institution, as_of: Date.current)
      # Two students total were created under section_a/b as "active" (default status).
      assert_equal 3, snapshot.headcount
    end
  end
end
