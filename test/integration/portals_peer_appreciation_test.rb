require "test_helper"

# Slice 6 (BI_DOCUMENT.md §5.4, deferred from Slice 5): the student peer-giving
# surface. Identity action (no RBAC): the giver is StudentSelfScope, the picker
# is a CLOSED roster of current section co-members (§1.1.6 — never a search), the
# tag is from the CLOSED active catalog. The Recorder's consent gate + scoped
# recipient lookup are enforced; rejections are friendly flashes, never a 500.
class PortalsPeerAppreciationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def build_student!(code, section:, user: nil)
    GroupManagement::Student.create!(institution: @institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023,
      status: "active", section: section, user: user)
  end

  setup do
    slug = "ppa-#{SecureRandom.hex(4)}"
    @institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    @giver_user = Core::User.create!(email: "s#{SecureRandom.hex(3)}@correo.test", name: "Giver G", password: "password-123456")
    @guardian = Core::User.create!(email: "g#{SecureRandom.hex(3)}@correo.test", name: "Acudiente A", password: "password-123456")

    within_tenant(@institution) do
      @institution.memberships.create!(user: @giver_user)
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @other_section = GroupManagement::Section.create!(institution: @institution, name: "9°B", academic_year: 2026)
      @giver = build_student!("GIVER-1", section: @section, user: @giver_user)
      @classmate = build_student!("MATE-1", section: @section)
      @outsider = build_student!("OUT-1", section: @other_section)
      @tag = AnalyticsBi::PeerAppreciationTag.create!(institution: @institution,
        label: "Buen compañero", category: "convivencia", active: true)
    end
  end

  def sign_in_giver = sign_in_as(@giver_user, institution: @institution, password: "password-123456")

  def consent!(student)
    within_tenant(@institution) do
      AnalyticsBi::CharacterProgramConsent.grant!(student: student, guardian_user: @guardian, institution: @institution)
    end
  end

  def active_appreciations_for(student)
    within_tenant(@institution) do
      AnalyticsBi::PeerAppreciation.active.where(institution_id: @institution.id, student_id: student.id).count
    end
  end

  test "the picker lists only current section co-members, never an outsider or the giver" do
    sign_in_giver
    get new_portal_student_peer_appreciation_path
    assert_response :success
    assert_match "MATE-1", response.body
    assert_no_match(/OUT-1/, response.body, "a student in another section is never offered (§1.1.6)")
    assert_no_match(/GIVER-1/, response.body, "the giver never appears in their own picker")
  end

  test "acceptance: a student recognizes a section co-member when consent is in place" do
    consent!(@giver)
    consent!(@classmate)
    sign_in_giver
    assert_difference -> { active_appreciations_for(@classmate) }, 1 do
      post portal_student_peer_appreciation_path, params: { recipient_student_id: @classmate.id, tag_id: @tag.id }
    end
    assert_redirected_to new_portal_student_peer_appreciation_path
  end

  test "SECURITY: a non-section-mate cannot be targeted (rescued, no record, friendly flash)" do
    consent!(@giver)
    consent!(@outsider)
    sign_in_giver
    assert_no_difference -> { active_appreciations_for(@outsider) } do
      post portal_student_peer_appreciation_path, params: { recipient_student_id: @outsider.id, tag_id: @tag.id }
    end
    assert_redirected_to new_portal_student_peer_appreciation_path
    follow_redirect!
    assert_match "Elige un compañero de tu grupo", response.body
  end

  test "the consent gate is respected: without consent nothing is recorded, no 500" do
    sign_in_giver # neither giver nor recipient has consent
    assert_no_difference -> { active_appreciations_for(@classmate) } do
      post portal_student_peer_appreciation_path, params: { recipient_student_id: @classmate.id, tag_id: @tag.id }
    end
    assert_redirected_to new_portal_student_peer_appreciation_path
    follow_redirect!
    assert_match "consentimiento del acudiente", response.body
  end

  test "an inactive tag is rejected with a friendly flash, never a 500" do
    consent!(@giver)
    consent!(@classmate)
    within_tenant(@institution) { @tag.update!(active: false) }
    sign_in_giver
    assert_no_difference -> { active_appreciations_for(@classmate) } do
      post portal_student_peer_appreciation_path, params: { recipient_student_id: @classmate.id, tag_id: @tag.id }
    end
    follow_redirect!
    assert_match "Elige un compañero de tu grupo y una etiqueta válida", response.body
  end
end
