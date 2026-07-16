module Assignments
  # Forms ONE work group from the assignment's roster (a group assignment,
  # already published — the roster is only concrete after publish, §3).
  # No #destroy/#update this slice — correcting a mistake is out of scope,
  # matching the "don't build beyond what's asked" discipline.
  class SubmissionGroupsController < ApplicationController
    def create
      @subject = find_subject
      @assignment = find_assignment
      authorize!("assignment.manage", @subject)

      unless @assignment.group_work? && @assignment.published?
        redirect_to assignments_subject_assignment_path(@subject, @assignment),
          alert: "Solo se pueden formar grupos en una tarea grupal ya publicada."
        return
      end

      roster_ids = Assignments::Roster.for_subject(@subject).pluck(:id).map(&:to_s)
      already_grouped_ids = Assignments::GroupMembership.where(assignment_id: @assignment.id).pluck(:student_id).map(&:to_s)
      selected_ids = (Array(params[:student_ids]) & roster_ids) - already_grouped_ids

      if selected_ids.empty?
        redirect_to assignments_subject_assignment_path(@subject, @assignment),
          alert: "Selecciona al menos un estudiante del roster que no tenga grupo todavía."
        return
      end

      Assignments::Assignment.transaction do
        group = Assignments::SubmissionGroup.create!(institution: Current.institution, assignment: @assignment,
          name: params[:name].presence || "Grupo #{@assignment.submission_groups.count + 1}")
        selected_ids.each do |student_id|
          Assignments::GroupMembership.create!(institution: Current.institution, assignment: @assignment,
            submission_group: group, student_id: student_id)
        end
      end

      redirect_to assignments_subject_assignment_path(@subject, @assignment), notice: "Grupo formado."
    end

    private

    def find_subject
      subject = Schedules::Subject.find_by(institution_id: Current.institution_id, id: params[:subject_id])
      raise ActiveRecord::RecordNotFound if subject.nil?

      subject
    end

    def find_assignment
      assignment = Assignments::Assignment.find_by(institution_id: Current.institution_id, subject_id: @subject.id,
        id: params[:assignment_id])
      raise ActiveRecord::RecordNotFound if assignment.nil?

      assignment
    end
  end
end
