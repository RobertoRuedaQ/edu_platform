module IdentityAccess
  # Batch alta admin surface — sibling of PeopleController's individual
  # "crear persona", gated by the SAME people.manage capability (real via
  # P1). Handles both kinds (students since v1.7.0, guardians since this
  # slice) — the controller only threads `kind` through to
  # Core::RosterImportBatch and the per-kind Strategy handles the rest
  # (G7); it never branches on kind itself. Three explicit phases (J4):
  # #create only validates the upload itself (capped, see MAX_ROWS) and
  # enqueues the async parse+validate (full-async hardening,
  # OPEN_PROCESS.md item #1), redirecting to the preview (#show), which
  # shows a pending state until the job lands; #commit enqueues the async
  # apply. No invitations are ever sent from here (J3/J3-bis) — this only
  # creates/updates roster records.
  class RosterImportsController < ApplicationController
    MAX_ROWS = 2_000
    KINDS = %w[students guardians].freeze

    def index
      authorize!("people.manage")
      @batches = Core::RosterImportBatch.where(institution: Current.institution).order(created_at: :desc)
    end

    def new
      authorize!("people.manage")
    end

    def create
      authorize!("people.manage")

      kind = params.dig(:roster_import, :kind).to_s
      unless KINDS.include?(kind)
        @error = "Selecciona un tipo de carga válido."
        return render :new, status: :unprocessable_entity
      end

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
        institution: Current.institution, academic_term: active_term, kind: kind,
        created_by: Current.institution_user, status: "queued", pending_content: content
      )

      # Same convention as #commit below: log at enqueue time, not at
      # completion — no job in this domain logs Audit from inside #perform.
      IdentityAccess::Audit.log(institution: Current.institution, action: "roster_import.parse_enqueued",
        actor_institution_user: Current.institution_user, target: batch)
      Core::RosterImport::ParseAndValidateJob.enqueue_for(batch)

      redirect_to identity_access_roster_import_path(batch)
    end

    def show
      authorize!("people.manage")
      @batch = find_batch
      strategy = Core::RosterImport::Strategy.for(@batch.kind, institution: Current.institution)
      @preview_headers = strategy.preview_headers

      # Preview columns are computed HERE (never in the view) so the masked/
      # decrypted values never leak into a helper that could be reused
      # somewhere unmasked by mistake — the view only ever sees what the
      # strategy decided is safe to show.
      @previews = @batch.roster_import_rows.order(:line_number).map do |row|
        plain = Core::RosterImport::Cipher.decrypt_row(row.raw, strategy.sensitive_fields)
        [ row, strategy.preview_columns(plain) ]
      end
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
