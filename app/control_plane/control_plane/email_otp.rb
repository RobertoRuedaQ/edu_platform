module ControlPlane
  # GLOBAL — mirrors email_otps, scoped to platform_admin instead of
  # (institution, user). S0 only ever issues purpose "sign_in".
  class EmailOtp < ApplicationRecord
    self.table_name = "control_plane_email_otps"

    belongs_to :platform_admin, class_name: "ControlPlane::PlatformAdmin"

    validates :purpose, inclusion: { in: %w[sign_in] }
  end
end
