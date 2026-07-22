require "test_helper"

# guidelines/CLOSURE_PLAN.md Fase D (fourth increment, v1.50.0): Schedules::
# Room/MeetingPattern, the real replacement for RoomRoster/ScheduleEventRoster
# (100% Data.define stubs). Exercised directly under the tenant GUC (RLS
# FORCE) — same molde as Transportation::RouteTest.
class Schedules::MeetingPatternTest < ActiveSupport::TestCase
  def within_tenant(institution)
    Tenant::Guc.set_local(institution.id)
    yield
  end

  def build_institution
    slug = "mp-#{SecureRandom.hex(4)}"
    Core::Institution.create!(name: "Colegio #{slug}", slug: slug, code: "C-#{SecureRandom.hex(3)}", kind: "school")
  end

  def build_section(institution, name:)
    GroupManagement::Section.create!(institution: institution, name: name, academic_year: 2026)
  end

  def build_subject(institution, name:)
    Schedules::Subject.create!(institution: institution, name: name, code: "#{name}-#{SecureRandom.hex(2)}",
      term: "2026-1")
  end

  test "group_id delegates to the section — the scope-covering descriptor schedule.view reads" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution, name: "9A")
      room = Schedules::Room.create!(institution: institution, name: "Aula 1")
      subject = build_subject(institution, name: "Álgebra")
      pattern = Schedules::MeetingPattern.create!(institution: institution, subject: subject, section: section,
        room: room, day_of_week: "mon", starts_at: "07:00", ends_at: "08:00")

      assert_equal section.id, pattern.group_id
    end
  end

  test "a closed day_of_week is enforced by the DB CHECK (bypassing app validation)" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution, name: "9A")
      room = Schedules::Room.create!(institution: institution, name: "Aula 1")
      subject = build_subject(institution, name: "Álgebra")
      pattern = Schedules::MeetingPattern.new(institution: institution, subject: subject, section: section,
        room: room, day_of_week: "sat", starts_at: "07:00", ends_at: "08:00")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { pattern.save!(validate: false) }
      end
    end
  end

  test "an inverted time range is enforced by the DB CHECK (bypassing app validation)" do
    institution = build_institution
    within_tenant(institution) do
      section = build_section(institution, name: "9A")
      room = Schedules::Room.create!(institution: institution, name: "Aula 1")
      subject = build_subject(institution, name: "Álgebra")
      pattern = Schedules::MeetingPattern.new(institution: institution, subject: subject, section: section,
        room: room, day_of_week: "mon", starts_at: "08:00", ends_at: "07:00")

      assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.transaction(requires_new: true) { pattern.save!(validate: false) }
      end
    end
  end

  test "room double-booking is PERMITTED at the DB level — no EXCLUDE constraint blocks it" do
    institution = build_institution
    within_tenant(institution) do
      section_a = build_section(institution, name: "9A")
      section_b = build_section(institution, name: "10A")
      room = Schedules::Room.create!(institution: institution, name: "Aula 1")
      subject_a = build_subject(institution, name: "Álgebra")
      subject_b = build_subject(institution, name: "Cálculo")

      Schedules::MeetingPattern.create!(institution: institution, subject: subject_a, section: section_a,
        room: room, day_of_week: "mon", starts_at: "07:00", ends_at: "08:00")
      overlapping = Schedules::MeetingPattern.create!(institution: institution, subject: subject_b, section: section_b,
        room: room, day_of_week: "mon", starts_at: "07:30", ends_at: "08:30")

      assert overlapping.persisted?
    end
  end

  test "MeetingPatternPresenter computes conflict for real: room overlap and section overlap, never a stored flag" do
    institution = build_institution
    within_tenant(institution) do
      section_a = build_section(institution, name: "9A")
      section_b = build_section(institution, name: "10A")
      room1 = Schedules::Room.create!(institution: institution, name: "Aula 1")
      room2 = Schedules::Room.create!(institution: institution, name: "Aula 2")
      algebra = build_subject(institution, name: "Álgebra")
      historia = build_subject(institution, name: "Historia")
      calculo = build_subject(institution, name: "Cálculo")

      # Same room, overlapping time, DIFFERENT sections — room conflict.
      mp_a = Schedules::MeetingPattern.create!(institution: institution, subject: algebra, section: section_a,
        room: room1, day_of_week: "mon", starts_at: "07:00", ends_at: "08:00")
      mp_b = Schedules::MeetingPattern.create!(institution: institution, subject: historia, section: section_b,
        room: room1, day_of_week: "mon", starts_at: "07:30", ends_at: "08:30")
      # Same section, overlapping time, DIFFERENT room — section conflict
      # (a group can't be in two classes at once, even in different rooms).
      mp_c = Schedules::MeetingPattern.create!(institution: institution, subject: calculo, section: section_a,
        room: room2, day_of_week: "mon", starts_at: "07:15", ends_at: "08:15")
      # Sequential, same room, same section — never conflicts.
      mp_d = Schedules::MeetingPattern.create!(institution: institution, subject: historia, section: section_a,
        room: room1, day_of_week: "tue", starts_at: "09:00", ends_at: "10:00")

      rows = Schedules::MeetingPatternPresenter.rows_for(institution).index_by(&:id)

      assert rows[mp_a.id].conflict
      assert rows[mp_b.id].conflict
      assert rows[mp_c.id].conflict
      assert_not rows[mp_d.id].conflict
    end
  end
end
