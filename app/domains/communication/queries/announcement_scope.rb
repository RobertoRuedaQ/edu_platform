module Communication
  # #4 canonical mold (§6.6, teacher_management) copied here: real relation +
  # institution_id explicit + per-row can? via .select, never default_scope.
  # Institution-wide by design (same as Finance::AccountScope) — announcing
  # is a central function, not scoped to a group/department.
  class AnnouncementScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Communication::Announcement
        .where(institution_id: institution.id)
        .order(created_at: :desc)
        .select { |announcement| context.can?("announcement.publish", announcement) }
    end

    private

    attr_reader :context, :institution
  end
end
