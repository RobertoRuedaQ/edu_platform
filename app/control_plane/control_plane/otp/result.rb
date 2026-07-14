module ControlPlane
  module Otp
    Result = Data.define(:success, :error) do
      def self.success = new(success: true, error: nil)
      def self.failure(error) = new(success: false, error: error)
      def success? = success
    end
  end
end
