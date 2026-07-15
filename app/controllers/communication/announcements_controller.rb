module Communication
  # Publish/manage surface — molde #4 (§6.6). Institution-wide scope (same
  # as Finance::AccountsController): announcing is a central function, not
  # scoped to a group/department. `authorize!("announcement.publish")` gates
  # every action; anyone holding it may edit/retract ANY announcement in
  # their institution (default: small comms team, not author-only — the
  # author is stored for attribution, not as an ownership boundary).
  # Retract is soft (Announcement#retract!) — never a #destroy action.
  class AnnouncementsController < ApplicationController
    def index
      authorize!("announcement.publish")
      @announcements = Communication::AnnouncementScope.new(context: authorization_context).resolve
    end

    def new
      authorize!("announcement.publish")
      @announcement = Communication::Announcement.new
    end

    def create
      authorize!("announcement.publish")
      @announcement = Communication::Announcement.new(announcement_params)
      @announcement.institution = Current.institution
      @announcement.author_institution_user_id = Current.institution_user_id
      @announcement.status = "published"
      @announcement.published_at = Time.current

      if @announcement.save
        redirect_to communication_announcements_path, notice: "Anuncio publicado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @announcement = find_announcement
      authorize!("announcement.publish", @announcement)
    end

    def update
      @announcement = find_announcement
      authorize!("announcement.publish", @announcement)

      if @announcement.update(announcement_params)
        redirect_to communication_announcements_path, notice: "Anuncio actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def retract
      @announcement = find_announcement
      authorize!("announcement.publish", @announcement)
      @announcement.retract!
      redirect_to communication_announcements_path, notice: "Anuncio retractado."
    end

    private

    def find_announcement
      announcement = Communication::Announcement.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if announcement.nil?

      announcement
    end

    def announcement_params
      params.require(:announcement).permit(:title, :body)
    end
  end
end
