module IdentityAccessHelper
  BATCH_STATUS = {
    "uploaded"  => { label: "Cargado", variant: :neutral },
    "validated" => { label: "Validado", variant: :info },
    "committed" => { label: "Aplicado", variant: :success },
    "failed"    => { label: "Falló", variant: :danger }
  }.freeze

  ROW_STATUS = {
    "valid"     => { label: "Crear", variant: :success },
    "duplicate" => { label: "Actualizar", variant: :info },
    "collision" => { label: "Duplicado en archivo", variant: :warning },
    "error"     => { label: "Error", variant: :danger }
  }.freeze

  def roster_import_batch_status_badge(status)
    info = BATCH_STATUS.fetch(status.to_s, { label: status.to_s.humanize, variant: :neutral })
    ui_badge(info[:label], variant: info[:variant])
  end

  def roster_import_row_status_badge(status)
    info = ROW_STATUS.fetch(status.to_s, { label: "Pendiente", variant: :neutral })
    ui_badge(info[:label], variant: info[:variant])
  end
end
