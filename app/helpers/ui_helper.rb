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
end
