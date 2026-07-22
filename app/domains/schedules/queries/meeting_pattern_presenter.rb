module Schedules
  # THE single read path that turns real Schedules::MeetingPattern rows into
  # the Row shape ScheduleEventRoster used to hand to views/helpers
  # (schedule_event_badge reads .conflict/.room_name) — one computation,
  # reused by ScheduleScope/TimetableScope/RoomsController#show, so the
  # three surfaces can never disagree about what conflicts.
  #
  # Conflict is COMPUTED for real here (the retired stub only ever REFLECTED
  # a baked-in flag, per Apéndice A) over the INSTITUTION-WIDE set of
  # patterns, never the caller's already-scoped subset — a conflict is still
  # flagged even when the other side of it falls outside the caller's own
  # scope (e.g. a different section's class in the same room). Two patterns
  # conflict when they meet the SAME day, their time ranges overlap, AND
  # either share the same room (can't both use it) or the same section (a
  # group can't be in two classes at once). Room double-booking is
  # deliberately NOT blocked at the DB level (owner decision) — this is the
  # real replacement for the stub's inert flag, not a rejection.
  module MeetingPatternPresenter
    Row = Data.define(:id, :day, :starts_at, :ends_at, :subject_name, :group_id, :group_name,
                       :room_id, :room_name, :conflict)

    module_function

    def rows_for(institution)
      patterns = Schedules::MeetingPattern.where(institution_id: institution.id)
        .includes(:subject, :section, :room).to_a
      patterns.map { |mp| to_row(mp, conflict?(mp, patterns)) }
    end

    def conflict?(pattern, all)
      all.any? do |other|
        other.id != pattern.id &&
          other.day_of_week == pattern.day_of_week &&
          (other.room_id == pattern.room_id || other.section_id == pattern.section_id) &&
          overlaps?(pattern, other)
      end
    end

    def overlaps?(a, b)
      a.starts_at < b.ends_at && b.starts_at < a.ends_at
    end

    def to_row(mp, conflict)
      Row.new(id: mp.id, day: mp.day_label, starts_at: mp.starts_at.strftime("%H:%M"),
              ends_at: mp.ends_at.strftime("%H:%M"), subject_name: mp.subject.name, group_id: mp.group_id,
              group_name: mp.section.name, room_id: mp.room_id, room_name: mp.room.name, conflict: conflict)
    end
  end
end
