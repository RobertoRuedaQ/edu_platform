module ReportCards
  # The publish action. Real target model (ReportCards::ReportCard) exists in
  # THIS slice, same as Attendance::RecordsController (v1.16.0) — so the
  # write is cabled completely, not gate-only. Idempotent batch publish:
  # publishing the SAME (student, academic_term) again regenerates the
  # snapshot via ReportCards::Publisher, never duplicates (unique index on
  # report_cards).
  class PublicationsController < ApplicationController
    def new
      @group = find_group
      authorize!("report_card.view", @group)
      @academic_term = active_term
      @rows = @academic_term ? roster_for(@group).map { |student| build_row(student) } : []
    end

    def create
      @group = find_group
      authorize!("report_card.publish", @group)
      @academic_term = active_term

      if @academic_term.nil?
        @error = "No hay un término activo para esta institución."
        @rows = []
        return render :new, status: :unprocessable_entity
      end

      selected_ids = Array(params[:student_ids])
      students = roster_for(@group).select { |student| selected_ids.include?(student.id) }
      publisher = StaffManagement::StaffMember.find_by(
        institution_id: Current.institution_id, institution_user_id: Current.institution_user_id
      )
      ReportCards::Publisher.call(institution: Current.institution, academic_term: @academic_term,
        students: students, published_by_staff_member: publisher)

      redirect_to report_cards_groups_path, notice: "Boletines publicados para #{@group.name}."
    end

    private

    def find_group
      group = GroupManagement::Section.find_by(institution_id: Current.institution_id, id: params[:group_id])
      raise ActiveRecord::RecordNotFound if group.nil?

      group
    end

    def active_term
      Core::AcademicTerm.active.find_by(institution_id: Current.institution_id)
    end

    # The roster tomable (same three-layer discipline as attendance, v1.16.0):
    # Schedules::ActiveTermEnrollmentScope (never re-derived here) ∩ this group.
    def roster_for(group)
      Schedules::ActiveTermEnrollmentScope.resolve(institution: Current.institution)
        .where(section_id: group.id)
        .order(:last_name, :first_name)
    end

    def build_row(student)
      computation = ReportCards::Computation.call(student: student, academic_term: @academic_term,
        institution: Current.institution)
      published = ReportCards::ReportCard.find_by(institution_id: Current.institution_id,
        student_id: student.id, academic_term_id: @academic_term.id)
      { student: student, computation: computation, published: published }
    end
  end
end
