require "test_helper"

# extracurriculars — superficie de PORTAL (v1.27.0). Acceso por RELACIÓN, nunca
# RBAC (§7): el estudiante ve sus propias inscripciones (solo lectura); el
# acudiente inscribe/desinscribe a UN hijo ya scopeado (B1). Doble salto
# GuardianScope -> StudentActivities.enrollable, misma disciplina que las
# entregas del acudiente — un hijo o una actividad fuera de alcance 404.
class PortalsExtracurricularsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def within_tenant(institution, &block)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      block.call
    end
  end

  def build_student!(institution, code:, user: nil)
    GroupManagement::Student.create!(institution: institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023, user: user)
  end

  def build_activity!(institution, name:, term:, capacity: 10, fee_cents: nil, status: "published")
    Extracurriculars::Activity.create!(institution: institution, academic_term: term, name: name,
      kind: "art", capacity: capacity, fee_cents: fee_cents, status: status)
  end

  setup do
    slug = "pex-#{SecureRandom.hex(4)}"
    @institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")

    @guardian = Core::User.create!(email: "g#{SecureRandom.hex(3)}@correo.test", name: "Guardiana G",
      password: "password-123456")
    @student_user = Core::User.create!(email: "s#{SecureRandom.hex(3)}@correo.test", name: "Estu E",
      password: "password-123456")

    @term = within_tenant(@institution) do
      Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
    end

    within_tenant(@institution) do
      @institution.memberships.create!(user: @guardian)
      @institution.memberships.create!(user: @student_user)
    end

    @child = within_tenant(@institution) { build_student!(@institution, code: "CHILD-1") }
    @other_child = within_tenant(@institution) { build_student!(@institution, code: "CHILD-2") }
    @self_student = within_tenant(@institution) { build_student!(@institution, code: "SELF-1", user: @student_user) }

    within_tenant(@institution) do
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: @guardian.id,
        student_id: @child.id, relationship: "madre", status: "active")
    end

    @free = within_tenant(@institution) { build_activity!(@institution, name: "Coro", term: @term) }
    @paid = within_tenant(@institution) { build_activity!(@institution, name: "Robótica", term: @term, fee_cents: 4_000_000) }
    @draft = within_tenant(@institution) { build_activity!(@institution, name: "Borrador Secreto", term: @term, status: "draft") }
  end

  def sign_in_guardian
    sign_in_as(@guardian, institution: @institution, password: "password-123456")
  end

  def sign_in_student
    sign_in_as(@student_user, institution: @institution, password: "password-123456")
  end

  test "guardian sees their child's available activities but never a draft" do
    sign_in_guardian
    get portal_guardian_student_activities_path(@child)
    assert_response :success
    assert_match(/Coro/, response.body)
    assert_match(/Robótica/, response.body)
    assert_no_match(/Borrador Secreto/, response.body)
  end

  test "acceptance: guardian enrolls their child in a free activity — attributed to the guardian" do
    sign_in_guardian
    post portal_guardian_student_activity_enrollment_path(@child, @free)
    assert_redirected_to portal_guardian_student_activity_path(@child, @free)

    enrollment = Extracurriculars::Enrollment.find_by!(institution_id: @institution.id,
      activity_id: @free.id, student_id: @child.id)
    assert_equal "active", enrollment.status
    assert_equal "guardian", enrollment.enrolled_via
    assert_equal @guardian.id, enrollment.enrolled_by_user_id
  end

  test "guardian enrolling in a PAID activity creates a Charge against the child's account" do
    sign_in_guardian
    post portal_guardian_student_activity_enrollment_path(@child, @paid), params: { idempotency_key: "g-idem-1" }

    within_tenant(@institution) do
      charge = Finance::Charge.find_by!(institution_id: @institution.id, idempotency_key: "g-idem-1")
      assert_equal BigDecimal("40000.00"), charge.amount
      account = Finance::StudentAccount.find_by!(institution_id: @institution.id, student_id: @child.id)
      assert_equal BigDecimal("40000.00"), account.balance
    end
  end

  test "guardian withdraws their child (soft) and the row survives as history" do
    within_tenant(@institution) do
      Extracurriculars::EnrollmentCreator.call(institution: @institution, activity: @free, student: @child, enrolled_via: "guardian")
    end

    sign_in_guardian
    delete portal_guardian_student_activity_enrollment_path(@child, @free)

    within_tenant(@institution) do
      enrollment = Extracurriculars::Enrollment.find_by!(institution_id: @institution.id,
        activity_id: @free.id, student_id: @child.id)
      assert_equal "withdrawn", enrollment.status
    end
  end

  test "SECURITY: guardian cannot enroll someone else's child (404, not 403)" do
    sign_in_guardian
    post portal_guardian_student_activity_enrollment_path(@other_child, @free)
    assert_response :not_found

    assert_nil Extracurriculars::Enrollment.find_by(institution_id: @institution.id,
      activity_id: @free.id, student_id: @other_child.id)
  end

  test "SECURITY: guardian cannot enroll their child into a draft activity (404, out of enrollable scope)" do
    sign_in_guardian
    post portal_guardian_student_activity_enrollment_path(@child, @draft)
    assert_response :not_found
  end

  test "capacity from the portal: enrolling into a full activity is rejected with an alert" do
    full = within_tenant(@institution) { build_activity!(@institution, name: "Lleno", term: @term, capacity: 1) }
    within_tenant(@institution) do
      Extracurriculars::EnrollmentCreator.call(institution: @institution, activity: full, student: @other_child, enrolled_via: "staff")
    end

    sign_in_guardian
    post portal_guardian_student_activity_enrollment_path(@child, full)
    assert_redirected_to portal_guardian_student_activities_path(@child)
    follow_redirect!
    assert_match(/cupo/i, response.body)

    assert_nil Extracurriculars::Enrollment.find_by(institution_id: @institution.id,
      activity_id: full.id, student_id: @child.id)
  end

  test "student portal lists the student's OWN active enrollments, read-only (no enroll control)" do
    within_tenant(@institution) do
      Extracurriculars::EnrollmentCreator.call(institution: @institution, activity: @free, student: @self_student, enrolled_via: "staff")
    end

    sign_in_student
    get portal_student_activities_path
    assert_response :success
    assert_match(/Coro/, response.body)
    # Solo lectura: sin formulario de inscripción en la superficie del estudiante.
    assert_select "form[action*=enrollment]", count: 0
  end
end
