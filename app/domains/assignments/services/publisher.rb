module Assignments
  # Publishing is the fan-out: ONE Schedules::Assessment per roster student
  # (Assignments::Roster), each starting ungraded (score: nil — a normal
  # state, same as any assessment report_cards already treats as "no line
  # yet"). Idempotent by construction: only fires on the draft -> published
  # transition (never re-fans-out a re-publish, since #published? short-
  # circuits) — there is no re-publish action in this slice.
  class Publisher
    def self.call(assignment)
      new(assignment).call
    end

    def initialize(assignment)
      @assignment = assignment
    end

    def call
      return assignment if assignment.published?

      Assignments::Assignment.transaction do
        Assignments::Roster.for_subject(assignment.subject, institution: assignment.institution).find_each do |student|
          enrollment = Schedules::Enrollment.find_by(institution_id: assignment.institution_id,
            student_id: student.id, subject_id: assignment.subject_id)
          next if enrollment.nil?

          enrollment.assessments.create!(institution: assignment.institution, assignment: assignment,
            kind: "tarea", title: assignment.title, term: assignment.subject.term)
        end
        assignment.update!(status: "published", published_at: Time.current)
      end
      assignment
    end

    private

    attr_reader :assignment
  end
end
