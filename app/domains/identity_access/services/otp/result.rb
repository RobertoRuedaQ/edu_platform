module IdentityAccess
  module Otp
    # Minimal result object for OTP verification. Data members can't be
    # predicates, so success? wraps the boolean member.
    Result = Data.define(:success, :error) do
      def self.success = new(success: true, error: nil)
      def self.failure(error) = new(success: false, error: error)

      def success? = success
    end
  end
end
