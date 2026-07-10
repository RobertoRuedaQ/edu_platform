module IdentityAccess
  # Batch alta admin surface for students (RosterImport slice) — sibling of
  # PeopleController's individual "crear persona", gated by the SAME
  # people.manage capability (real via P1). Three explicit phases (J4):
  # #create parses+validates synchronously (capped, see MAX_ROWS) and
  # redirects to the preview (#show); #commit enqueues the async apply. No
  # invitations are ever sent from here (J3) — this only creates/updates
  # roster records.
  class RosterImportsController < ApplicationController
    MAX_ROWS = 2_000

    def index
      authorize!("people.manage")
      @batches = Core::RosterImportBatch.where(institution: Current.institution).order(created_at: :desc)
    end

    def new
      authorize!("people.manage")
    end

    def create
      authorize!("people.manage")

      file = params.dig(:roster_import, :file)
      if file.blank?
        @error = "Selecciona un archivo CSV."
        return render :new, status: :unprocessable_entity
      end

      content = file.read
      if content.each_line.count > MAX_ROWS
        @error = "El archivo supera el máximo de #{MAX_ROWS} filas para procesar en línea."
        return render :new, status: :unprocessable_entity
      end

      active_term = Core::AcademicTerm.active.find_by(institution_id: Current.institution_id)
      if active_term.nil?
        @error = "La institución no tiene un término académico activo."
        return render :new, status: :unprocessable_entity
      end

      batch = Core::RosterImportBatch.create!(
        institution: Current.institution, academic_term: active_term, kind: "students",
        created_by: Current.institution_user
      )
      Core::RosterImport::Parser.call(batch: batch, content: content)
      Core::RosterImport::Validator.call(batch: batch)

      IdentityAccess::Audit.log(institution: Current.institution, action: "roster_import.validated",
        actor_institution_user: Current.institution_user, target: batch, metadata: batch.summary)

      redirect_to identity_access_roster_import_path(batch)
    end

    def show
      authorize!("people.manage")
      @batch = find_batch
      @rows = @batch.roster_import_rows.order(:line_number)
    end

    def commit
      authorize!("people.manage")
      @batch = find_batch

      # Audit BEFORE enqueuing, not after: in test (and any inline queue
      # adapter), .enqueue_for can run the job SYNCHRONOUSLY, and CommitJob's
      # around_perform unconditionally resets the tenant GUC in its `ensure`
      # once it's done — an Audit.log call placed after it would run with no
      # GUC set at all and fail RLS on audit_events, even in this same request.
      IdentityAccess::Audit.log(institution: Current.institution, action: "roster_import.commit_enqueued",
        actor_institution_user: Current.institution_user, target: @batch)
      Core::RosterImport::CommitJob.enqueue_for(@batch)

      redirect_to identity_access_roster_import_path(@batch), notice: "El commit quedó encolado."
    end

    private

    def find_batch
      Core::RosterImportBatch.find_by!(institution: Current.institution, id: params[:id])
    end
  end
end
