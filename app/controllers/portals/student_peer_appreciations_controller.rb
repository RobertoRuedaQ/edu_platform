module Portals
  # The student peer-appreciation-GIVING surface (BI_DOCUMENT.md §5.4 — deferred
  # from Slice 5 to here). SELF-SERVICE identity action, no authorize! and no
  # RBAC: the giver is Core::Access::StudentSelfScope, the recipient is resolved
  # through AnalyticsBi::SectionClassmatesScope (a CLOSED roster of the giver's
  # own current section co-members, §1.1.6 — never a person search), the tag is
  # from the CLOSED PeerAppreciationTag.active catalog (§5.4 resguardo #1). The
  # consent gate + anti-duplicate + threshold all live in
  # AnalyticsBi::Character::PeerAppreciationRecorder (Slice 5, not touched) — its
  # ConsentRequired / TagUnavailable are rescued into a friendly flash, never a
  # 500 (same posture as AnalyticsBi::CharacterEvaluationsController).
  #
  # DEFERRED (documented, honest): the GUARDIAN-as-giver UI (giver_kind
  # "guardian", a guardian recognizing a non-own student). The model + Recorder
  # already support it and it is tested at the model level (Slice 5), but a real
  # UI raises its own person-search/scope question (which non-own students may a
  # guardian even see?) that this slice's scope does not resolve — so no scope is
  # invented for it under time pressure. Same posture as Slice 5 deferring the
  # guardian-giving controller entirely.
  class StudentPeerAppreciationsController < ApplicationController
    layout "portal"

    def new
      @portal_label = "Portal del estudiante"
      @portal_person_name = Current.user.name
      @student = Core::Access::StudentSelfScope.for(Current.user)
      return redirect_missing_student if @student.nil?

      @classmates = AnalyticsBi::SectionClassmatesScope.new.for(@student)
      @tags = AnalyticsBi::PeerAppreciationTag.active
        .where(institution_id: Current.institution_id).order(:label)
    end

    def create
      @student = Core::Access::StudentSelfScope.for(Current.user)
      return redirect_missing_student if @student.nil?

      term = active_term
      return give_error("No hay un término académico activo.") if term.nil?

      record_appreciation(term)
      redirect_to new_portal_student_peer_appreciation_path, notice: "Reconocimiento enviado. ¡Gracias!"
    rescue AnalyticsBi::Character::PeerAppreciationRecorder::ConsentRequired
      give_error("El reconocimiento necesita el consentimiento del acudiente (el tuyo o el de tu compañero).")
    rescue AnalyticsBi::Character::PeerAppreciationRecorder::TagUnavailable
      give_error("Esa etiqueta ya no está disponible.")
    rescue ActiveRecord::RecordNotFound
      give_error("Elige un compañero de tu grupo y una etiqueta válida.")
    end

    private

    # Recipient + tag are resolved through SCOPED reads (co-section + active
    # catalog), never trusted raw from params — a non-section-mate or an inactive
    # tag simply raises RecordNotFound and is rescued cleanly (§1.1.6).
    def record_appreciation(term)
      recipient = AnalyticsBi::SectionClassmatesScope.new.for(@student).find(params[:recipient_student_id])
      tag = AnalyticsBi::PeerAppreciationTag.active
        .find_by!(institution_id: Current.institution_id, id: params[:tag_id])
      AnalyticsBi::Character::PeerAppreciationRecorder.call(
        student: recipient, tag: tag, academic_term: term,
        giver_student: @student, institution: Current.institution
      )
    end

    def active_term
      Core::AcademicTerm.active.where(institution_id: Current.institution_id).first
    end

    def redirect_missing_student
      redirect_to portal_student_path, alert: "Tu cuenta aún no está vinculada a un registro de estudiante."
    end

    def give_error(message)
      redirect_to new_portal_student_peer_appreciation_path, alert: message
    end
  end
end
