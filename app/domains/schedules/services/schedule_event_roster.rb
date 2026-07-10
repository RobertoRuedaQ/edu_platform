module Schedules
  # STUB weekly timetable events. Feeds both "mi horario" (schedule.view,
  # filtered to the actor's own group) and the institutional timetable
  # (timetable.manage, sees everything). conflict is a stub flag baked into
  # the data — Apéndice A is explicit that this view REFLECTS a conflict flag,
  # it never computes one.
  #
  # TODO: reemplazar por un modelo real de horario/periodos — no existe ni la
  # tabla hoy (ni siquiera una columna a medio poblar, a diferencia de
  # teachers/students).
  module ScheduleEventRoster
    Row = Data.define(:id, :day, :starts_at, :ends_at, :subject_name, :group_id,
                       :group_name, :room_name, :conflict)

    def self.all
      [
        Row.new(id: "ev-1", day: "Lun", starts_at: "07:00", ends_at: "08:00",
                subject_name: "Álgebra", group_id: GroupManagement::GroupRoster::SECTION_9A_ID, group_name: "9°A",
                room_name: "Aula 101", conflict: false),
        Row.new(id: "ev-2", day: "Lun", starts_at: "08:00", ends_at: "09:00",
                subject_name: "Historia", group_id: GroupManagement::GroupRoster::SECTION_9A_ID, group_name: "9°A",
                room_name: "Aula 101", conflict: false),
        Row.new(id: "ev-3", day: "Mar", starts_at: "07:00", ends_at: "08:00",
                subject_name: "Cálculo", group_id: GroupManagement::GroupRoster::SECTION_10A_ID, group_name: "10°A",
                room_name: "Aula 102", conflict: false),
        # Same room + day + hour as ev-3 — a baked-in stub conflict, not detected.
        Row.new(id: "ev-4", day: "Mar", starts_at: "07:00", ends_at: "08:00",
                subject_name: "Sociología", group_id: GroupManagement::GroupRoster::SECTION_11B_ID, group_name: "11°B",
                room_name: "Aula 102", conflict: true),
        Row.new(id: "ev-5", day: "Mié", starts_at: "09:00", ends_at: "10:00",
                subject_name: "Álgebra", group_id: GroupManagement::GroupRoster::SECTION_9A_ID, group_name: "9°A",
                room_name: "Aula 101", conflict: false),
        Row.new(id: "ev-6", day: "Jue", starts_at: "07:00", ends_at: "08:00",
                subject_name: "Sociología", group_id: GroupManagement::GroupRoster::SECTION_11B_ID, group_name: "11°B",
                room_name: "Aula 103", conflict: false)
      ]
    end

    def self.for_group(group_id)
      all.select { |event| event.group_id == group_id }
    end
  end
end
