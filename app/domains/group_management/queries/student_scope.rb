module GroupManagement
  # #4 barrido — copies the teacher_management canonical mold (§6.6). Reads
  # real Student rows now instead of the retired StudentRoster stub (that
  # stub file itself stays alive — cafeteria/student_support still consume it
  # for their OWN still-stub surfaces; only group_management's own controllers
  # stop calling it).
  class StudentScope
    def initialize(context:, institution: Current.institution)
      @context = context
      @institution = institution
    end

    def resolve
      GroupManagement::Student
        .where(institution_id: institution.id)
        .includes(:section, :grade_level)
        .order(:last_name, :first_name)
        .select { |student| context.can?("students.read", student) }
    end

    private

    attr_reader :context, :institution
  end
end
