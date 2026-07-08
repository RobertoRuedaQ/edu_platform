module ControlPlane
  module Otp
    # Verifies a sign_in code against the latest live OTP. Every check (right
    # or wrong) burns an attempt; once MAX_ATTEMPTS is reached the code is
    # locked regardless of correctness. Digests are compared timing-safely.
    class Verifier
      MAX_ATTEMPTS = 5
      PURPOSE = "sign_in"

      def self.call(platform_admin:, code:)
        new(platform_admin, code).call
      end

      def initialize(platform_admin, code)
        @platform_admin = platform_admin
        @code = code
      end

      def call
        otp = latest_otp
        return Result.failure("expired_or_missing") if otp.nil?
        return Result.failure("locked") if otp.attempts >= MAX_ATTEMPTS

        otp.increment!(:attempts)
        matches?(otp) ? consume(otp) : Result.failure("incorrect")
      end

      private

      attr_reader :platform_admin, :code

      def latest_otp
        EmailOtp.where(platform_admin_id: platform_admin.id, purpose: PURPOSE, consumed_at: nil)
          .where("expires_at > ?", Time.current)
          .order(created_at: :desc).first
      end

      def matches?(otp)
        ActiveSupport::SecurityUtils.secure_compare(otp.code_digest, Digest::SHA256.hexdigest(code))
      end

      def consume(otp)
        otp.update!(consumed_at: Time.current)
        Result.success
      end
    end
  end
end
