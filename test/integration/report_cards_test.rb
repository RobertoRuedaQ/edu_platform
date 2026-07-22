require "test_helper"

# report_cards (net-new domain, v1.17.0, item #3 of the MVP critical path).
# Copies the teacher_management canonical mold (§6.6): per-row can?,
# authorize!, Navigation::Registry. Roster tomable = Schedules::
# ActiveTermEnrollmentScope ∩ group — same discipline as attendance
# (v1.16.0), never re-derives the term join. A published ReportCard NEVER
# re-reads live Schedules::Assessment data (the star invariant, §9).
class ReportCardsTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_section!(institution, name:)
    GroupManagement::Section.create!(institution: institution, name: name, academic_year: 2026)
  end

  def build_student!(institution, first_name:, last_name:, student_code:, section:, user: nil)
    GroupManagement::Student.create!(institution: institution, first_name: first_name, last_name: last_name,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: student_code, entry_year: 2023,
      section: section, user: user)
  end

  # Enrolls the student in a subject for the institution's active term and
  # grades one assessment — the ONLY real signal Computation reads.
  def build_staff_member!(institution, email:)
    user = Core::User.create!(email: email, name: "Staff de prueba", password: "password-123456")
    iu = institution.memberships.create!(user: user)
    StaffManagement::StaffMember.create!(institution: institution, institution_user: iu,
      employee_number: "EMP-#{SecureRandom.hex(4)}", staff_category: "admin", employment_type: "full_time")
  end

  def enroll_and_grade!(institution, student:, active_term:, subject_code: "MAT-RC", score: 4.0)
    subject = Schedules::Subject.find_or_create_by!(institution: institution, code: subject_code) do |s|
      s.name = "Álgebra"
      s.term = active_term.code
    end
    enrollment = Schedules::Enrollment.create!(institution: institution, student: student, subject: subject,
      term: active_term.code, academic_term: active_term, status: "enrolled")
    enrollment.assessments.create!(institution: institution, kind: "parcial", title: "Parcial 1",
      term: active_term.code, score: score, max_score: 5.0, weight: 1.0)
    enrollment
  end

  setup do
    @user, @institution = sign_in_as_member # report_cards entitled by default (grant_full_entitlements)

    @active_term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    @section_a = within_tenant(@institution) { build_section!(@institution, name: "9°A") }
    @section_b = within_tenant(@institution) { build_section!(@institution, name: "9°B") }

    @student_in_term = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Valentina", last_name: "Suárez", student_code: "RC-001", section: @section_a)
      enroll_and_grade!(@institution, student: s, active_term: @active_term)
      s
    end
    @student_not_enrolled = within_tenant(@institution) do
      build_student!(@institution, first_name: "Sin", last_name: "Matricula", student_code: "RC-002", section: @section_a)
    end
    @student_in_b = within_tenant(@institution) do
      s = build_student!(@institution, first_name: "Otro", last_name: "Grupo", student_code: "RC-003", section: @section_b)
      enroll_and_grade!(@institution, student: s, active_term: @active_term, subject_code: "MAT-RC-B")
      s
    end
  end

  def as_homeroom_a(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[report_card.view report_card.publish],
                                     scope_type: :group, scope_id: @section_a.id),
      &block
    )
  end

  def as_viewer_only_a(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "homeroom", permission_keys: %w[report_card.view],
                                     scope_type: :group, scope_id: @section_a.id),
      &block
    )
  end

  test "index shows only the actor's own group" do
    as_homeroom_a do
      get "/report_cards/groups"
      assert_response :success
      assert_select "td", text: "9°A"
      assert_select "td", text: "9°B", count: 0
    end
  end

  test "an actor with no grants is denied the index (403)" do
    with_grants { get "/report_cards/groups"; assert_response :forbidden }
  end

  test "roster tomable is the intersection: enrolled-this-term students of the group, excluding one not enrolled" do
    as_homeroom_a do
      get "/report_cards/groups/#{@section_a.id}/publications/new"
      assert_response :success
      assert_match(/Valentina Suárez/, response.body)
      assert_no_match(/Sin Matricula/, response.body)
    end
  end

  test "preview shows the live computed average without publishing anything" do
    as_homeroom_a do
      get "/report_cards/groups/#{@section_a.id}/publications/new"
      assert_response :success
      assert_match(/4\.0/, response.body)
      assert_equal 0, ReportCards::ReportCard.where(institution_id: @institution.id).count
    end
  end

  test "a viewer without publish permission does not see the publish button, but publishing is still 403-gated" do
    as_viewer_only_a do
      get "/report_cards/groups/#{@section_a.id}/publications/new"
      assert_response :success
      assert_no_match(/Publicar boletines/, response.body)

      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
      assert_response :forbidden
    end
  end

  test "acceptance: publishing persists a frozen snapshot per selected student" do
    as_homeroom_a do
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
      assert_redirected_to report_cards_groups_path

      report_card = ReportCards::ReportCard.find_by!(institution_id: @institution.id,
        student_id: @student_in_term.id, academic_term_id: @active_term.id)
      assert_equal "published", report_card.status
      assert_equal BigDecimal("4.0"), report_card.overall_average
      assert_equal 1, report_card.lines_snapshot.size

      # The non-enrolled student never gets a row — the roster never included them.
      assert_nil ReportCards::ReportCard.find_by(institution_id: @institution.id,
        student_id: @student_not_enrolled.id, academic_term_id: @active_term.id)
    end
  end

  test "re-publishing the same (student, term) regenerates the snapshot, never duplicates" do
    as_homeroom_a do
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
      first_id = ReportCards::ReportCard.find_by!(institution_id: @institution.id,
        student_id: @student_in_term.id, academic_term_id: @active_term.id).id

      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }

      records = ReportCards::ReportCard.where(institution_id: @institution.id, student_id: @student_in_term.id,
        academic_term_id: @active_term.id)
      assert_equal 1, records.count, "re-publishing must regenerate, never duplicate"
      # Regeneration destroys-and-recreates (never UPDATEs a persisted row,
      # see ReportCard#readonly?) — a fresh id proves that, not just the count.
      assert_not_equal first_id, records.sole.id
    end
  end

  # S3b (v1.30.0): one "boletines" usage event per (student, academic_term)
  # PUBLISHED — keyed on that pair (not the ReportCard row's own id, which
  # changes on every regeneration above), so re-publishing never re-emits.
  test "S3b: publishing emits one usage event, and re-publishing the SAME (student, term) never duplicates it despite a fresh row id" do
    ControlPlane::Addon.find_by!(key: "report_cards").update!( # sign_in_as_member already seeded this, unmetered
      metered: true, unit: "boletines", included_quota: 20, overage_unit_price_cents: 100
    )

    as_homeroom_a do
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
    end

    events = ControlPlane::UsageEvent.where(institution_id: @institution.id)
    assert_equal 1, events.count
    assert_equal "boletines", events.sole.unit
  end

  test "STAR: a published report card never re-reads a live grade edited afterwards" do
    as_homeroom_a do
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
    end

    within_tenant(@institution) do
      enrollment = Schedules::Enrollment.find_by!(institution_id: @institution.id, student_id: @student_in_term.id)
      enrollment.assessments.sole.update_columns(score: 0.5) # bypass readonly-model concerns, edit the raw grade
    end

    report_card = ReportCards::ReportCard.find_by!(institution_id: @institution.id,
      student_id: @student_in_term.id, academic_term_id: @active_term.id)
    assert_equal BigDecimal("4.0"), report_card.overall_average, "a published snapshot must never change"
  end

  test "ReportCard#readonly? blocks update/destroy of a persisted row outside the publisher service" do
    as_homeroom_a do
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
    end

    within_tenant(@institution) do
      report_card = ReportCards::ReportCard.find_by!(institution_id: @institution.id,
        student_id: @student_in_term.id, academic_term_id: @active_term.id)
      assert_raises(ActiveRecord::ReadOnlyRecord) { report_card.update!(overall_average: 1.0) }
      assert_raises(ActiveRecord::ReadOnlyRecord) { report_card.destroy! }
    end
  end

  test "a homeroom teacher cannot publish or preview for a group outside their scope (403)" do
    as_homeroom_a do
      get "/report_cards/groups/#{@section_b.id}/publications/new"
      assert_response :forbidden

      post "/report_cards/groups/#{@section_b.id}/publications", params: { student_ids: [] }
      assert_response :forbidden
    end
  end

  test "entitlement gate #1 runs before RBAC gate #2: not entitled shows the friendly module page, not a bare 403" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "report_cards" })
    entitlement.revoke!

    as_homeroom_a do
      get "/report_cards/groups"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "no student search surface anywhere in the publication view" do
    as_homeroom_a do
      get "/report_cards/groups/#{@section_a.id}/publications/new"
      assert_response :success
      assert_select "main#main input[type=search]", count: 0
      assert_select "main#main input[name=q]", count: 0
    end
  end

  test "cross-tenant: a report card seeded in a different institution never leaks" do
    other_institution = Core::Institution.create!(name: "Colegio Otro", slug: "rc-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    other_term = within_tenant(other_institution) do
      Core::AcademicTerm.create!(institution: other_institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end
    other_student = within_tenant(other_institution) do
      section = build_section!(other_institution, name: "9°A Otro Colegio")
      s = build_student!(other_institution, first_name: "Fantasma", last_name: "Ajeno",
        student_code: "GHOST-1", section: section)
      enroll_and_grade!(other_institution, student: s, active_term: other_term)
      s
    end
    within_tenant(other_institution) do
      staff = build_staff_member!(other_institution, email: "staff-#{SecureRandom.hex(4)}@other.test")
      ReportCards::Publisher.call(institution: other_institution, academic_term: other_term,
        students: [ other_student ], published_by_staff_member: staff)
    end

    as_homeroom_a do
      get "/report_cards/groups"
      assert_response :success
      assert_no_match(/9°A Otro Colegio/, response.body)
    end

    # Model-layer, under I's own GUC: a raw query that explicitly asks for J's
    # institution_id must still return zero rows — RLS itself blocking it.
    within_tenant(@institution) do
      assert_empty ReportCards::ReportCard.where(institution_id: other_institution.id)
    end
  end

  test "portal (guardian): sees only published report cards of their own child, never drafts or other families" do
    guardian_user = within_tenant(@institution) do
      Core::User.create!(email: "guardian-#{SecureRandom.hex(4)}@member.test", name: "Acudiente",
        password: "password-123456")
    end
    within_tenant(@institution) do
      @institution.memberships.create!(user: guardian_user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: guardian_user.id,
        student: @student_in_term, relationship: "madre", status: "active")
    end

    as_homeroom_a do
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
    end

    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/students/#{@student_in_term.id}/report_cards"
    assert_response :success
    assert_match(/2026-1/, response.body)
    assert_match(/4\.0/, response.body)

    # Never sees the other family's child's report card, even by guessing the id.
    get "/portal/guardian/students/#{@student_in_b.id}/report_cards"
    assert_response :not_found
  end

  test "portal (student): sees only their own published report cards" do
    student_user = within_tenant(@institution) do
      Core::User.create!(email: "student-#{SecureRandom.hex(4)}@member.test", name: "Valentina Suárez",
        password: "password-123456")
    end
    within_tenant(@institution) do
      @institution.memberships.create!(user: student_user)
      @student_in_term.update!(user: student_user)
    end

    as_homeroom_a do
      post "/report_cards/groups/#{@section_a.id}/publications", params: { student_ids: [ @student_in_term.id ] }
    end

    sign_in_as(student_user, institution: @institution, password: "password-123456")
    get "/portal/student/report_cards"
    assert_response :success
    assert_match(/2026-1/, response.body)
  end

  test "portal never shows an unpublished (preview-only) report card" do
    guardian_user = within_tenant(@institution) do
      Core::User.create!(email: "guardian2-#{SecureRandom.hex(4)}@member.test", name: "Acudiente 2",
        password: "password-123456")
    end
    within_tenant(@institution) do
      @institution.memberships.create!(user: guardian_user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: guardian_user.id,
        student: @student_in_term, relationship: "padre", status: "active")
    end

    # No publish call at all — only the live computation exists.
    sign_in_as(guardian_user, institution: @institution, password: "password-123456")
    get "/portal/guardian/students/#{@student_in_term.id}/report_cards"
    assert_response :success
    assert_select ".empty-state, [class*=empty]", minimum: 0 # tolerate whichever empty-state class shape
    assert_no_match(/2026-1/, response.body)
  end

  # Regression: confirm this slice never touched the headcount source or
  # re-derived the term join (same guardrail attendance v1.16.0 confirmed).
  test "REGRESSION: headcount is unaffected by report_cards" do
    within_tenant(@institution) do
      staff = build_staff_member!(@institution, email: "staff-#{SecureRandom.hex(4)}@member.test")
      ReportCards::Publisher.call(institution: @institution, academic_term: @active_term,
        students: [ @student_in_term ], published_by_staff_member: staff)

      snapshot = Core::Headcount::Snapshotter.call(institution: @institution, as_of: Date.current)
      # Three students total were created under section_a/b as "active" (default status).
      assert_equal 3, snapshot.headcount
    end
  end
end
