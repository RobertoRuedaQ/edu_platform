module GroupManagement
  # One-shot (idempotent, re-runnable) backfill for Slice 4 (BI_DOCUMENT.md
  # §5.2). Every active student today has a CURRENT section (students.section_id)
  # but NO historical placement row — this creates ONE open placement per active,
  # placed student at today's date / the active academic term, so the invariant
  # "every active placed student has an open placement" holds going forward.
  #
  # Runs UNDER the tenant's own GUC (RLS) — the caller (lib/tasks, or a future
  # *AllJob fan-out) sets it, exactly like Core::Headcount::Snapshotter trusts
  # its caller. Batched with find_each (default 1000) so a large tenant never
  # loads every student into memory at once; per-tenant student counts are
  # bounded, so a rake fan-out over institutions is sufficient here (no throttled
  # background job needed at this scale — documented, revisit if a tenant grows
  # past find_each's comfort).
  #
  # IDEMPOTENT via SectionReassigner's own self-healing no-op: a student who
  # already has a matching open placement is skipped; one missing a placement
  # (or pointing at a stale section) gets it opened/reconciled. Safe to re-run
  # after a roster import (which sets section_id on creation but does not, in
  # this slice, open a placement).
  #
  # Skips (counted, never raised): students with no section_id (nothing to place
  # them in), and — inside SectionReassigner — those with no resolvable grade
  # level or no active term.
  module PlacementBackfill
    module_function

    Result = Data.define(:placed, :skipped)

    def run(institution: Current.institution)
      placed = 0
      skipped = 0

      GroupManagement::Student
        .where(institution_id: institution.id, status: "active")
        .find_each do |student|
          if student.section_id.nil?
            skipped += 1
            next
          end

          section = GroupManagement::Section.find_by(institution_id: institution.id, id: student.section_id)
          result = GroupManagement::SectionReassigner.call(student: student, section: section, institution: institution)
          result.placement ? placed += 1 : skipped += 1
        end

      Result.new(placed: placed, skipped: skipped)
    end
  end
end
