require "test_helper"

# extracurriculars (net-new addon domain, v1.27.0, item #8 del camino crítico
# del MVP). Molde #4 (authorize! duro + Query object de scope), pero con un
# giro: el scope del instructor es PROPIEDAD de fila (instructor_staff_member_id
# == mi StaffMember), NO scope de rol — Extracurriculars::ActivityScope lo
# filtra por FK, covers?/role_assignments quedan intactos. Actividad paga => un
# Finance::Charge (puente cents->decimal exacto), nunca un cobro propio.
class ExtracurricularsTest < ActionDispatch::IntegrationTest
  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_staff_member!(institution, user:)
    institution_user = institution.memberships.active.find_by!(user: user)
    StaffManagement::StaffMember.create!(institution: institution, institution_user: institution_user,
      employee_number: "EMP-#{SecureRandom.hex(3)}", staff_category: "teaching",
      employment_type: "full_time", status: "active")
  end

  def build_student!(institution, code:)
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023)
  end

  def build_activity!(institution, name:, term:, instructor: nil, capacity: 10, fee_cents: nil, status: "published")
    Extracurriculars::Activity.create!(institution: institution, academic_term: term, name: name,
      kind: "sport", capacity: capacity, instructor_staff_member: instructor, fee_cents: fee_cents, status: status)
  end

  setup do
    @user, @institution = sign_in_as_member # extracurriculars entitled by default (grant_full_entitlements)

    @term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    # El actor ES el instructor A (su institution_user tiene un StaffMember).
    @actor_staff = within_tenant(@institution) { build_staff_member!(@institution, user: @user) }

    # Un segundo staff (instructor B), otra persona — el dueño de la actividad ajena.
    @other_user = Core::User.create!(email: "b#{SecureRandom.hex(3)}@staff.test", name: "Instructor B",
      password: "password-123456")
    @other_staff = within_tenant(@institution) do
      @institution.memberships.create!(user: @other_user)
      build_staff_member!(@institution, user: @other_user)
    end

    @activity_a = within_tenant(@institution) { build_activity!(@institution, name: "Fútbol A", term: @term, instructor: @actor_staff) }
    @activity_b = within_tenant(@institution) { build_activity!(@institution, name: "Ajedrez B", term: @term, instructor: @other_staff) }
    @activity_free = within_tenant(@institution) { build_activity!(@institution, name: "Coro", term: @term) }

    @student = within_tenant(@institution) { build_student!(@institution, code: "X-001") }
  end

  def as_coordinator(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "activity_coordinator",
        permission_keys: %w[activity.manage activity.instruct], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  # Instructor: activity.instruct institución-wide — pero la PROPIEDAD la hace
  # cumplir ActivityScope por FK, no el scope del rol. Que sea institution-wide
  # y aun así solo vea las propias es exactamente lo que se prueba.
  def as_instructor(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "activity_instructor",
        permission_keys: %w[activity.instruct], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "coordinator sees every activity in the institution" do
    as_coordinator do
      get "/extracurriculars/activities"
      assert_response :success
      assert_match(/Fútbol A/, response.body)
      assert_match(/Ajedrez B/, response.body)
      assert_match(/Coro/, response.body)
    end
  end

  test "instructor sees ONLY their own activities (ownership by FK, not role scope)" do
    as_instructor do
      get "/extracurriculars/activities"
      assert_response :success
      assert_match(/Fútbol A/, response.body)
      assert_no_match(/Ajedrez B/, response.body)
      assert_no_match(/Coro/, response.body)
    end
  end

  test "instructor cannot view or enroll into another instructor's activity (404, out of scope)" do
    as_instructor do
      get "/extracurriculars/activities/#{@activity_b.id}"
      assert_response :not_found

      post "/extracurriculars/activities/#{@activity_b.id}/enrollments", params: { student_id: @student.id }
      assert_response :not_found
    end
  end

  test "instructor cannot create an activity (activity.manage only)" do
    as_instructor do
      get "/extracurriculars/activities/new"
      assert_response :forbidden
    end
  end

  test "an actor with neither permission is denied the index (403)" do
    with_grants { get "/extracurriculars/activities"; assert_response :forbidden }
  end

  test "acceptance: coordinator enrolls a student, and withdrawing is SOFT (never destroyed)" do
    as_coordinator do
      post "/extracurriculars/activities/#{@activity_a.id}/enrollments", params: { student_id: @student.id }
      assert_redirected_to extracurriculars_activity_path(@activity_a)

      enrollment = Extracurriculars::Enrollment.find_by!(institution_id: @institution.id,
        activity_id: @activity_a.id, student_id: @student.id)
      assert_equal "active", enrollment.status
      assert_equal "staff", enrollment.enrolled_via

      delete "/extracurriculars/activities/#{@activity_a.id}/enrollments/#{enrollment.id}"
      enrollment.reload
      assert_equal "withdrawn", enrollment.status
      assert_not_nil enrollment.withdrawn_at
      # Nunca se destruye — la fila sigue ahí como historial.
      assert Extracurriculars::Enrollment.exists?(enrollment.id)
    end
  end

  test "capacity is enforced: the enrollment over capacity is rejected, no row created" do
    small = within_tenant(@institution) { build_activity!(@institution, name: "Cupo 1", term: @term, instructor: @actor_staff, capacity: 1) }
    other_student = within_tenant(@institution) { build_student!(@institution, code: "X-002") }

    as_coordinator do
      post "/extracurriculars/activities/#{small.id}/enrollments", params: { student_id: @student.id }
      post "/extracurriculars/activities/#{small.id}/enrollments", params: { student_id: other_student.id }
      assert_redirected_to extracurriculars_activity_path(small)
      follow_redirect!
      assert_match(/cupo/i, response.body)
    end

    assert_equal 1, Extracurriculars::Enrollment.where(institution_id: @institution.id,
      activity_id: small.id, status: "active").count
  end

  test "service-level: filling capacity then enrolling once more raises CapacityExceeded" do
    within_tenant(@institution) do
      small = build_activity!(@institution, name: "Solo uno", term: @term, capacity: 1)
      s1 = build_student!(@institution, code: "CAP-1")
      s2 = build_student!(@institution, code: "CAP-2")

      Extracurriculars::EnrollmentCreator.call(institution: @institution, activity: small, student: s1, enrolled_via: "staff")
      assert_raises(Extracurriculars::EnrollmentCreator::CapacityExceeded) do
        Extracurriculars::EnrollmentCreator.call(institution: @institution, activity: small, student: s2, enrolled_via: "staff")
      end
    end
  end

  test "re-enrolling after a withdrawal appends a new active row, keeping only one active" do
    within_tenant(@institution) do
      Extracurriculars::EnrollmentCreator.call(institution: @institution, activity: @activity_a, student: @student, enrolled_via: "staff")
      Extracurriculars::EnrollmentWithdrawer.call(institution: @institution, activity: @activity_a, student: @student)
      Extracurriculars::EnrollmentCreator.call(institution: @institution, activity: @activity_a, student: @student, enrolled_via: "guardian")

      all = Extracurriculars::Enrollment.where(institution_id: @institution.id, activity_id: @activity_a.id, student_id: @student.id)
      assert_equal 2, all.count, "history preserved: one withdrawn + one active"
      assert_equal 1, all.where(status: "active").count, "at most one active"
    end
  end

  test "paid activity creates a Finance::Charge with exact cents->decimal conversion and raises the balance" do
    paid = within_tenant(@institution) { build_activity!(@institution, name: "Robótica", term: @term, instructor: @actor_staff, fee_cents: 5_000_000) }

    as_coordinator do
      post "/extracurriculars/activities/#{paid.id}/enrollments",
        params: { student_id: @student.id, idempotency_key: "idem-paid-1" }
    end

    within_tenant(@institution) do
      charge = Finance::Charge.find_by!(institution_id: @institution.id, idempotency_key: "idem-paid-1")
      assert_equal BigDecimal("50000.00"), charge.amount
      assert_equal "COP", charge.currency
      assert_match(/Robótica/, charge.description)

      account = Finance::StudentAccount.find_by!(institution_id: @institution.id, student_id: @student.id)
      assert_equal BigDecimal("50000.00"), account.balance
    end
  end

  test "paid enrollment is idempotent: a double submit creates exactly one charge" do
    paid = within_tenant(@institution) { build_activity!(@institution, name: "Natación", term: @term, instructor: @actor_staff, fee_cents: 3_000_000) }

    as_coordinator do
      2.times do
        post "/extracurriculars/activities/#{paid.id}/enrollments",
          params: { student_id: @student.id, idempotency_key: "idem-paid-2" }
      end
    end

    within_tenant(@institution) do
      assert_equal 1, Finance::Charge.where(institution_id: @institution.id, idempotency_key: "idem-paid-2").count
      assert_equal 1, Extracurriculars::Enrollment.where(institution_id: @institution.id,
        activity_id: paid.id, student_id: @student.id, status: "active").count
    end
  end

  test "entitlement gate #1 runs before RBAC gate #2: not entitled shows the friendly module page" do
    entitlement = ControlPlane::Entitlement.joins(:addon).find_by!(institution_id: @institution.id,
      addons: { key: "extracurriculars" })
    entitlement.revoke!

    as_coordinator do
      get "/extracurriculars/activities"
      assert_response :forbidden
      assert_match "no está habilitado", response.body
    end
  end

  test "cross-tenant: an activity seeded in another institution never leaks into the index" do
    other = Core::Institution.create!(name: "Colegio Otro", slug: "ext-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    other_term = within_tenant(other) do
      Core::AcademicTerm.create!(institution: other, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end
    within_tenant(other) { build_activity!(other, name: "Actividad Ajena", term: other_term) }

    as_coordinator do
      get "/extracurriculars/activities"
      assert_response :success
      assert_no_match(/Actividad Ajena/, response.body)
    end

    within_tenant(@institution) do
      assert_empty Extracurriculars::Activity.where(institution_id: other.id, name: "Actividad Ajena")
    end
  end

  # S3b (v1.30.0): one "inscripciones" usage event per NEW active enrollment —
  # re-enrolling the SAME (activity, student) while already active is a no-op
  # (EnrollmentCreator's own idempotency guard), so it never re-emits either.
  test "S3b: enrolling emits one usage event, and re-enrolling while already active never duplicates it" do
    ControlPlane::Addon.find_by!(key: "extracurriculars").update!( # sign_in_as_member already seeded this, unmetered
      metered: true, unit: "inscripciones", included_quota: 5, overage_unit_price_cents: 200
    )

    as_coordinator do
      post "/extracurriculars/activities/#{@activity_a.id}/enrollments", params: { student_id: @student.id }
      post "/extracurriculars/activities/#{@activity_a.id}/enrollments", params: { student_id: @student.id }
    end

    events = ControlPlane::UsageEvent.where(institution_id: @institution.id)
    assert_equal 1, events.count
    assert_equal "inscripciones", events.sole.unit
  end
end
