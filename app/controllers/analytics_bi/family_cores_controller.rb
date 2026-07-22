module AnalyticsBi
  # Lens 4 — "Núcleo Familiar" (BI_DOCUMENT.md §4/§5.6, Slice 8). SUPERVISION
  # (molde #4): authorize!("hps.family.view") at the top — INSTITUTION-WIDE
  # ONLY (§4: orientación/directivas), no smaller scope reader for this lens
  # (a family spans sections/grades by definition, unlike Lens 1/3).
  #
  # The entry point is a supervised student (student_id in params) — never a
  # person search (§1.1.6). The orbital graph never includes custody_kind
  # (§6.2 — see AnalyticsBi::Lens::FamilyGraph's own guarantee). The sibling
  # decline alert (AnalyticsBi::Lens::SiblingBondAlert) is a school-wide signal,
  # not scoped to this one student's siblings — it is AUDITED every time it
  # actually has something to show (never on a plain graph view with no alert).
  class FamilyCoresController < ApplicationController
    def show
      authorize!("hps.family.view")
      @student = find_student
      @graph = AnalyticsBi::Lens::FamilyGraph.for(student: @student)
      @alerts = relevant_alerts
      audit_alert_view if @alerts.any?
    end

    private

    # The family core's own "id" IS the student's id — there is one family
    # core per student, so `show` is keyed on it directly
    # (analytics_bi_family_core_path(student)), same as spatial_classrooms
    # keys :show on the section id (Slice 2).
    def find_student
      student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if student.nil?

      student
    end

    # Only the alert entries that involve THIS student (a school-wide signal,
    # narrowed to what's relevant on this student's own family page — never a
    # roster of every family in crisis, which would itself be a person search
    # in disguise, §1.1.6).
    def relevant_alerts
      AnalyticsBi::Lens::SiblingBondAlert.for(institution: Current.institution)
        .select { |alert| alert.students.any? { |s| s.id == @student.id } }
    end

    def audit_alert_view
      IdentityAccess::Audit.log(
        institution: Current.institution, action: "family_core.sibling_alert_viewed",
        actor_institution_user: Current.institution_user, target: @student,
        metadata: { student_id: @student.id }
      )
    end
  end
end
