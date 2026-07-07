module GroupManagementHelper
  STUDENT_STATUS = {
    "active"   => { label: "Activo", variant: :success },
    "inactive" => { label: "Inactivo", variant: :neutral },
    "on_leave" => { label: "En licencia", variant: :warning }
  }.freeze

  def student_status_badge(status)
    info = STUDENT_STATUS.fetch(status.to_s, { label: status.to_s.humanize, variant: :neutral })
    ui_badge(info[:label], variant: info[:variant])
  end
end
