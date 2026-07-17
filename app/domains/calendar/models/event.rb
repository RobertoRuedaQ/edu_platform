module Calendar
  # A shared calendar event (v1.27.0, item #7 of the MVP critical path).
  # Audience is expressed by two mutually-exclusive scope columns, same idiom
  # as role_assignments.scope_*: a grade level XOR a group (section) XOR, when
  # both are null, the whole institution. No `kind` column on purpose — the
  # only writer is this domain; assignment deadlines are DERIVED in the portal
  # timeline (Calendar::Timeline), never stored as rows here.
  class Event < ApplicationRecord
    self.table_name = "calendar_events"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :grade_level, class_name: "GroupManagement::GradeLevel",
      optional: true, foreign_key: :scope_grade_level_id
    belongs_to :group, class_name: "GroupManagement::Section",
      optional: true, foreign_key: :scope_group_id
    belongs_to :created_by_institution_user, class_name: "Core::InstitutionUser", optional: true

    validates :title, presence: true
    validates :starts_at, :ends_at, presence: true
    validate :ends_at_not_before_starts_at
    # Defense in depth alongside the DB CHECK (calendar_events_scope_exclusive_
    # check) — never trust only the constraint, same criterion as
    # Assignment#lock_group_work_after_publish.
    validate :scope_is_not_both

    # Both scope columns null => the event is visible to the whole institution.
    def institution_wide?
      scope_grade_level_id.nil? && scope_group_id.nil?
    end

    private

    def ends_at_not_before_starts_at
      return if starts_at.blank? || ends_at.blank?

      errors.add(:ends_at, "no puede ser anterior al inicio") if ends_at < starts_at
    end

    def scope_is_not_both
      return unless scope_grade_level_id.present? && scope_group_id.present?

      errors.add(:base, "Un evento no puede ser de un grado y un grupo a la vez")
    end
  end
end
