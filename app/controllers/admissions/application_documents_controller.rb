module Admissions
  # Adjunta un documento a una solicitud existente — molde
  # Portals::StudentAttachmentsController#create (write action against an
  # existing parent record) + Assignments::AttachmentAdder's validation
  # order (vía Admissions::DocumentAttacher).
  class ApplicationDocumentsController < ApplicationController
    include AttachmentServing

    def show
      authorize!("admissions.applications.manage")
      document = Admissions::Document.joins(:application)
        .where(institution_id: Current.institution_id, admission_applications: { id: params[:application_id] })
        .find(params[:id])

      send_attachable_file(document)
    end

    def create
      authorize!("admissions.intake")
      application = Admissions::Application.find_by!(institution_id: Current.institution_id,
        id: params[:application_id])

      result = Admissions::DocumentAttacher.call(application: application, document_type: params[:document_type],
        file: params[:file], uploaded_by: Current.institution_user)

      if result.document
        redirect_to admissions_application_path(application), notice: "Documento adjuntado."
      else
        redirect_to admissions_application_path(application), alert: document_error_message(result.error)
      end
    end

    private

    def document_error_message(error)
      {
        no_file: "Selecciona un archivo.",
        no_document_type: "Indica el tipo de documento.",
        too_many: "Ya se alcanzó el máximo de documentos para esta solicitud.",
        too_large: "El archivo supera el tamaño máximo permitido.",
        invalid_type: "Tipo de archivo no permitido (solo PDF, JPG o PNG)."
      }.fetch(error, "No se pudo adjuntar el documento.")
    end
  end
end
