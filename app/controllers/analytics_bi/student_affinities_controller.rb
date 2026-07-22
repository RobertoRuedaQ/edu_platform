module AnalyticsBi
  # The MINIMAL teacher-observed authoring path for Lens 3 (BI_DOCUMENT.md §6,
  # Slice 7): a docente/orientador tags a supervised student with a talent from
  # the CLOSED taxonomy (§1.1.6 — never free text, never a person search: the
  # entry point is a student_id the author already supervises). SUPERVISION
  # (molde #4): authorize!("hps.affinity.author", @student) at the top of every
  # action; the scope reader resolves the student's section (:group), so a
  # group-scoped grant covers the student (StudentAffinity#group_id delegates to
  # the student, same as character_evaluations).
  #
  # DEFERRED (documented, §6): guardian_reported / self_reported authoring UI —
  # portal surfaces, a future slice's job, exactly as Lens 2's portal was deferred
  # from Slice 5. Only `teacher_observed` gets a write path here, so the data
  # model has one real, reachable source value. A dedicated write key
  # hps.affinity.author (mirroring hps.character.author) keeps read (view) and
  # write (author) separate — the house discipline the Lens-1 tests rely on.
  class StudentAffinitiesController < ApplicationController
    before_action :set_student

    def new
      authorize!("hps.affinity.author", @student)
      @taxonomies = active_taxonomies
    end

    def create
      authorize!("hps.affinity.author", @student)
      term = active_term
      return redirect_new("No hay un término académico activo para fechar la afinidad.") if term.nil?

      AnalyticsBi::StudentAffinity.create!(
        institution_id: Current.institution_id, student: @student, taxonomy: taxonomy,
        academic_term: term, source: "teacher_observed", context: affinity_context
      )
      redirect_to new_analytics_bi_student_affinity_path(student_id: @student.id),
        notice: "Afinidad registrada."
    rescue ActiveRecord::RecordNotUnique
      redirect_new("Ese talento ya estaba registrado para este estudiante en el término activo.")
    rescue ActiveRecord::RecordInvalid => e
      redirect_new("No se pudo registrar la afinidad: #{e.record.errors.full_messages.join(', ')}.")
    end

    private

    def set_student
      @student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
      raise ActiveRecord::RecordNotFound if @student.nil?
    end

    # The talent must be a real, active node in THIS institution (institution-
    # scoped find — a foreign or unknown id 404s, never a cross-tenant write).
    def taxonomy
      node = AnalyticsBi::AffinityTaxonomy.active
        .find_by(institution_id: Current.institution_id, id: params[:taxonomy_id])
      raise ActiveRecord::RecordNotFound if node.nil?

      node
    end

    def affinity_context
      AnalyticsBi::StudentAffinity::CONTEXTS.include?(params[:context]) ? params[:context] : "in_school"
    end

    def active_taxonomies
      AnalyticsBi::AffinityTaxonomy.where(institution_id: Current.institution_id).active.order(:kind, :name)
    end

    def active_term
      Core::AcademicTerm.active.where(institution_id: Current.institution_id).first
    end

    def redirect_new(message)
      redirect_to new_analytics_bi_student_affinity_path(student_id: @student.id), alert: message
    end
  end
end
