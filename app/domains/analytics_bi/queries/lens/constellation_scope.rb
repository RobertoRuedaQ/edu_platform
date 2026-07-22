module AnalyticsBi
  module Lens
    # Access-boundary query object for Lens 3 (BI_DOCUMENT.md §4/§9, Slice 7).
    # Resolves WHICH affinity-taxonomy nodes the viewer may see: institution-wide
    # (orientación/directivas) OR only their department's talents (a specialist),
    # via the EXISTING :department scope reader — same molde as Slice 2's
    # SpatialClassroomScope reusing :group/:grade_level, no new scope_type.
    #
    # Uses IdentityAccess::PermissionCheck#scope_for to filter the taxonomy at the
    # DB level (the index-filter variant the engine explicitly supports, indexed
    # by idx_affinity_taxonomy_on_inst_department) rather than loading every node
    # and calling can? per row — both are equivalent (see PermissionCheck#scope_for).
    # Explicit institution_id filter, no default_scope; RLS is the backstop.
    #
    # A NULL-department node is an institution-level talent: covered only by an
    # institution-wide grant, never by a department-scoped one (the IN (...) filter
    # excludes NULLs), which is exactly the intended access model.
    class ConstellationScope
      def initialize(context:, institution: Current.institution)
        @context = context
        @institution = institution
      end

      # The AffinityTaxonomy relation the viewer is authorized to see. Returns an
      # empty relation when a department-scoped viewer holds no department grants
      # for this permission (fail-closed).
      def resolve
        return AnalyticsBi::AffinityTaxonomy.none if scope.nil?

        base = AnalyticsBi::AffinityTaxonomy
          .where(institution_id: institution.id)
          .active
        return base if scope.institution_wide?
        return AnalyticsBi::AffinityTaxonomy.none if scope.department_ids.empty?

        base.where(department_id: scope.department_ids)
      end

      private

      attr_reader :context, :institution

      def scope
        @scope ||= context.scope_for("hps.constellation.view")
      end
    end
  end
end
