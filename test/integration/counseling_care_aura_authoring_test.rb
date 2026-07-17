require "test_helper"

# Slice 3 (BI_DOCUMENT.md §5.7, §4): the counselor-side AUTHORING surface for
# care auras. Write is gated by the EXISTING counseling.write key (never a new
# one); reading a case (counseling.read) is NOT enough to publish. Publishing
# goes through the analytics_bi Projector; counseling never writes the
# projection table directly.
class CounselingCareAuraAuthoringTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member # default grant includes counseling.read, NOT counseling.write
    within_tenant(@institution) do
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "P",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "AU-ANA", entry_year: 2023,
        status: "active", section: @section)
      counselor = @institution.memberships.active.find_by!(user: @user)
      @case = Counseling::Case.create!(institution: @institution, student: @student, opened_by: counselor,
        category: "academic", status: "open", opened_at: Time.current)
    end
  end

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def as_counselor(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "counselor",
        permission_keys: %w[counseling.read counseling.write], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  test "counseling.read alone cannot reach the authoring surface (403)" do
    # default persona holds counseling.read but not counseling.write
    get new_counseling_case_care_aura_path(@case)
    assert_response :forbidden

    post counseling_case_care_auras_path(@case), params: { aura_kind: "extra_time", guidance_text: "x" }
    assert_response :forbidden
    assert_equal 0, AnalyticsBi::CareAura.count
  end

  test "a counselor publishes an aura through the analytics_bi projector" do
    as_counselor do
      assert_difference -> { AnalyticsBi::CareAura.count }, 1 do
        post counseling_case_care_auras_path(@case),
          params: { aura_kind: "private_or_oral_evaluation", guidance_text: "Evaluaciones en privado." }
      end
      assert_redirected_to counseling_case_path(@case)

      aura = within_tenant(@institution) { AnalyticsBi::CareAura.last }
      assert_equal "private_or_oral_evaluation", aura.aura_kind
      assert_equal "Evaluaciones en privado.", aura.guidance_text
      assert_equal @student.id, aura.student_id
      counselor = within_tenant(@institution) { @institution.memberships.active.find_by!(user: @user) }
      assert_equal counselor.id, aura.authored_by_counselor_id
    end
  end

  test "the published aura appears on the case show for the counselor" do
    as_counselor do
      post counseling_case_care_auras_path(@case),
        params: { aura_kind: "quiet_space", guidance_text: "Ubícalo lejos del ruido." }
      get counseling_case_path(@case)
      assert_response :success
      assert_match "Espacio tranquilo", response.body
      assert_match "Ubícalo lejos del ruido", response.body
    end
  end

  test "republishing the same kind is append-only (one active, history preserved)" do
    as_counselor do
      post counseling_case_care_auras_path(@case), params: { aura_kind: "extra_time", guidance_text: "v1" }
      post counseling_case_care_auras_path(@case), params: { aura_kind: "extra_time", guidance_text: "v2" }

      within_tenant(@institution) do
        rows = AnalyticsBi::CareAura.where(student_id: @student.id, aura_kind: "extra_time")
        assert_equal 2, rows.count
        assert_equal 1, rows.active.count
        assert_equal "v2", rows.active.first.guidance_text
      end
    end
  end

  test "retiring an aura closes it (effective_until set), still gated by counseling.write" do
    aura = nil
    as_counselor do
      post counseling_case_care_auras_path(@case), params: { aura_kind: "extra_time", guidance_text: "v1" }
      aura = within_tenant(@institution) { AnalyticsBi::CareAura.last }
      delete counseling_case_care_aura_path(@case, aura.id)
      assert_redirected_to counseling_case_path(@case)
    end
    within_tenant(@institution) { assert_equal Date.current, aura.reload.effective_until }
  end
end
