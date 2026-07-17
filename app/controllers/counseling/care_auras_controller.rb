module Counseling
  # Lens 5 authoring surface (BI_DOCUMENT.md §5.7, Slice 3). Lives in counseling
  # — the two-sided permission split (§4) puts authoring on the counselor side,
  # where they see the Case/SessionNote that motivates the aura. WRITE is gated
  # by the EXISTING counseling.write ("Registrar notas de orientación") — the
  # same key that gates counseling authorship; no new write key is invented.
  #
  # This controller NEVER writes AnalyticsBi::CareAura directly: publishing goes
  # through AnalyticsBi::Aura::Projector (the single sanctioned cross-domain
  # write seam), retiring through Projector.retire. That keeps counseling from
  # reaching into analytics_bi's internals, and keeps analytics_bi from ever
  # reading counseling's tables. guidance_text is authored by the counselor
  # (zero clinical PII by construction of this workflow).
  class CareAurasController < ApplicationController
    before_action :set_case

    def new
      authorize!("counseling.write", @case)
      @aura_kinds = AnalyticsBi::CareAura::AURA_KINDS
    end

    def create
      authorize!("counseling.write", @case)
      term = active_term
      return redirect_to_case("No hay un término académico activo para fechar el aura.") if term.nil?

      AnalyticsBi::Aura::Projector.call(
        student: @case.student, academic_term: term,
        aura_kind: params[:aura_kind], guidance_text: params[:guidance_text].to_s.strip,
        authored_by: Current.institution_user
      )
      redirect_to_case("Aura de cuidado publicada. El docente verá solo la indicación de trato.")
    rescue ActiveRecord::RecordInvalid => e
      redirect_to_case("No se pudo publicar el aura: #{e.record.errors.full_messages.join(', ')}.")
    end

    def destroy
      authorize!("counseling.write", @case)
      aura = AnalyticsBi::CareAura.find_by(institution_id: Current.institution_id,
        id: params[:id], student_id: @case.student_id)
      raise ActiveRecord::RecordNotFound if aura.nil?

      AnalyticsBi::Aura::Projector.retire(aura: aura)
      redirect_to_case("Aura de cuidado retirada.")
    end

    private

    def set_case
      @case = Counseling::Case.find_by(institution_id: Current.institution_id, id: params[:case_id])
      raise ActiveRecord::RecordNotFound if @case.nil?
    end

    def active_term
      Core::AcademicTerm.active.where(institution_id: Current.institution_id).first
    end

    def redirect_to_case(message)
      redirect_to counseling_case_path(@case), notice: message
    end
  end
end
