module StudentSupport
  # STUB medical history, one row per student. No medical model exists at all
  # in the schema — this is the most stub-only domain yet, alongside
  # schedules' timetable/rooms.
  #
  # Two access tiers, enforced in the controller (never here):
  #   medical_history.view          — full record (medical_staff, the owner)
  #   medical_history.view_summary  — allergies/contraindications only (counselor)
  #
  # TODO: reemplazar por un modelo real de historia médica cuando exista.
  module MedicalHistoryRoster
    Allergy = Data.define(:name, :severity, :reaction)
    Row = Data.define(:student_id, :student_name, :group_id, :blood_type,
                       :conditions, :medications, :allergies)

    def self.all
      [
        Row.new(student_id: "s-1", student_name: "Valentina Suárez", group_id: GroupManagement::GroupRoster::SECTION_9A_ID,
                blood_type: "O+", conditions: [ "Asma leve" ], medications: [ "Salbutamol (inhalador, según necesidad)" ],
                allergies: [ Allergy.new(name: "Maní", severity: :severe, reaction: "Urticaria y dificultad respiratoria") ]),
        Row.new(student_id: "s-4", student_name: "Mateo Cárdenas", group_id: GroupManagement::GroupRoster::SECTION_10A_ID,
                blood_type: "A-", conditions: [], medications: [],
                allergies: [ Allergy.new(name: "Penicilina", severity: :moderate, reaction: "Erupción cutánea") ]),
        Row.new(student_id: "s-7", student_name: "Daniela Ortiz", group_id: GroupManagement::GroupRoster::SECTION_11B_ID,
                blood_type: "B+", conditions: [ "Diabetes tipo 1" ], medications: [ "Insulina (según esquema)" ],
                allergies: [])
      ]
    end

    def self.find_by_student(student_id)
      all.find { |row| row.student_id == student_id.to_s }
    end
  end
end
