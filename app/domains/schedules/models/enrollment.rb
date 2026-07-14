module Schedules
  # A student enrolled in a subject for a term.
  class Enrollment < ApplicationRecord
    self.table_name = "enrollments"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :student, class_name: "GroupManagement::Student", inverse_of: :enrollments
    belongs_to :subject, class_name: "Schedules::Subject",       inverse_of: :enrollments
    # Closes the model half of Cav./B2 (v1.15.0): the REAL term join,
    # additive/nullable — coexists with the legacy `term` string (kept as
    # display-only, never cross-validated against this FK, same coexistence
    # pattern as guardian_students/student_guardians). A nil academic_term_id
    # is a normal state (enrollment predates this column, or no active term
    # was resolvable at creation time), never an error.
    belongs_to :academic_term, class_name: "Core::AcademicTerm", optional: true
    has_many :assessments, class_name: "Schedules::Assessment",
             foreign_key: :enrollment_id, inverse_of: :enrollment, dependent: :destroy
  end
end
