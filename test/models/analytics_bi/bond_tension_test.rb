require "test_helper"

# Slice 8 (BI_DOCUMENT.md §5.6, decision A6: computed LIVE, never persisted).
# AnalyticsBi::Lens::BondTension derives guardian engagement from real T1
# signals only (login recency, message-read recency) — nil when neither
# signal exists, never a misleading zero (same convention as
# SpatialHeatmap/Hps::Snapshotter's heat/wellbeing).
class AnalyticsBi::BondTensionTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "bt-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_guardian
    Core::User.create!(email: "bt-#{SecureRandom.hex(4)}@test", name: "Acudiente", password: "password-123456")
  end

  test "no signals at all -> nil engagement/tension, never a misleading zero" do
    institution = build_institution
    within_tenant(institution) do
      guardian = build_guardian
      result = AnalyticsBi::Lens::BondTension.for(guardian_user_id: guardian.id, institution: institution)

      assert_nil result.engagement
      assert_nil result.tension
      assert_equal "Sin datos suficientes", result.label
    end
  end

  test "a recent login alone yields high engagement and the 'Comprometido' label" do
    institution = build_institution
    within_tenant(institution) do
      guardian = build_guardian
      Core::Session.create!(user: guardian, current_institution: institution, created_at: 2.days.ago)

      result = AnalyticsBi::Lens::BondTension.for(guardian_user_id: guardian.id, institution: institution)
      assert_in_delta 1.0, result.engagement, 0.001
      assert_in_delta 0.0, result.tension, 0.001
      assert_equal "Comprometido", result.label
    end
  end

  test "an old login alone (>90 days) yields low engagement" do
    institution = build_institution
    within_tenant(institution) do
      guardian = build_guardian
      Core::Session.create!(user: guardian, current_institution: institution, created_at: 200.days.ago)

      result = AnalyticsBi::Lens::BondTension.for(guardian_user_id: guardian.id, institution: institution)
      assert_in_delta 0.0, result.engagement, 0.001
      assert_equal "Necesita seguimiento", result.label
    end
  end

  test "engagement is the mean of the AVAILABLE signals (login + message reads)" do
    institution = build_institution
    within_tenant(institution) do
      guardian = build_guardian
      Core::Session.create!(user: guardian, current_institution: institution, created_at: 2.days.ago) # 1.0
      # A conversation participant row with a stale last_read_at (~200 days -> 0.0).
      conversation = Communication::Conversation.create!(institution: institution, subject: "Seguimiento")
      Communication::ConversationParticipant.create!(institution: institution, conversation: conversation,
        guardian_user: guardian, last_read_at: 200.days.ago)

      result = AnalyticsBi::Lens::BondTension.for(guardian_user_id: guardian.id, institution: institution)
      assert_in_delta 0.5, result.engagement, 0.001 # mean(1.0, 0.0)
      assert_equal "Seguimiento moderado", result.label
    end
  end
end
