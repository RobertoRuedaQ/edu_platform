module StudentSupport
  # STUB convivencia/disciplinary log entries, per student. No such model
  # exists in the schema at all.
  # TODO: reemplazar por un modelo real de convivencia/disciplina.
  module DisciplinaryLogRoster
    Row = Data.define(:id, :student_id, :group_id, :occurred_at, :category, :description, :reported_by)

    def self.all
      [
        Row.new(id: "log-1", student_id: "s-3", group_id: GroupManagement::GroupRoster::SECTION_9A_ID,
                occurred_at: Date.new(2026, 2, 12), category: "ausentismo",
                description: "Tercera ausencia sin excusa este mes.", reported_by: "Laura Gómez Duarte"),
        Row.new(id: "log-2", student_id: "s-9", group_id: GroupManagement::GroupRoster::SECTION_11B_ID,
                occurred_at: Date.new(2026, 3, 1), category: "convivencia",
                description: "Conflicto verbal con un compañero durante el descanso.",
                reported_by: "Ana Sofía Beltrán")
      ]
    end

    def self.for_student(student_id)
      all.select { |row| row.student_id == student_id.to_s }
    end
  end
end
