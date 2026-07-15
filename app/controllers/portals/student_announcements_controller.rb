module Portals
  # Membership read surface for the student portal — same rationale as
  # GuardianAnnouncementsController (org-wide, not per-self-scope). Reachable
  # even when StudentSelfScope resolves to nothing (an announcement has
  # nothing to do with being linked to a GroupManagement::Student row).
  class StudentAnnouncementsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @announcements = Communication::AnnouncementFeed.call(institution: Current.institution)
    end
  end
end
