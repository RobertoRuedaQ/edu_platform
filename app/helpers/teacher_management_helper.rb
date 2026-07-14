module TeacherManagementHelper
  STATUS = {
    "active"     => { label: "Activo", variant: :success },
    "on_leave"   => { label: "En licencia", variant: :warning },
    "terminated" => { label: "Desvinculado", variant: :neutral }
  }.freeze

  def teacher_status_badge(status)
    # nil when the teacher has no staff_member link yet (D1's additive
    # transition, v1.12.0) — a normal state, not an error.
    return ui_badge("Sin vincular a personal", variant: :neutral) if status.nil?

    info = STATUS.fetch(status.to_s, { label: status.to_s.humanize, variant: :neutral })
    ui_badge(info[:label], variant: info[:variant])
  end
end
