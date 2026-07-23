module IdentityAccess
  # Scoped RBAC grant. All scope_* NULL = institution-wide. A person in several
  # groups is several rows (one per scope), not one row with many columns.
  class RoleAssignment < ApplicationRecord
    self.table_name = "role_assignments"
    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :institution_user, class_name: "Core::InstitutionUser"
    belongs_to :role, class_name: "IdentityAccess::Role", inverse_of: :role_assignments

    # Explicit scope columns (better indexes/FKs than polymorphic). "group" = section.
    belongs_to :scope_department,  class_name: "StaffManagement::Department",   optional: true
    belongs_to :scope_grade_level, class_name: "GroupManagement::GradeLevel",   optional: true
    belongs_to :scope_group,       class_name: "GroupManagement::Section",      optional: true
    belongs_to :scope_route,       class_name: "Transportation::Route",        optional: true

    # OPEN_PROCESS.md B2: opt-in coupling to a term — when set,
    # Core::AcademicTermsController#close caps valid_until at the term's
    # ends_on. Nil means unchanged legacy behavior (independent calendar dates).
    belongs_to :academic_term, class_name: "Core::AcademicTerm", optional: true

    # R5 (dating): a grant only applies within [valid_from, valid_until].
    # valid_until nil == open-ended.
    scope :effective_now, -> {
      today = Date.current
      where("valid_from <= ?", today).where("valid_until IS NULL OR valid_until >= ?", today)
    }

    # Human-readable label of the scope, for badges/rows.
    def scope_label
      return "Toda la institución" if institution_wide?
      [ scope_department&.name, scope_grade_level&.name, scope_group&.name, scope_route&.name ].compact.join(" · ")
    end

    def institution_wide?
      scope_department_id.nil? && scope_grade_level_id.nil? && scope_group_id.nil? && scope_route_id.nil?
    end
  end
end
