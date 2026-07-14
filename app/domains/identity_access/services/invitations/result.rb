module IdentityAccess
  module Invitations
    # Minimal result object for Completer. Data members can't be predicates,
    # so success? wraps the boolean member (same shape as Otp::Result).
    Result = Data.define(:success, :error, :user) do
      def self.success(user) = new(success: true, error: nil, user: user)
      def self.failure(error) = new(success: false, error: error, user: nil)

      def success? = success
    end
  end
end
