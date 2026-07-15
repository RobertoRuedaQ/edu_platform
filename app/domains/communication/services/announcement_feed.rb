module Communication
  # THE single read path for "what announcements does this institution have
  # right now" — consumed by staff read, the guardian portal, AND the
  # student portal (same pattern as ReportCards::Computation/Finance::
  # AccountStatement: one computation, many surfaces, so they can never
  # disagree). Membership-gated by the CALLER (no authorize! here, no
  # relation scope either — an announcement is org-wide, not per-person),
  # this object only ever answers "published, for this institution, newest
  # first". Retracted announcements never appear.
  module AnnouncementFeed
    module_function

    def call(institution:)
      Communication::Announcement
        .where(institution_id: institution.id, status: "published")
        .order(published_at: :desc)
    end
  end
end
