require "test_helper"

# Slice 6 (BI_DOCUMENT.md §5.4 "Cómo alimenta las lentes"): the Lens 2 read-model
# assembling the radar, brújula, medallas and intra-student growth from the
# already-built Slice 5 machinery. Proven under the tenant GUC (RLS FORCE).
#
# The non-negotiables under test:
#  - ordinal is a private geometry input; the Card exposes only qualitative text
#  - a true empty state (no published evaluation) is nil/absent, never a fake shape
#  - growth is ordered by the term's OWN calendar start (§1.1.3), not published_at
class AnalyticsBi::CharacterCardTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  setup do
    @institution = Core::Institution.create!(name: "Colegio cc", slug: "cc-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(@institution) do
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @student = build_student("CC-ANA")
      @author = @institution.memberships.create!(
        user: Core::User.create!(email: "a-#{SecureRandom.hex(4)}@test", name: "Docente", password: "password-123456"))
      build_framework
    end
  end

  def build_student(code)
    GroupManagement::Student.create!(institution: @institution, first_name: "Est", last_name: code,
      gender: "female", birthdate: Date.new(2013, 3, 1), student_code: code, entry_year: 2023,
      status: "active", section: @section)
  end

  def build_framework
    @framework = AnalyticsBi::CharacterFramework.create!(institution: @institution, name: "Marco base", status: "published")
    @empatia = AnalyticsBi::CharacterDimension.create!(institution: @institution, framework: @framework,
      name: "Empatía", position: 0, weight: 1)
    %w[En\ desarrollo Consolidado Destacado].each_with_index do |label, i|
      AnalyticsBi::CharacterLevel.create!(institution: @institution, dimension: @empatia,
        label: label, descriptor: "#{label} en empatía.", position: i)
    end
    @perseverancia = AnalyticsBi::CharacterDimension.create!(institution: @institution, framework: @framework,
      name: "Perseverancia", position: 1, weight: 1)
    %w[En\ desarrollo Consolidado].each_with_index do |label, i|
      AnalyticsBi::CharacterLevel.create!(institution: @institution, dimension: @perseverancia,
        label: label, descriptor: "#{label} en perseverancia.", position: i)
    end
  end

  # status defaults to "closed": only ONE active term per institution is allowed
  # (index_academic_terms_one_active_per_institution), and the card's growth read
  # is by term.starts_on regardless of term status.
  def term(code, starts_on, status: "closed")
    Core::AcademicTerm.create!(institution: @institution, code: code, name: code,
      starts_on: starts_on, ends_on: starts_on + 5.months, status: status)
  end

  def publish(term:, empatia:, perseverancia:, published_at: Time.current)
    result = AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student,
      academic_term: term, author: @author, institution: @institution, selections: [
        { dimension_key: @empatia.id, level_label: empatia },
        { dimension_key: @perseverancia.id, level_label: perseverancia }
      ])
    result.evaluation.update!(published_at: published_at)
    result.evaluation
  end

  test "the radar reflects the most recently published evaluation, in qualitative terms only" do
    within_tenant(@institution) do
      t1 = term("2025-1", Date.new(2025, 1, 1))
      t2 = term("2026-1", Date.new(2026, 1, 1))
      publish(term: t1, empatia: "Consolidado", perseverancia: "En desarrollo", published_at: 2.days.ago)
      publish(term: t2, empatia: "Destacado", perseverancia: "Consolidado", published_at: 1.hour.ago)

      card = AnalyticsBi::Lens::CharacterCard.call(student: @student, institution: @institution)
      assert card.evaluated?
      empatia = card.axes.find { |a| a.dimension_name == "Empatía" }
      assert_equal "Destacado", empatia.level_label, "the LATEST published evaluation drives the radar"
      assert_equal "Destacado en empatía.", empatia.descriptor
      assert_equal 2, empatia.ordinal, "ordinal is captured as a geometry input"
      assert_equal 3, empatia.levels_count
    end
  end

  test "the brújula surfaces the highest-level dimensions by name, never a number" do
    within_tenant(@institution) do
      publish(term: term("2026-1", Date.new(2026, 1, 1)), empatia: "Destacado", perseverancia: "Consolidado")

      card = AnalyticsBi::Lens::CharacterCard.call(student: @student, institution: @institution)
      assert_equal [ "Empatía" ], card.top_strengths
    end
  end

  test "growth is ordered by the term's own calendar start, not by published_at" do
    within_tenant(@institution) do
      later_term = term("2026-1", Date.new(2026, 1, 1))
      earlier_term = term("2025-1", Date.new(2025, 1, 1))
      # Publish the chronologically-EARLIER term LAST (later published_at) to
      # prove ordering follows starts_on, not publish order (§1.1.3 mold).
      publish(term: later_term, empatia: "Consolidado", perseverancia: "Consolidado", published_at: 2.days.ago)
      publish(term: earlier_term, empatia: "En desarrollo", perseverancia: "En desarrollo", published_at: 1.hour.ago)

      card = AnalyticsBi::Lens::CharacterCard.call(student: @student, institution: @institution)
      assert_equal %w[2025-1 2026-1], card.growth.map(&:term_name)
      assert_equal "En desarrollo", card.growth.first.axes.find { |a| a.dimension_name == "Empatía" }.level_label
    end
  end

  test "a student with no published evaluation gets a true empty state, not a zeroed radar" do
    within_tenant(@institution) do
      card = AnalyticsBi::Lens::CharacterCard.call(student: @student, institution: @institution)
      refute card.evaluated?
      assert_empty card.axes
      assert_empty card.top_strengths
      assert_empty card.growth
    end
  end

  test "a draft (unpublished) evaluation never reaches the card" do
    within_tenant(@institution) do
      t = term("2026-1", Date.new(2026, 1, 1))
      publish(term: t, empatia: "Destacado", perseverancia: "Consolidado").update!(status: "draft")

      card = AnalyticsBi::Lens::CharacterCard.call(student: @student, institution: @institution)
      refute card.evaluated?
    end
  end

  test "medallas surface only once a tag crosses the aggregation threshold, aggregate-only" do
    within_tenant(@institution) do
      t = term("2026-1", Date.new(2026, 1, 1))
      tag = AnalyticsBi::PeerAppreciationTag.create!(institution: @institution,
        label: "Buen compañero", category: "convivencia", active: true)

      give_appreciations(tag: tag, term: t, count: 2)
      below = AnalyticsBi::Lens::CharacterCard.call(student: @student, institution: @institution)
      assert_empty below.recognitions, "below the threshold, nothing surfaces"

      give_appreciations(tag: tag, term: t, count: 1)
      at = AnalyticsBi::Lens::CharacterCard.call(student: @student, institution: @institution)
      assert_equal [ "Buen compañero" ], at.recognitions.map(&:tag_label)
    end
  end

  def give_appreciations(tag:, term:, count:)
    count.times do
      giver = build_student("GV-#{SecureRandom.hex(3)}")
      AnalyticsBi::PeerAppreciation.create!(institution: @institution, student: @student, tag: tag,
        academic_term: term, giver_kind: "peer_student", giver_student: giver, status: "active")
    end
  end
end
