module AttendanceHelper
  STATUS = {
    "present" => { label: "Presente", variant: :success },
    "absent"  => { label: "Ausente", variant: :danger },
    "late"    => { label: "Tarde", variant: :warning },
    "excused" => { label: "Justificada", variant: :info }
  }.freeze

  def attendance_status_badge(status)
    info = STATUS.fetch(status.to_s, { label: status.to_s.humanize, variant: :neutral })
    ui_badge(info[:label], variant: info[:variant])
  end
end
