module ControlPlane
  # GLOBAL, self-contained platform-admin identity (F1: deliberately NOT a
  # Core::User — two planes, opposite security rules, duplicating a thin auth
  # model is cheaper than a polymorphic OTP/session layer that couples them).
  #
  # Unlike Core::User, has_secure_password keeps its DEFAULT presence
  # validation: in S0 the only way a platform_admin is created is the
  # bootstrap CLI task, which always sets a password up front, so
  # password_digest is never nil here.
  class PlatformAdmin < ApplicationRecord
    self.table_name = "platform_admins"

    has_secure_password

    has_many :sessions, class_name: "ControlPlane::Session",
      foreign_key: :platform_admin_id, dependent: :destroy
    has_many :email_otps, class_name: "ControlPlane::EmailOtp",
      foreign_key: :platform_admin_id, dependent: :destroy

    validates :email, presence: true, uniqueness: true
    validates :name, presence: true
    validates :status, inclusion: { in: %w[active suspended] }
    validates :role, inclusion: { in: %w[super_admin billing_ops viewer] }

    scope :active, -> { where(status: "active") }
    scope :suspended, -> { where(status: "suspended") }

    def suspend!    = update!(status: "suspended")
    def reactivate! = update!(status: "active")
    def active?     = status == "active"
  end
end
