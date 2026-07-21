require "test_helper"

# Slice 5 (BI_DOCUMENT.md §5.4, §4): the docente/orientador authoring surface
# for character evaluations. SUPERVISION (molde #4) — every action is gated by
# hps.character.author; the default persona (which lacks it) is denied. Publishing
# goes through AnalyticsBi::Character::Publisher (freezing the snapshot).
class AnalyticsBiCharacterEvaluationTest < ActionDispatch::IntegrationTest
  setup do
    @user, @institution = sign_in_as_member # default grant does NOT include hps.character.author
    within_tenant(@institution) do
      @term = Core::AcademicTerm.create!(institution: @institution, code: "2026-1", name: "2026-1",
        starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 6, 30), status: "active")
      @section = GroupManagement::Section.create!(institution: @institution, name: "9°A", academic_year: 2026)
      @student = GroupManagement::Student.create!(institution: @institution, first_name: "Ana", last_name: "P",
        gender: "female", birthdate: Date.new(2013, 3, 1), student_code: "CE-ANA", entry_year: 2023,
        status: "active", section: @section)
      @framework = AnalyticsBi::CharacterFramework.create!(institution: @institution, name: "Marco base", status: "published")
      @empatia = AnalyticsBi::CharacterDimension.create!(institution: @institution, framework: @framework,
        name: "Empatía", position: 0, weight: 1)
      AnalyticsBi::CharacterLevel.create!(institution: @institution, dimension: @empatia,
        label: "Consolidado", descriptor: "Acompaña a sus compañeros.", position: 0)
    end
  end

  def within_tenant(institution)
    ActiveRecord::Base.transaction do
      Tenant::Guc.set_local(institution.id)
      yield
    end
  end

  def as_author(&block)
    with_grants(
      Authorization::Assignment.new(role_key: "hps_author",
        permission_keys: %w[hps.character.author], scope_type: :institution, scope_id: nil),
      &block
    )
  end

  def create_params
    { student_id: @student.id, framework_id: @framework.id, author_kind: "teacher",
      dimensions: { @empatia.id => { level_label: "Consolidado", note: "Muy solidaria." } } }
  end

  test "the default persona (no hps.character.author) is denied the authoring surface (403)" do
    get new_analytics_bi_character_evaluation_path(student_id: @student.id, framework_id: @framework.id)
    assert_response :forbidden

    post analytics_bi_character_evaluations_path, params: create_params
    assert_response :forbidden
    assert_equal 0, AnalyticsBi::CharacterEvaluation.count
  end

  test "an hps.character.author publishes an evaluation through the Publisher" do
    as_author do
      assert_difference -> { AnalyticsBi::CharacterEvaluation.count }, 1 do
        post analytics_bi_character_evaluations_path, params: create_params
      end
      assert_response :redirect

      evaluation = within_tenant(@institution) { AnalyticsBi::CharacterEvaluation.last }
      assert evaluation.published?
      assert_equal @student.id, evaluation.student_id
      assert_equal "Empatía", evaluation.framework_snapshot["dimensions"].first["name"]

      score = within_tenant(@institution) { evaluation.character_dimension_scores.sole }
      assert_equal @empatia.id, score.dimension_key
      assert_equal "Consolidado", score.level_label
    end
  end

  test "the authoring form renders for an hps.character.author" do
    as_author do
      get new_analytics_bi_character_evaluation_path(student_id: @student.id, framework_id: @framework.id)
      assert_response :success
      assert_match "Empatía", response.body
    end
  end
end
