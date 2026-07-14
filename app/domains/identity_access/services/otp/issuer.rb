module IdentityAccess
  module Otp
    # Issues a fresh 6-digit login/step-up code: invalidates any prior live code
    # for the same (user, institution, purpose), stores only a SHA-256 digest
    # (short-TTL single-use numeric code — bcrypt would be pointless overhead),
    # and emails the plaintext. Returns the raw code alongside the record so the
    # flow (and tests) can reach it without ever persisting/logging it.
    class Issuer
      Issued = Data.define(:email_otp, :code)

      TTL = 10.minutes

      def self.call(user:, institution:, purpose:)
        new(user, institution, purpose).call
      end

      def initialize(user, institution, purpose)
        @user = user
        @institution = institution
        @purpose = purpose
      end

      def call
        code = generate_code
        invalidate_prior
        otp = create_otp(code)
        deliver(code)
        Issued.new(email_otp: otp, code: code)
      end

      private

      attr_reader :user, :institution, :purpose

      def generate_code
        SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
      end

      def invalidate_prior
        live_scope.where(consumed_at: nil).update_all(consumed_at: Time.current)
      end

      def create_otp(code)
        EmailOtp.create!(user_id: user.id, institution_id: institution.id, purpose: purpose,
          code_digest: Digest::SHA256.hexdigest(code), expires_at: TTL.from_now)
      end

      # Plain primitives, never the AR record: OtpMailer runs async (deliver_later)
      # with NO tenant GUC, so it must not depend on loading the RLS-scoped EmailOtp.
      def deliver(code)
        OtpMailer.code(email: user.email, code: code).deliver_later
      end

      def live_scope
        EmailOtp.where(user_id: user.id, institution_id: institution.id, purpose: purpose)
      end
    end
  end
end
