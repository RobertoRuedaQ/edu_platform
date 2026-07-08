module Core
  module People
    # Finds the existing Core::User for a real human — a person is always
    # exactly ONE global users row, never duplicated across institutions or
    # roster runs — or creates one, then attaches (find_or_create, never
    # duplicates) the institution_users membership. national_id is the
    # durable real-world identifier and is checked first; a person with no
    # document on file yet falls back to the global email.
    class Resolver
      Resolved = Data.define(:user, :institution_user, :new_user)

      def self.call(email:, name:, institution:, national_id: nil, role: "member")
        new(email, name, institution, national_id, role).call
      end

      def initialize(email, name, institution, national_id, role)
        @email = email.to_s.downcase.strip
        @name = name
        @institution = institution
        @national_id = national_id.presence
        @role = role
      end

      def call
        existing = find_existing
        user = existing || create_user
        membership = attach_membership(user)
        Resolved.new(user: user, institution_user: membership, new_user: existing.nil?)
      end

      private

      attr_reader :email, :name, :institution, :national_id, :role

      def find_existing
        by_national_id || Core::User.find_by(email: email)
      end

      def by_national_id
        return nil unless national_id
        Core::User.find_by(national_id: national_id)
      end

      def create_user
        Core::User.create!(email: email, name: name, national_id: national_id)
      end

      def attach_membership(user)
        Core::InstitutionUser.find_or_create_by!(institution: institution, user: user) do |m|
          m.role = role
        end
      end
    end
  end
end
