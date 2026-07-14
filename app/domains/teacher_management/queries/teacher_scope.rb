module TeacherManagement
  # CANONICAL REFERENCE for the #4 "business view" pattern (esqueleto #1 of
  # PROJECT_STATE.md §6.6) — the other six domains copy this shape, not
  # reinvent it. No default_scope: RLS + an explicit institution_id filter
  # are the PRIMARY guarantee, and per-row `context.can?` (the SAME seam
  # authorize!/can? use) is what actually decides which rows an index shows
  # — so index filtering and single-resource gating (TeachersController#show)
  # can never disagree. Loads real Teacher rows now (#4 slice 1) instead of
  # the retired in-memory TeacherRoster stub.
  #
  # Per-row `can?` over `.select`, NOT `PermissionCheck#scope_for` — §6.3
  # explicitly says both are equivalent and per-row is "just as valid"; no
  # domain has adopted scope_for yet, and this slice's job is to prove ONE
  # pattern cleanly, not to introduce a second one.
  class TeacherScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      TeacherManagement::Teacher
        .where(institution_id: institution.id)
        .includes(:staff_member)
        .order(:last_name, :first_name)
        .select { |teacher| context.can?("teachers.view", teacher) }
    end

    private

    attr_reader :context, :institution
  end
end
