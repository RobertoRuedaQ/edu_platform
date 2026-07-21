require "test_helper"

# Slice 6 (BI_DOCUMENT.md §4, §5.4): Lens 2 "Ficha de Personaje" as a portal
# surface. SELF-SERVICE — access by RELATION (GuardianScope / StudentSelfScope),
# never RBAC. A child outside the caller's active links 404s ("caso de María").
# The card is strengths-only and dignified (§1.1.4) — never a numeric score.
class PortalsCharacterCardTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def build_student!(code, user: nil)
    GroupManagement::Student.create!(institution: @institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023,
      status: "active", section: @section, user: user)
  end

  setup do
    slug = "pcc-#{SecureRandom.hex(4)}"
    @institution = Core::Institution.create!(name: "Colegio #{slug}", slug: slug,
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    @guardian = Core::User.create!(email: "g#{SecureRandom.hex(3)}@correo.test", name: "Guardiana G", password: "password-123456")
    @student_user = Core::User.create!(email: "s#{SecureRandom.hex(3)}@correo.test", name: "Estu E", password: "password-123456")

    within_tenant(@institution) do
      @institution.memberships.create!(user: @guardian)
      @institution.memberships.create!(user: @student_user)
      @author = @institution.memberships.create!(
        user: Core::User.create!(email: "a#{SecureRandom.hex(3)}@correo.test", name: "Docente", password: "password-123456"))
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @child = build_student!("CHILD-1")
      @other_child = build_student!("CHILD-2")
      @self_student = build_student!("SELF-1", user: @student_user)
      Core::GuardianStudent.create!(institution: @institution, guardian_user_id: @guardian.id,
        student_id: @child.id, relationship: "madre", status: "active")
      build_and_publish_evaluation(@child)
    end
  end

  def build_and_publish_evaluation(student)
    framework = AnalyticsBi::CharacterFramework.create!(institution: @institution, name: "Marco base", status: "published")
    empatia = AnalyticsBi::CharacterDimension.create!(institution: @institution, framework: framework,
      name: "Empatía", position: 0, weight: 1)
    %w[En\ desarrollo Consolidado].each_with_index do |label, i|
      AnalyticsBi::CharacterLevel.create!(institution: @institution, dimension: empatia,
        label: label, descriptor: "#{label} en empatía.", position: i)
    end
    AnalyticsBi::Character::Publisher.call(framework: framework, student: student, academic_term: @term,
      author: @author, institution: @institution,
      selections: [ { dimension_key: empatia.id, level_label: "Consolidado" } ])
  end

  def sign_in_guardian = sign_in_as(@guardian, institution: @institution, password: "password-123456")
  def sign_in_student = sign_in_as(@student_user, institution: @institution, password: "password-123456")

  test "guardian sees their child's card in qualitative terms, with no numeric score" do
    sign_in_guardian
    get portal_guardian_student_character_card_path(@child)
    assert_response :success
    assert_match "Empatía", response.body
    assert_match "Consolidado", response.body
    assert_no_match(/Empatía:\s*\d/, response.body, "the ordinal must never render as a score")
  end

  test "SECURITY (caso de María): guardian cannot see another guardian's child card (404)" do
    sign_in_guardian
    get portal_guardian_student_character_card_path(@other_child)
    assert_response :not_found
  end

  test "the student sees their own card by self-scope" do
    sign_in_student
    get portal_student_character_card_path
    assert_response :success
    assert_match "Mi ficha de carácter", response.body
  end

  test "a guardian with no published evaluation sees the true empty state" do
    within_tenant(@institution) { AnalyticsBi::CharacterEvaluation.where(student_id: @child.id).update_all(status: "draft") }
    sign_in_guardian
    get portal_guardian_student_character_card_path(@child)
    assert_response :success
    assert_match "Aún no hay una evaluación de carácter publicada", response.body
  end

  test "acceptance: guardian grants then revokes peer-path consent for their own child" do
    sign_in_guardian
    assert_difference -> { active_consents_for(@child) }, 1 do
      post portal_guardian_student_character_consent_path(@child)
    end
    assert_redirected_to portal_guardian_student_character_card_path(@child)

    assert_difference -> { active_consents_for(@child) }, -1 do
      delete portal_guardian_student_character_consent_path(@child)
    end
  end

  test "SECURITY: guardian cannot grant consent for a child that is not theirs (404)" do
    sign_in_guardian
    assert_no_difference -> { active_consents_for(@other_child) } do
      post portal_guardian_student_character_consent_path(@other_child)
    end
    assert_response :not_found
  end

  def active_consents_for(student)
    within_tenant(@institution) do
      AnalyticsBi::CharacterProgramConsent.active.where(institution_id: @institution.id, student_id: student.id).count
    end
  end
end
