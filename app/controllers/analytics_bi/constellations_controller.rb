module AnalyticsBi
  # Lens 3 — "Constelación de Afinidades" (BI_DOCUMENT.md §4/§9, Slice 7). A
  # SUPERVISION surface (molde #4): authorize!("hps.constellation.view") at the
  # top, then a scoped Query object / read-model does the work. The scope
  # (institution-wide vs a department-scoped specialist) is resolved INSIDE
  # AnalyticsBi::Lens::ConstellationScope — the controller only proves the
  # capability, exactly as SpatialClassroomsController#index does for Lens 1.
  #
  # The taxonomy search (§1.1.6 "sin buscador de personas") is progressive: with
  # NO JS, `?q=` is a normal GET the server resolves via TaxonomySearchScope (over
  # affinity_taxonomy ONLY, never a student name) to narrow the fallback list;
  # with JS, a Stimulus controller filters the already-in-DOM nodes without a
  # round-trip (§10.4). Cytoscape.js is a progressive enhancement on top of the
  # always-server-rendered accessible fallback.
  class ConstellationsController < ApplicationController
    def index
      authorize!("hps.constellation.view")
      @constellation = AnalyticsBi::Lens::ConstellationBuilder.for(context: authorization_context)
      @query = params[:q].to_s.strip
      @matched_taxonomy_ids = matched_taxonomy_ids
    end

    private

    # Only for the NO-JS fallback: which visible talents match the server search.
    # nil means "no search active" (show all); [] means "searched, nothing matched".
    def matched_taxonomy_ids
      return nil if @query.blank?

      AnalyticsBi::Lens::TaxonomySearchScope.new(query: @query).matching_ids
    end
  end
end
