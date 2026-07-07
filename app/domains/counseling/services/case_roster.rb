module Counseling
  # STUB roster of counseling cases. Real Case/SessionNote/Referral tables
  # exist (with RLS) but carry no seed data — same situation as departments/
  # staff_members in teacher_management. The README already documents that
  # gating this on counseling.read is "planned, not yet implemented"; this is
  # that gate, built the same way as every other domain in this phase.
  #
  # TODO: reemplazar por Counseling::Case + SessionNote reales.
  module CaseRoster
    Note = Data.define(:author, :occurred_at, :body)
    Row = Data.define(:id, :student_id, :student_name, :group_id, :category,
                       :status, :opened_at, :notes)

    def self.all
      [
        Row.new(id: "case-1", student_id: "s-3", student_name: "Isabella Mendoza",
                group_id: "stub-section-9a", category: "conducta", status: "open",
                opened_at: Date.new(2026, 3, 10),
                notes: [
                  Note.new(author: "Laura Gómez Duarte", occurred_at: Date.new(2026, 3, 10),
                           body: "Seguimiento inicial por ausentismo reiterado.")
                ]),
        Row.new(id: "case-2", student_id: "s-9", student_name: "Luciana Restrepo",
                group_id: "stub-section-11b", category: "emocional", status: "in_progress",
                opened_at: Date.new(2026, 2, 20),
                notes: [
                  Note.new(author: "Ana Sofía Beltrán", occurred_at: Date.new(2026, 2, 20),
                           body: "Primera sesión: ansiedad relacionada con transición de colegio."),
                  Note.new(author: "Ana Sofía Beltrán", occurred_at: Date.new(2026, 3, 5),
                           body: "Mejoría reportada por la acudiente.")
                ]),
        Row.new(id: "case-3", student_id: "s-6", student_name: "Nicolás Herrera",
                group_id: "stub-section-10a", category: "familiar", status: "closed",
                opened_at: Date.new(2026, 1, 15), notes: [])
      ]
    end

    def self.find(id)
      all.find { |c| c.id == id.to_s }
    end
  end
end
