require "test_helper"

# Slice 8 (BI_DOCUMENT.md §4/§5.6/§6.2): HTTP-level acceptance for Lens 4.
# SUPERVISION (molde #4), institution-wide ONLY (no smaller scope reader for
# this lens) — the default persona (lacking hps.family.view) is denied.
# custody_kind must never leak into the rendered response even though it is a
# real, populated column on the underlying model.
class AnalyticsBiFamilyCoreTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member # default grant does NOT include hps.family.view
    within_tenant(@institution) do
      grade = GroupManagement::GradeLevel.create!(institution: @institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: @institution, grade_level: grade, name: "9A", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, grade_level: grade, section: section,
        first_name: "Ana", last_name: "P", gender: "female", birthdate: Date.new(2013, 3, 1),
        student_code: "AFC-ANA", entry_year: 2023, status: "active")
      @mom = Core::User.create!(email: "afc-mom-#{SecureRandom.hex(4)}@test", name: "Mamá", password: "password-123456")
      gs = Core::GuardianStudent.create!(institution: @institution, guardian: @mom, student: @student, relationship: "madre", status: "active")
      AnalyticsBi::GuardianRelationship.create!(institution: @institution, guardian_student: gs,
        relationship_kind: "mother", is_primary_caregiver: true, custody_kind: "sole")
    end
  end

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def as_viewer(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "hps_family_viewer",
        permission_keys: %w[hps.family.view], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "the default persona (no hps.family.view) is denied (403)" do
    get analytics_bi_family_core_path(@student.id)
    assert_response :forbidden
  end

  test "an hps.family.view holder sees the family core, and custody_kind never appears in the response" do
    as_viewer do
      get analytics_bi_family_core_path(@student.id)
      assert_response :success
      assert_match "Mamá", response.body
      assert_no_match(/sole/, response.body)
      assert_no_match(/custody/i, response.body)
    end
  end

  test "a foreign student id 404s (cross-tenant / unknown id), never leaks another institution's family" do
    other_institution = Core::Institution.create!(name: "Otro", slug: "afc-other-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    other_student = within_tenant(other_institution) do
      grade = GroupManagement::GradeLevel.create!(institution: other_institution, name: "Grado 9", level_number: 9)
      section = GroupManagement::Section.create!(institution: other_institution, grade_level: grade, name: "9A", academic_year: 2026)
      GroupManagement::Student.create!(institution: other_institution, grade_level: grade, section: section,
        first_name: "Otro", last_name: "Estudiante", gender: "male", birthdate: Date.new(2013, 3, 1),
        student_code: "OTHER-1", entry_year: 2023, status: "active")
    end

    as_viewer do
      get analytics_bi_family_core_path(other_student.id)
      assert_response :not_found
    end
  end

  test "no audit event is written on a plain view with no sibling alert" do
    as_viewer do
      assert_no_difference -> { IdentityAccess::AuditEvent.where(action: "family_core.sibling_alert_viewed").count } do
        get analytics_bi_family_core_path(@student.id)
      end
    end
  end
end
