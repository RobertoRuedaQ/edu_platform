module SchedulesHelper
  # score nil = "pendiente"; >=3.0 passes (mirrors Schedules::Assessment.passing).
  def grade_score_badge(score)
    return ui_badge("Pendiente", variant: :neutral) if score.nil?

    ui_badge(format("%.1f", score), variant: score >= 3.0 ? :success : :danger)
  end

  # Conflict is never color-only: the badge always carries the word too.
  def schedule_event_badge(event)
    return ui_badge("Conflicto", variant: :danger) if event.conflict

    ui_badge(event.room_name, variant: :neutral)
  end
end
