module Schedules
  # #4 barrido — copies the teacher_management canonical mold (§6.6). Reads
  # real Subject rows now (grade_level_id is already a real column — no
  # delegate needed, unlike Teacher#department_id). NOTE: unlike the stub
  # SubjectRoster, which scoped by :group, the real Subject has no group/
  # section link at all (a subject belongs to a grade_level or a program, not
  # a specific section) — grade_level is the real scope dimension here, per
  # the actual schema, not the stub's assumed one.
  class SubjectScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      Schedules::Subject
        .where(institution_id: institution.id)
        .includes(:grade_level, :program)
        .order(:name)
        .select { |subject| context.can?("grades.read", subject) }
    end

    private

    attr_reader :context, :institution
  end
end
