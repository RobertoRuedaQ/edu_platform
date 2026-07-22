require "test_helper"

# Slice 5 (BI_DOCUMENT.md §5.4): the STAFF character-evaluation instrument
# (rubric mold, but for behavior). framework_snapshot freezing at publish, the
# unique-author DB index, dimension_key referencing the FROZEN snapshot, and the
# InvalidSelection guard. Exercised directly under the tenant GUC (RLS FORCE).
class AnalyticsBi::CharacterEvaluationTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  setup do
    @institution = Core::Institution.create!(name: "Colegio ce", slug: "ce-#{SecureRandom.hex(4)}",
      code: "C-#{SecureRandom.hex(3)}", kind: "school")
    within_tenant(@institution) do
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "P",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "CE-ANA", entry_year: 2023,
        status: "active", section: @section)
      user = Core::User.create!(email: "author-#{SecureRandom.hex(4)}@test", name: "Docente", password: "password-123456")
      @author = @institution.memberships.create!(user: user)
      @framework = build_framework
    end
  end

  def build_framework
    framework = AnalyticsBi::CharacterFramework.create!(institution: @institution, name: "Marco base", status: "published")
    @empatia = AnalyticsBi::CharacterDimension.create!(institution: @institution, framework: framework,
      name: "Empatía", position: 0, weight: 1)
    AnalyticsBi::CharacterLevel.create!(institution: @institution, dimension: @empatia,
      label: "En desarrollo", descriptor: "Empieza a reconocer emociones.", position: 0)
    AnalyticsBi::CharacterLevel.create!(institution: @institution, dimension: @empatia,
      label: "Consolidado", descriptor: "Acompaña a sus compañeros.", position: 1)
    framework
  end

  def selections
    [ { dimension_key: @empatia.id, level_label: "Consolidado", note: "Muy solidaria." } ]
  end

  test "publishing freezes the framework structure into framework_snapshot" do
    within_tenant(@institution) do
      evaluation = AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student,
        academic_term: @term, author: @author, selections: selections, institution: @institution).evaluation

      assert evaluation.published?
      assert_equal @student.id, evaluation.student_id
      snapshot = evaluation.framework_snapshot
      assert_equal "Marco base", snapshot["framework_name"]
      dimension = snapshot["dimensions"].first
      assert_equal "Empatía", dimension["name"]
      assert_equal @empatia.id, dimension["key"]
      assert_equal %w[En\ desarrollo Consolidado], dimension["levels"].map { |l| l["label"] }
    end
  end

  test "editing the framework after publish never rewrites the frozen snapshot" do
    within_tenant(@institution) do
      evaluation = AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student,
        academic_term: @term, author: @author, selections: selections, institution: @institution).evaluation

      @empatia.update!(name: "Empatía (renombrada)")
      evaluation.reload
      assert_equal "Empatía", evaluation.framework_snapshot["dimensions"].first["name"],
        "the frozen snapshot is immutable; a live edit never leaks in"
    end
  end

  test "dimension scores reference the frozen snapshot by dimension_key, not a live FK" do
    within_tenant(@institution) do
      evaluation = AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student,
        academic_term: @term, author: @author, selections: selections, institution: @institution).evaluation

      score = evaluation.character_dimension_scores.sole
      assert_equal @empatia.id, score.dimension_key
      assert_equal "Consolidado", score.level_label
      assert_equal "Muy solidaria.", score.note
    end
  end

  test "an unknown dimension or level is rejected as an invalid selection" do
    within_tenant(@institution) do
      assert_raises(AnalyticsBi::Character::Publisher::InvalidSelection) do
        AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student, academic_term: @term,
          author: @author, selections: [ { dimension_key: @empatia.id, level_label: "Inventado" } ],
          institution: @institution)
      end
      assert_equal 0, AnalyticsBi::CharacterEvaluation.count, "the failed publish rolled back cleanly"
    end
  end

  test "the same author cannot evaluate the same student/term/framework twice (AR validation)" do
    within_tenant(@institution) do
      AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student, academic_term: @term,
        author: @author, selections: selections, institution: @institution)

      assert_raises(ActiveRecord::RecordInvalid) do
        AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student, academic_term: @term,
          author: @author, selections: selections, institution: @institution)
      end
    end
  end

  test "the DB unique index is the backstop even if validation is bypassed" do
    within_tenant(@institution) do
      AnalyticsBi::Character::Publisher.call(framework: @framework, student: @student, academic_term: @term,
        author: @author, selections: selections, institution: @institution)

      dup = AnalyticsBi::CharacterEvaluation.new(institution: @institution, student: @student,
        academic_term: @term, framework: @framework, author: @author, author_kind: "teacher",
        status: "published", framework_snapshot: {})
      assert_raises(ActiveRecord::RecordNotUnique) do
        ActiveRecord::Base.transaction(requires_new: true) { dup.save!(validate: false) }
      end
    end
  end
end
