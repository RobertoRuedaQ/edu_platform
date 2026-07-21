require "test_helper"

# Slice 5 (BI_DOCUMENT.md §5.4): the peer/guardian appreciation path and its
# hard anti-bullying + Habeas Data safeguards, proven at the MODEL level:
#  - closed tag catalog (no free text ever reaches a contribution)
#  - XOR giver identity (DB CHECK, num_nonnulls)
#  - anti-duplicate/anti-brigading partial unique index
#  - guardian consent gate rejecting an unconsented participant CLEANLY
#  - aggregation threshold before surfacing + never-attributable projection
#  - append-only moderation (status flip, never destroy, always audited)
# Exercised directly under the tenant GUC (RLS FORCE).
class AnalyticsBi::PeerAppreciationTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  setup do
    @institution = Core::Institution.create!(name: "Colegio pa", slug: "pa-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(@institution) do
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @ana = build_student("PA-ANA")   # receiver
      @leo = build_student("PA-LEO")   # peer giver
      @tag = AnalyticsBi::PeerAppreciationTag.create!(institution: @institution,
        label: "Buen compañero", category: "convivencia", active: true)
      @guardian = Core::User.create!(email: "g-#{SecureRandom.hex(4)}@test", name: "Acudiente", password: "password-123456")
      @moderator = @institution.memberships.create!(
        user: Core::User.create!(email: "m-#{SecureRandom.hex(4)}@test", name: "Mod", password: "password-123456"))
    end
  end

  def build_student(code)
    GroupManagement::Student.create!(institution: @institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023,
      status: "active", section: @section)
  end

  def grant_consent(student)
    AnalyticsBi::CharacterProgramConsent.grant!(student: student, guardian_user: @guardian, institution: @institution)
  end

  def record_from_peer(giver: @leo, student: @ana, tag: @tag)
    AnalyticsBi::Character::PeerAppreciationRecorder.call(student: student, tag: tag,
      academic_term: @term, giver_student: giver, institution: @institution)
  end

  # --- no free text / closed catalog ---------------------------------------

  test "an inactive tag cannot be used for a contribution" do
    within_tenant(@institution) do
      grant_consent(@ana)
      grant_consent(@leo)
      @tag.update!(active: false)

      assert_raises(AnalyticsBi::Character::PeerAppreciationRecorder::TagUnavailable) do
        record_from_peer
      end
    end
  end

  # --- XOR giver identity ---------------------------------------------------

  test "the DB forbids a contribution with BOTH giver identities (XOR CHECK)" do
    within_tenant(@institution) do
      row = AnalyticsBi::PeerAppreciation.new(institution: @institution, student: @ana, tag: @tag,
        academic_term: @term, giver_kind: "peer_student", giver_student: @leo, giver_guardian: @guardian,
        status: "active")
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { row.save!(validate: false) }
      end
    end
  end

  test "the DB forbids a contribution with NEITHER giver identity (XOR CHECK)" do
    within_tenant(@institution) do
      row = AnalyticsBi::PeerAppreciation.new(institution: @institution, student: @ana, tag: @tag,
        academic_term: @term, giver_kind: "guardian", status: "active")
      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { row.save!(validate: false) }
      end
    end
  end

  # --- consent gate ---------------------------------------------------------

  test "the recorder rejects an unconsented RECEIVER cleanly (ConsentRequired, never a 500)" do
    within_tenant(@institution) do
      grant_consent(@leo) # giver consents, receiver does NOT
      assert_raises(AnalyticsBi::Character::PeerAppreciationRecorder::ConsentRequired) { record_from_peer }
      assert_equal 0, AnalyticsBi::PeerAppreciation.count
    end
  end

  test "the recorder rejects an unconsented peer GIVER cleanly" do
    within_tenant(@institution) do
      grant_consent(@ana) # receiver consents, peer giver does NOT
      assert_raises(AnalyticsBi::Character::PeerAppreciationRecorder::ConsentRequired) { record_from_peer }
      assert_equal 0, AnalyticsBi::PeerAppreciation.count
    end
  end

  test "a consented peer contribution is recorded" do
    within_tenant(@institution) do
      grant_consent(@ana)
      grant_consent(@leo)
      result = record_from_peer
      assert result.created
      assert result.appreciation.active?
      assert_equal "peer_student", result.appreciation.giver_kind
    end
  end

  test "revoking consent stops further participation" do
    within_tenant(@institution) do
      grant_consent(@ana)
      grant_consent(@leo)
      AnalyticsBi::CharacterProgramConsent.revoke!(student: @ana, institution: @institution)

      assert_raises(AnalyticsBi::Character::PeerAppreciationRecorder::ConsentRequired) { record_from_peer }
    end
  end

  # --- anti-duplicate / anti-brigading -------------------------------------

  test "re-giving the same tag to the same recipient is an idempotent no-op" do
    within_tenant(@institution) do
      grant_consent(@ana)
      grant_consent(@leo)
      first = record_from_peer
      second = record_from_peer

      assert first.created
      refute second.created, "the resubmit is a no-op, not a new row"
      assert_equal first.appreciation.id, second.appreciation.id
      assert_equal 1, AnalyticsBi::PeerAppreciation.where(student_id: @ana.id, tag_id: @tag.id).count
    end
  end

  test "the partial unique index is the DB backstop against a duplicate active contribution" do
    within_tenant(@institution) do
      grant_consent(@ana)
      grant_consent(@leo)
      record_from_peer

      dup = AnalyticsBi::PeerAppreciation.new(institution: @institution, student: @ana, tag: @tag,
        academic_term: @term, giver_kind: "peer_student", giver_student: @leo, status: "active")
      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { dup.save!(validate: false) }
      end
    end
  end

  # --- aggregation threshold + never-attributable projection ---------------

  test "the digest surfaces a tag only at/above the threshold, and NEVER exposes giver identity" do
    within_tenant(@institution) do
      threshold = AnalyticsBi::Character::PeerAppreciationRecorder::AGGREGATION_THRESHOLD
      # threshold distinct peer givers on @tag -> surfaced
      threshold.times do |i|
        giver = build_student("PA-G#{i}")
        AnalyticsBi::PeerAppreciation.create!(institution: @institution, student: @ana, tag: @tag,
          academic_term: @term, giver_kind: "peer_student", giver_student: giver, status: "active")
      end
      # a second tag with only ONE contribution -> below threshold, hidden
      sparse = AnalyticsBi::PeerAppreciationTag.create!(institution: @institution,
        label: "Creativo/a", category: "creatividad", active: true)
      AnalyticsBi::PeerAppreciation.create!(institution: @institution, student: @ana, tag: sparse,
        academic_term: @term, giver_kind: "peer_student", giver_student: @leo, status: "active")

      recognitions = AnalyticsBi::Character::PeerAppreciationDigest.for(student: @ana, institution: @institution)

      assert_equal 1, recognitions.size, "only the tag at/above threshold surfaces"
      recognition = recognitions.first
      assert_equal "Buen compañero", recognition.tag_label
      assert_equal threshold, recognition.count
      assert_equal %i[tag_label category count].sort, recognition.to_h.keys.sort,
        "the projection is aggregate-only — never a giver id"
    end
  end

  test "withheld contributions never count toward the aggregation threshold" do
    within_tenant(@institution) do
      threshold = AnalyticsBi::Character::PeerAppreciationRecorder::AGGREGATION_THRESHOLD
      appreciations = threshold.times.map do |i|
        giver = build_student("PA-W#{i}")
        AnalyticsBi::PeerAppreciation.create!(institution: @institution, student: @ana, tag: @tag,
          academic_term: @term, giver_kind: "peer_student", giver_student: giver, status: "active")
      end
      AnalyticsBi::Character::Moderation.withhold!(appreciation: appreciations.first, actor: @moderator,
        institution: @institution)

      recognitions = AnalyticsBi::Character::PeerAppreciationDigest.for(student: @ana, institution: @institution)
      assert_empty recognitions, "one withheld row drops the count below threshold"
    end
  end

  # --- append-only moderation ----------------------------------------------

  test "moderation is an append-only status flip (never destroy) and is audited" do
    within_tenant(@institution) do
      grant_consent(@ana)
      grant_consent(@leo)
      appreciation = record_from_peer.appreciation

      assert_difference -> { AnalyticsBi::PeerAppreciation.count }, 0, "the row is never destroyed" do
        assert_difference -> { IdentityAccess::AuditEvent.where(action: "peer_appreciation.withheld").count }, 1 do
          AnalyticsBi::Character::Moderation.withhold!(appreciation: appreciation, actor: @moderator,
            institution: @institution)
        end
      end

      assert appreciation.reload.withheld?
    end
  end

  test "withholding is idempotent (no second audit event for an already-withheld row)" do
    within_tenant(@institution) do
      grant_consent(@ana)
      grant_consent(@leo)
      appreciation = record_from_peer.appreciation
      AnalyticsBi::Character::Moderation.withhold!(appreciation: appreciation, actor: @moderator, institution: @institution)

      assert_difference -> { IdentityAccess::AuditEvent.where(action: "peer_appreciation.withheld").count }, 0 do
        AnalyticsBi::Character::Moderation.withhold!(appreciation: appreciation, actor: @moderator, institution: @institution)
      end
    end
  end
end
