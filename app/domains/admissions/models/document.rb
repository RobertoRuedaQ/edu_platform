module Admissions
  # Bridge table molde exacto Assignments::SubmissionAttachment — RLS
  # ENABLE+FORCE vive SOLO aquí, nunca en active_storage_*. Servido vía
  # send_data (AttachmentServing concern), nunca rails_blob_path.
  class Document < ApplicationRecord
    self.table_name = "admission_documents"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :application, class_name: "Admissions::Application", inverse_of: :documents
    belongs_to :uploaded_by, class_name: "Core::InstitutionUser",
      foreign_key: :uploaded_by_institution_user_id, optional: true
    has_one_attached :file

    # AttachmentServing#send_attachable_file requires this. PDFs/imágenes se
    # previsualizan en el navegador; cualquier otro tipo permitido se fuerza
    # a descarga.
    def disposition
      %w[application/pdf image/jpeg image/png].include?(file.content_type) ? "inline" : "attachment"
    end
  end
end
