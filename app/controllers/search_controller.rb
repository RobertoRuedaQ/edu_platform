class SearchController < ApplicationController
  # Global search escape hatch. STUB: renders an empty state regardless of query.
  # TODO: implementar búsqueda real acotada por permisos + scope del actor.
  def index
    @query = params[:q].to_s.strip
  end
end
