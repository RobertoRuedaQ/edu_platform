module Schedules
  # STUB grades (assessments) for each subject offering's roster — cross-domain
  # read of GroupManagement::StudentRoster (both are stub, so this is just
  # Ruby, not a real query) so grades line up with the same students shown
  # elsewhere. Deterministic (no rand/sample) so repeated views are stable.
  #
  # TODO: reemplazar por Schedules::Assessment real vía Enrollment.
  module GradeEntryRoster
    Row = Data.define(:id, :subject_id, :student_id, :student_name, :kind, :title, :score)

    SLOTS = [ { kind: "parcial", title: "Parcial 1" }, { kind: "parcial", title: "Parcial 2" } ].freeze
    SCORES = [ 3.2, 4.5, 2.8, 3.9, 4.1, 3.4, 4.8, 2.5 ].freeze

    def self.all
      @all ||= build_all
    end

    def self.for_subject(subject_id)
      all.select { |row| row.subject_id == subject_id }
    end

    def self.build_all
      SubjectRoster.all.each_with_index.flat_map do |subject, subject_index|
        GroupManagement::StudentRoster.for_group(subject.group_id).each_with_index.flat_map do |student, student_index|
          SLOTS.each_with_index.map do |slot, slot_index|
            # First slot gets a deterministic sample score; later slots are
            # "pendiente" (nil) — mirrors real grading workflow (not every
            # assessment is scored yet).
            score = slot_index.zero? ? SCORES[(subject_index + student_index) % SCORES.size] : nil
            Row.new(id: "#{subject.id}-#{student.id}-#{slot_index}", subject_id: subject.id,
                    student_id: student.id, student_name: student.name,
                    kind: slot[:kind], title: slot[:title], score: score)
          end
        end
      end
    end
    private_class_method :build_all
  end
end
