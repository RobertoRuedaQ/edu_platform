module IdentityAccess
  # Onboarding admin surface: crear personas, invitar/reenviar, suspender/
  # reactivar. people.manage — see routes.rb for why this is a separate
  # capability from roles.manage.
  class PeopleController < ApplicationController
    def index
      authorize!("people.manage")
      Invitations::Expirer.call(institution: Current.institution)

      @memberships = Current.institution.memberships.includes(:user).order(:created_at)
      @memberships = @memberships.where(role: params[:role]) if params[:role].present?
      @roles = Current.institution.memberships.distinct.order(:role).pluck(:role)
      @invitations_by_user = Invitation
        .where(institution_id: Current.institution_id, user_id: @memberships.map(&:user_id))
        .order(created_at: :desc)
        .group_by(&:user_id)
        .transform_values(&:first)
    end

    def new
      authorize!("people.manage")
    end

    def create
      authorize!("people.manage")

      resolved = Core::People::Resolver.call(
        email: params[:email], name: params[:name], national_id: params[:national_id],
        institution: Current.institution
      )
      Audit.log(institution: Current.institution, actor_institution_user: Current.institution_user,
        action: "person.created", target: resolved.user)
      Invitations::Issuer.call(user: resolved.user, institution: Current.institution,
        created_by: Current.institution_user)

      redirect_to identity_access_people_path, notice: "Invitamos a #{resolved.user.email}."
    rescue ActiveRecord::RecordInvalid => e
      @error = e.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end

    def resend_invitation
      membership = find_membership
      authorize!("people.manage", membership)

      Invitations::Issuer.call(user: membership.user, institution: Current.institution,
        created_by: Current.institution_user)
      redirect_to identity_access_people_path, notice: "Reenviamos la invitación."
    end

    def suspend
      membership = find_membership
      authorize!("people.manage", membership)

      membership.suspend!
      Audit.log(institution: Current.institution, actor_institution_user: Current.institution_user,
        action: "person.suspended", target: membership.user)
      redirect_to identity_access_people_path, notice: "Cuenta suspendida."
    end

    def reactivate
      membership = find_membership
      authorize!("people.manage", membership)

      membership.reactivate!
      Audit.log(institution: Current.institution, actor_institution_user: Current.institution_user,
        action: "person.reactivated", target: membership.user)
      redirect_to identity_access_people_path, notice: "Cuenta reactivada."
    end

    private

    def find_membership
      Current.institution.memberships.find(params[:id])
    end
  end
end
