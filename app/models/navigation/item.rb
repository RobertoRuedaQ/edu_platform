module Navigation
  # One primary-nav destination — a domain index (the "clic 1" level of the
  # 3-click tree). Registered by domains in config/navigation/<domain>.rb and
  # rendered only when the actor holds `permission`. `icon` is optional and left
  # nil for now: the shared icon set has no per-domain glyphs and a wrong icon is
  # worse than none, so nav is text-only (same call the control plane made).
  Item = Data.define(:domain, :label, :path, :permission, :position, :icon)
end
