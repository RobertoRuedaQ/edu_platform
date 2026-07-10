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

  # Decrypts just long enough to show a trailing fragment for sanity-checking
  # a row against the source file — the preview never shows a full document
  # number (privacy, same spirit as never autocompleting by national_id/
  # name). AT MOST half the characters are ever revealed (never all 4, e.g.
  # for an unrealistically short id) — length/2 capped at 4, so a full-length
  # cédula shows its last 4 digits but nothing shows in the clear.
  def mask_national_id(ciphertext)
    plain = Core::RosterImport::Cipher.decrypt(ciphertext)
    return "—" if plain.blank?

    visible = [ plain.length / 2, 4 ].min
    ("•" * (plain.length - visible)) + plain.last(visible)
  end
end
