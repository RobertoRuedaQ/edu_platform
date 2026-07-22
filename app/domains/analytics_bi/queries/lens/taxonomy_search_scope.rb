module AnalyticsBi
  module Lens
    # The taxonomy search primitive for Lens 3 (BI_DOCUMENT.md §1.1.6/§5.5, Slice 7).
    # The specialist searches a TALENT ("fútbol", "piano"), NEVER a student name —
    # this query object is the proof of that invariant: it only ever touches
    # affinity_taxonomy, over the PG18-generated `search_tsv` (Spanish FTS + GIN
    # index) via websearch_to_tsquery. There is no join to students, no name
    # column of a minor anywhere in its SQL.
    #
    # Explicit institution_id filter, no default_scope (RLS is the backstop, the
    # app filter is the primary scoping — house discipline, §9). It powers the
    # NO-JS fallback search on the constellation page (a normal GET ?q=); with JS,
    # the Stimulus controller filters the already-in-DOM nodes without a round-trip
    # (§10.4), so this is not a per-keystroke server call.
    class TaxonomySearchScope
      def initialize(query:, institution: Current.institution, only_active: true)
        @query = query.to_s.strip
        @institution = institution
        @only_active = only_active
      end

      # Returns the matching AffinityTaxonomy relation, or the empty set for a
      # blank query (a blank search matches nothing, never "everything").
      def resolve
        return AnalyticsBi::AffinityTaxonomy.none if query.blank?

        base.where("search_tsv @@ websearch_to_tsquery('spanish', ?)", query)
      end

      # Convenience for callers that only need the ids (e.g. the client-side
      # highlight set) without loading rows.
      def matching_ids
        resolve.pluck(:id)
      end

      private

      attr_reader :query, :institution, :only_active

      def base
        rel = AnalyticsBi::AffinityTaxonomy.where(institution_id: institution.id)
        only_active ? rel.active : rel
      end
    end
  end
end
