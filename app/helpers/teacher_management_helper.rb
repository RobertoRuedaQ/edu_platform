module TeacherManagementHelper
  STATUS = {
    "active"     => { label: "Activo", variant: :success },
    "on_leave"   => { label: "En licencia", variant: :warning },
    "terminated" => { label: "Desvinculado", variant: :neutral }
  }.freeze

  def teacher_status_badge(status)
    info = STATUS.fetch(status.to_s, { label: status.to_s.humanize, variant: :neutral })
    ui_badge(info[:label], variant: info[:variant])
  end
end
