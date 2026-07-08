module ControlPlane
  module Otp
    # Self-contained MFA (F1 — no reuse of IdentityAccess::Otp::*, which is
    # keyed on user+institution and doesn't fit a platform_admin). Issues a
    # fresh 6-digit sign_in code: invalidates any prior live code for the same
    # platform_admin, stores only a SHA-256 digest (short-TTL single-use
    # numeric code — bcrypt would be pointless overhead), and emails the
    # plaintext.
    class Issuer
      Issued = Data.define(:email_otp, :code)

      TTL = 10.minutes
      PURPOSE = "sign_in"

      def self.call(platform_admin:)
        new(platform_admin).call
      end

      def initialize(platform_admin)
        @platform_admin = platform_admin
      end

      def call
        code = generate_code
        invalidate_prior
        otp = create_otp(code)
        deliver(code)
        Issued.new(email_otp: otp, code: code)
      end

      private

      attr_reader :platform_admin

      def generate_code
        SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
      end

      def invalidate_prior
        live_scope.where(consumed_at: nil).update_all(consumed_at: Time.current)
      end

      def create_otp(code)
        EmailOtp.create!(platform_admin_id: platform_admin.id, purpose: PURPOSE,
          code_digest: Digest::SHA256.hexdigest(code), expires_at: TTL.from_now)
      end

      # Plain primitives, never the AR record — mirrors IdentityAccess's
      # mailer boundary. No tenant GUC to worry about here either way: the
      # control plane has none.
      def deliver(code)
        OtpMailer.code(email: platform_admin.email, code: code).deliver_later
      end

      def live_scope
        EmailOtp.where(platform_admin_id: platform_admin.id, purpose: PURPOSE)
      end
    end
  end
end
