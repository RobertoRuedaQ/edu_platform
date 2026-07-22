module AnalyticsBi
  # T2 write surface (BI_DOCUMENT.md §5.4, Slice 5): a docente/orientador authors
  # and publishes a character evaluation of a student against a published
  # framework. SUPERVISION (molde #4): authorize!("hps.character.author",
  # resource) at the top of every action; the scope reader resolves the student's
  # section (:group) / grade_level, so a group-scoped grant covers the student
  # (CharacterEvaluation#group_id delegates to the student, same as care_aura).
  #
  # DEFERRED (documented): the framework-authoring UI (creating frameworks/
  # dimensions/levels) — seeded via `bin/rails bi:seed_character_starter` for
  # now, real CRUD deferred until a real curation need. The entry point is a
  # student the docente already supervises (student_id in params), NOT a person
  # search (§1.1.6 — sin buscador de personas); the roster link that reaches
  # this is deferred to the Lens surfaces / Slice 6. Peer appreciations are NOT
  # written here (identity action, no RBAC gate — recorded by
  # AnalyticsBi::Character::PeerAppreciationRecorder from the portal in Slice 6).
  class CharacterEvaluationsController < ApplicationController
    before_action :set_student
    before_action :set_framework

    def new
      authorize!("hps.character.author", @student)
    end

    def create
      authorize!("hps.character.author", @student)
      term = active_term
      return redirect_back_with("No hay un término académico activo para fechar la evaluación.") if term.nil?

      AnalyticsBi::Character::Publisher.call(
        framework: @framework, student: @student, academic_term: term,
        author: Current.institution_user, author_kind: author_kind, selections: selections
      )
      redirect_to new_analytics_bi_character_evaluation_path(student_id: @student.id, framework_id: @framework.id),
        notice: "Evaluación de carácter publicada."
    rescue ActiveRecord::RecordInvalid => e
      redirect_back_with("No se pudo publicar la evaluación: #{e.record.errors.full_messages.join(', ')}.")
    rescue AnalyticsBi::Character::Publisher::InvalidSelection => e
      redirect_back_with("Selección inválida: #{e.message}.")
    end

    private

    def set_student
      @student = GroupManagement::Student.find_by(institution_id: Current.institution_id, id: params[:student_id])
      raise ActiveRecord::RecordNotFound if @student.nil?
    end

    def set_framework
      @framework = AnalyticsBi::CharacterFramework.published
        .find_by(institution_id: Current.institution_id, id: params[:framework_id])
      raise ActiveRecord::RecordNotFound if @framework.nil?
    end

    def author_kind
      AnalyticsBi::CharacterEvaluation::AUTHOR_KINDS.include?(params[:author_kind]) ? params[:author_kind] : "teacher"
    end

    # params[:dimensions] => { "<dimension_key>" => { "level_label" => "...", "note" => "..." } }.
    # permit! is safe here: every dimension_key and level_label is re-validated
    # against the FROZEN framework_snapshot in the Publisher (an unknown key or
    # level raises InvalidSelection), so there is no mass-assignment surface —
    # nothing here is assigned to a model attribute directly.
    def selections
      raw = params.fetch(:dimensions, {})
      raw = raw.permit!.to_h if raw.respond_to?(:permit!)
      raw.filter_map do |dimension_key, attrs|
        attrs = attrs.to_h
        label = attrs["level_label"].presence
        next if label.nil?

        { dimension_key: dimension_key.to_s, level_label: label, note: attrs["note"].presence }
      end
    end

    def active_term
      Core::AcademicTerm.active.where(institution_id: Current.institution_id).first
    end

    def redirect_back_with(message)
      redirect_to new_analytics_bi_character_evaluation_path(student_id: @student.id, framework_id: @framework.id),
        alert: message
    end
  end
end
