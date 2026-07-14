module CounselingHelper
  CASE_STATUS = {
    "open"        => { label: "Abierto", variant: :warning },
    "in_progress" => { label: "En seguimiento", variant: :info },
    "closed"      => { label: "Cerrado", variant: :neutral }
  }.freeze

  def counseling_case_status_badge(status)
    info = CASE_STATUS.fetch(status.to_s, { label: status.to_s.humanize, variant: :neutral })
    ui_badge(info[:label], variant: info[:variant])
  end
end
