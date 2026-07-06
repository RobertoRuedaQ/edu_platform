class DashboardController < ApplicationController
  # Landing (clic 0). Shortcut tiles ARE the permitted nav entries — same
  # Navigation::Registry as the nav — so each role lands on its own accesses,
  # keeping every working view ≤ 3 clics away. No authorize! here: this is the
  # landing every staff user reaches; each tile's destination gates itself.
  def show
    @tiles = Navigation::Registry.visible_to(authorization_context).map do |item|
      { label: item.label, path: item.path, stat: STUB_STATS[item.domain] }
    end
  end

  # STUB metrics for a few tiles so the landing feels alive. Real numbers come
  # from each domain's Query objects (scoped to the actor) later.
  # TODO: reemplazar por métricas reales por dominio.
  STUB_STATS = {
    "group_management" => { value: "128", label: "Estudiantes en tu alcance" },
    "schedules"        => { value: "6",   label: "Grupos con notas pendientes" },
    "counseling"       => { value: "3",   label: "Casos abiertos" }
  }.freeze
end
