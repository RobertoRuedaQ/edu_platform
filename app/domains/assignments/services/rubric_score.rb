module Assignments
  # Pure calculation, no DB writes — given a FROZEN rubric_snapshot (never
  # the live template; see Assignments::Publisher) and which level got
  # picked per criterion, computes:
  #
  #   score = (Σ puntos_nivel_elegido × peso) / (Σ puntos_máx × peso) × 5.0
  #
  # rounded to 1 decimal. Weights are relative (this is a RATIO), so
  # criteria never need to sum to 100. Any criterion missing a pick makes
  # the whole evaluation :incomplete — never a phantom zero for an
  # ungraded criterion.
  module RubricScore
    module_function

    Result = Data.define(:score, :error)

    def call(snapshot:, levels_by_criterion:)
      criteria = snapshot && snapshot["criteria"]
      levels = snapshot && snapshot["levels"]
      return Result.new(score: nil, error: :no_snapshot) if criteria.blank? || levels.blank?

      picks = levels_by_criterion.transform_keys(&:to_s).transform_values(&:to_s)
      max_points = levels.map { |l| BigDecimal(l["points"].to_s) }.max
      numerator = BigDecimal("0")
      denominator = BigDecimal("0")

      criteria.each do |criterion|
        picked_level_id = picks[criterion["id"].to_s]
        return Result.new(score: nil, error: :incomplete) if picked_level_id.blank?

        level = levels.find { |l| l["id"].to_s == picked_level_id }
        return Result.new(score: nil, error: :incomplete) if level.nil?

        weight = BigDecimal(criterion["weight"].to_s)
        numerator += BigDecimal(level["points"].to_s) * weight
        denominator += max_points * weight
      end

      return Result.new(score: nil, error: :incomplete) if denominator.zero?

      Result.new(score: (numerator / denominator * 5).round(1), error: nil)
    end
  end
end
