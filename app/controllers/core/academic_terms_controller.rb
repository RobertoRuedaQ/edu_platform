module Core
  # The FIRST staff-facing surface for Core::AcademicTerm (guidelines/
  # CLOSURE_PLAN.md §4.2). Until now a term only ever existed via
  # db/seeds.rb/console — zero UI to create one, activate it, or close it.
  # ONE unified permission (academic_terms.manage) covers create/edit/
  # activate/close, same criterion as attendance.record/assignment.manage —
  # no confidentiality split applies here.
  #
  # "Cerrar término" is ALSO the manual trigger for
  # AnalyticsBi::HpsTermSnapshotJob (BI_DOCUMENT.md §7/Slice 4) — the owner's
  # confirmed choice over a scheduled/cron trigger (end-of-term is
  # data-dependent, not clock-driven, molde report_card.publish).
  class AcademicTermsController < ApplicationController
    def index
      authorize!("academic_terms.manage")
      @terms = Core::AcademicTerm.where(institution_id: Current.institution_id).order(starts_on: :desc)
    end

    def new
      authorize!("academic_terms.manage")
      @term = Core::AcademicTerm.new
    end

    def create
      authorize!("academic_terms.manage")
      @term = Core::AcademicTerm.new(term_params.merge(institution_id: Current.institution_id, status: "upcoming"))
      if @term.save
        redirect_to core_academic_terms_path, notice: "Término creado."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize!("academic_terms.manage")
      @term = find_term
    end

    def update
      authorize!("academic_terms.manage")
      @term = find_term
      if @term.update(term_params)
        redirect_to core_academic_terms_path, notice: "Término actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # upcoming -> active. The DB enforces "at most one active term per
    # institution" (index_academic_terms_one_active_per_institution) — this
    # action does NOT auto-close whatever term is currently active (an
    # implicit side effect would be surprising); the staff member closes the
    # old term first, then activates the new one, two explicit steps.
    # requires_new: true -> a SAVEPOINT, so the unique-violation rescue below
    # doesn't poison the request's own transaction (TenantScoped's
    # around_action) — same posture as SeatAssigner/SectionReassigner.
    def activate
      authorize!("academic_terms.manage")
      @term = find_term
      ActiveRecord::Base.transaction(requires_new: true) { @term.update!(status: "active") }
      redirect_to core_academic_terms_path, notice: "Término activado."
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid
      redirect_to core_academic_terms_path, alert: "Ya hay un término activo en esta institución — ciérralo primero."
    end

    # active -> closed, AND enqueues the HPS term snapshot for THIS term
    # explicitly (never relying on Core::AcademicTerm.active resolving it
    # later, since by the time the job runs this term is already closed).
    # Same transaction as the status flip: if the enqueue fails, the term
    # stays open rather than silently closing with no snapshot ever queued.
    def close
      authorize!("academic_terms.manage")
      @term = find_term
      ActiveRecord::Base.transaction(requires_new: true) do
        @term.update!(status: "closed")
        AnalyticsBi::HpsTermSnapshotJob.enqueue_for(Current.institution, academic_term: @term)
      end
      redirect_to core_academic_terms_path, notice: "Término cerrado — snapshot del HPS encolado."
    end

    private

    def find_term
      term = Core::AcademicTerm.find_by(institution_id: Current.institution_id, id: params[:id])
      raise ActiveRecord::RecordNotFound if term.nil?

      term
    end

    def term_params
      params.require(:academic_term).permit(:code, :name, :starts_on, :ends_on)
    end
  end
end
