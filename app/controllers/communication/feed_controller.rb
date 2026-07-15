module Communication
  # Membership read surface — a THIRD kind of gate, distinct from RBAC
  # (supervision, authorize! + Navigation::Registry) and from relation
  # (self-service/portal, GuardianScope/StudentSelfScope): "any active
  # member of this institution", nothing narrower. No authorize!, no
  # permission, not in Navigation::Registry — linked from the shell header
  # instead (shared/_announcements_link.html.erb), same as /mis_datos.
  # Living under Communication:: still means Entitlement::Controller gates
  # it by namespace inference (gate #1), same as any other domain
  # controller — membership-gated does NOT mean ungated.
  class FeedController < ApplicationController
    def show
      @announcements = Communication::AnnouncementFeed.call(institution: Current.institution)
    end
  end
end
