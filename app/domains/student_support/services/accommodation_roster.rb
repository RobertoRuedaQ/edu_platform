module StudentSupport
  # STUB accommodations/adaptations, per student. No real model exists yet.
  # TODO: reemplazar por un modelo real de acomodaciones cuando exista.
  module AccommodationRoster
    Row = Data.define(:id, :student_id, :group_id, :kind, :description, :status)

    def self.all
      [
        Row.new(id: "acc-1", student_id: "s-1", group_id: GroupManagement::GroupRoster::SECTION_9A_ID,
                kind: "tiempo_extra",
                description: "Tiempo adicional (30%) en evaluaciones por diagnóstico de TDAH.",
                status: "active"),
        Row.new(id: "acc-2", student_id: "s-7", group_id: GroupManagement::GroupRoster::SECTION_11B_ID,
                kind: "material_adaptado",
                description: "Material en fuente ampliada por baja visión.", status: "active"),
        Row.new(id: "acc-3", student_id: "s-3", group_id: GroupManagement::GroupRoster::SECTION_9A_ID,
                kind: "ubicacion_preferencial",
                description: "Ubicación cerca al tablero por dificultad auditiva.", status: "expired")
      ]
    end

    def self.for_student(student_id)
      all.select { |row| row.student_id == student_id.to_s }
    end

    def self.find(id)
      all.find { |row| row.id == id.to_s }
    end
  end
end
