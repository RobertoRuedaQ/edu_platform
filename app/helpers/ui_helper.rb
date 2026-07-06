module UiHelper
  # Thin ergonomics over shared/ partials. No business logic lives here —
  # these just save a few keystrokes and keep "one way to render X".

  def ui_button(label, **opts)
    render "shared/button", label: label, **opts
  end

  def ui_badge(label, variant: :neutral, **opts)
    render "shared/badge", label: label, variant: variant, **opts
  end

  def ui_icon(name, size: 20, **opts)
    render "shared/icon", name: name, size: size, **opts
  end

  def ui_avatar(name, **opts)
    render "shared/avatar", name: name, **opts
  end

  # Maps Rails flash keys (and semantic aliases) to a component modifier class.
  def flash_class_for(type)
    {
      "notice"  => "flash--success",
      "success" => "flash--success",
      "alert"   => "flash--danger",
      "error"   => "flash--danger",
      "danger"  => "flash--danger",
      "warning" => "flash--warning"
    }.fetch(type.to_s, "flash--info")
  end

  # Per-currency display config. es-style grouping (1.234,50).
  # TODO: currency will come from institution_settings; passed in for now.
  MONEY_FORMATS = {
    "COP" => { unit: "$",   precision: 0, format: "%u%n" },
    "USD" => { unit: "US$", precision: 2, format: "%u%n" },
    "MXN" => { unit: "$",   precision: 2, format: "%u%n" },
    "EUR" => { unit: "€",   precision: 2, format: "%n %u" }
  }.freeze

  # Format money for the es locale with a configurable currency. Never hardcode
  # the currency at call sites for real amounts — pass the institution's.
  def money(amount, currency: "COP")
    return "—" if amount.nil?

    cfg = MONEY_FORMATS.fetch(currency.to_s, { unit: "#{currency} ", precision: 2, format: "%u%n" })
    number_to_currency(amount,
      unit: cfg[:unit], precision: cfg[:precision],
      delimiter: ".", separator: ",", format: cfg[:format])
  end

  MONTHS_ES = %w[enero febrero marzo abril mayo junio julio agosto septiembre
                 octubre noviembre diciembre].freeze

  # Format a timestamp for the es locale in the institution's time zone.
  # format: :short (03/07/2026 14:30) | :date | :time | :long (3 de julio…).
  # TODO: time zone will come from institution_settings; passed in for now.
  def datetime(time, zone: "America/Bogota", format: :short)
    return "—" if time.nil?

    t = time.in_time_zone(zone)
    case format.to_sym
    when :time then t.strftime("%H:%M")
    when :date then t.strftime("%d/%m/%Y")
    when :long then "#{t.day} de #{MONTHS_ES[t.month - 1]} de #{t.year}, #{t.strftime('%H:%M')}"
    else            t.strftime("%d/%m/%Y %H:%M")
    end
  end
end
