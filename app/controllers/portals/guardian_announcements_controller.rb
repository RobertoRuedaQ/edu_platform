module Portals
  # Membership read surface for the guardian portal — NOT per-child (an
  # announcement is org-wide, unlike report_cards/finance), so no
  # GuardianScope needed here; the feed scopes by Current.institution alone.
  # Same shared read path (Communication::AnnouncementFeed) the staff feed
  # and the student portal use. No authorize!, outside Navigation::Registry.
  class GuardianAnnouncementsController < ApplicationController
    layout "portal"

    def index
      @portal_label = "Portal del acudiente"
      @portal_person_name = Current.user.name
      @announcements = Communication::AnnouncementFeed.call(institution: Current.institution)
    end
  end
end
