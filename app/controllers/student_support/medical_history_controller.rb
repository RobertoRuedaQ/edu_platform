module StudentSupport
  # Two tiers of the SAME resource: medical_history.view (full record — the
  # owner, medical_staff) and medical_history.view_summary (allergies/
  # contraindications only — counselor). authorize! only takes one permission
  # key, so this tries the wider grant first and falls back to the narrower
  # one; if NEITHER matches, it still raises via authorize! (the same hard
  # gate, same 403) — can? here decides WHICH tier renders, it never is the
  # last word on whether access is granted at all.
  #
  # REAL since guidelines/CLOSURE_PLAN.md Fase D — StudentSupport::
  # MedicalHistory/StudentAllergy replace the MedicalHistoryRoster stub. The
  # page is about the STUDENT, not one specific row: a student with no
  # MedicalHistory row yet still renders (an honest empty state for
  # conditions/medications), it never 404s just because nobody has filled it
  # in yet — same posture as a student with zero disciplinary_logs.
  class MedicalHistoryController < ApplicationController
    Presenter = Data.define(:student_name, :group_id, :blood_type, :conditions, :medications, :allergies)

    def show
      @student = find_student
      @record = build_presenter(@student)

      if authorization_context.can?("medical_history.view", @record)
        @tier = :full
      elsif authorization_context.can?("medical_history.view_summary", @record)
        @tier = :summary
      else
        authorize!("medical_history.view", @record) # no grant matches -> raises -> 403
      end
    end

    # Full-tier only (medical_history.view) — editing conditions/medications/
    # blood type is the owner's (medical_staff) job, never the narrow
    # counselor tier's.
    def edit
      @student = find_student
      authorize!("medical_history.view", presenter_for_authorize(@student))
      @history = StudentSupport::MedicalHistory.find_or_initialize_by(
        institution_id: Current.institution_id, student_id: @student.id
      )
    end

    def update
      @student = find_student
      authorize!("medical_history.view", presenter_for_authorize(@student))
      @history = StudentSupport::MedicalHistory.find_or_initialize_by(
        institution_id: Current.institution_id, student_id: @student.id
      )
      if @history.update(history_params)
        redirect_to student_support_student_medical_history_path(@student.id), notice: "Historia médica actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def find_student
      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
      raise ActiveRecord::RecordNotFound if student.nil?

      student
    end

    # A lightweight resource just for the authorize!/can? scope check on
    # edit/update — doesn't need the full presenter's allergy list.
    def presenter_for_authorize(student)
      Presenter.new(student_name: nil, group_id: student.group_id, blood_type: nil, conditions: [], medications: [], allergies: [])
    end

    def build_presenter(student)
      history = StudentSupport::MedicalHistory.find_by(institution_id: Current.institution_id, student_id: student.id)
      allergies = StudentSupport::StudentAllergy.where(institution_id: Current.institution_id, student_id: student.id)
      Presenter.new(
        student_name: "#{student.first_name} #{student.last_name}", group_id: student.group_id,
        blood_type: history&.blood_type, conditions: Array(history&.conditions), medications: Array(history&.medications),
        allergies: allergies
      )
    end

    def history_params
      params.require(:medical_history).permit(:blood_type).tap do |permitted|
        permitted[:conditions] = params[:medical_history][:conditions].to_s.split("\n").map(&:strip).reject(&:blank?)
        permitted[:medications] = params[:medical_history][:medications].to_s.split("\n").map(&:strip).reject(&:blank?)
      end
    end
  end
end
