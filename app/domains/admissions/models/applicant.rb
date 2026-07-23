module Admissions
  # A prospective student (guidelines/library_prompt.md, Increment 2) —
  # deliberately NEVER a Core::User/Core::InstitutionUser and NEVER a
  # GroupManagement::Student. Plain-text guardian contact only; no
  # membership/login is created for a family that might not be accepted.
  # Admissions::AcceptanceConverter is the ONLY seam that turns one of these
  # into a real Student (+ resolves the guardian via Core::People::Resolver).
  class Applicant < ApplicationRecord
    self.table_name = "admission_applicants"

    belongs_to :institution, class_name: "Core::Institution"
    has_many :applications, class_name: "Admissions::Application", inverse_of: :applicant,
      dependent: :restrict_with_exception

    validates :first_name, :last_name, :gender, :birthdate, :guardian_name, :guardian_email, presence: true

    def full_name = "#{first_name} #{last_name}"
  end
end
