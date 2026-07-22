module GroupManagement
  # THE single write seam that moves a student between sections (BI_DOCUMENT.md
  # §5.2, Slice 4). It keeps TWO things in lock-step, so no call site ever has
  # to know about placement history:
  #
  #   1. students.section_id — the LIVE CACHE of the current placement (§5.2;
  #      many flows read it, so it stays).
  #   2. student_placements  — the append-only historical axis: the current open
  #      placement is CLOSED (valid_until = Date.current) and a new one OPENED,
  #      the exact symmetric "close the range" mold as SeatAssigner /
  #      ClassroomReconfigurer (v1.36.0) and Subscription#end!/Entitlement#revoke!
  #      (v1.33.0). Closing at Date.current keeps [from, today) and [today, ∞)
  #      adjacent, never overlapping — satisfies the GiST EXCLUDE and works even
  #      the same day a placement was opened.
  #
  # section: nil means UNASSIGN (student leaves the group) — the cache is set to
  # nil and the open placement is closed, but no new one is opened (an unplaced
  # student has no active placement).
  #
  # IDEMPOTENT: if the student is already in the target section AND already has a
  # matching open placement, this is a no-op — re-submitting the same roster
  # never churns history. If the section matches but the open placement is
  # MISSING (e.g. a pre-backfill student, or one created via roster import), the
  # placement is still opened — the seam self-heals the invariant.
  #
  # A placement needs a grade_level_id (NOT NULL). It is resolved from the
  # student's own grade_level, falling back to the section's. If neither exists
  # (a section with no grade level and a student with no grade level) OR there is
  # no active academic term, the cache is still updated but no placement row is
  # written — documented edge, the NOT NULL columns could not be satisfied anyway.
  class SectionReassigner
    Result = Data.define(:student, :placement, :previous)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(student:, section:, institution: Current.institution)
      @student = student
      @section = section
      @institution = institution
    end

    def call
      target_id = section&.id
      open_placement = current_placement
      return no_op if target_id == student.section_id && matching?(open_placement, target_id)

      # requires_new: true -> a SAVEPOINT, so a would-be overlap violation rolls
      # back only this unit and re-raises without poisoning the caller's request
      # transaction (TenantScoped's around_action). Same posture as SeatAssigner.
      ActiveRecord::Base.transaction(requires_new: true) do
        student.update!(section_id: target_id)
        open_placement&.update!(valid_until: Date.current)
        placement = open_new_placement
        Result.new(student: student, placement: placement, previous: open_placement)
      end
    end

    private

    attr_reader :student, :section, :institution

    def no_op
      Result.new(student: student, placement: current_placement, previous: nil)
    end

    def matching?(placement, target_id)
      target_id.nil? ? placement.nil? : placement&.section_id == target_id
    end

    def current_placement
      GroupManagement::StudentPlacement
        .where(institution_id: institution.id, student_id: student.id)
        .current
        .first
    end

    # Opens a placement only when a section is targeted AND the NOT NULL columns
    # can be satisfied (grade level resolvable + an active term exists).
    def open_new_placement
      return nil if section.nil?

      grade_level_id = student.grade_level_id || section.grade_level_id
      term = active_term
      return nil if grade_level_id.nil? || term.nil?

      GroupManagement::StudentPlacement.create!(
        institution: institution, student: student, section: section,
        grade_level_id: grade_level_id, academic_term: term, valid_from: Date.current
      )
    end

    def active_term
      Core::AcademicTerm.active.find_by(institution_id: institution.id)
    end
  end
end
