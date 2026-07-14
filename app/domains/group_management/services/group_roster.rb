module GroupManagement
  # #4 barrido (v1.14.0): group_management's OWN controllers now read real
  # GroupManagement::Section rows (see GroupScope) — the roster behavior
  # (.all/.find/Row) this module used to provide is retired. Only the
  # canonical section id CONSTANTS survive: they're still load-bearing —
  # referenced as fixed group_id values by still-stub cross-domain rosters
  # (schedules' timetable half, student_support, counseling's pre-barrido
  # stub) AND by test_helper.rb's grant_role!(scope_type: :group, scope_id:),
  # which creates a REAL Section row with this exact id if one doesn't exist
  # yet. Kept greppable/deterministic rather than random so those call sites
  # keep agreeing on the same id.
  module GroupRoster
    SECTION_9A_ID  = "aaaaaaaa-0000-4000-8000-00000000009a".freeze
    SECTION_10A_ID = "aaaaaaaa-0000-4000-8000-0000000010a0".freeze
    SECTION_11B_ID = "aaaaaaaa-0000-4000-8000-0000000011b0".freeze
  end
end
