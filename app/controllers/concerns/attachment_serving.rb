# Shared by every controller that serves an Assignments::SubmissionAttachment's
# underlying file, AFTER that controller's own scope has already resolved
# which attachment rows this actor may reach (StudentView/GuardianScope/
# roster — never a bare SubmissionAttachment.find). Streams through the app,
# never rails_blob_path/rails_representation_path (OPEN_PROCESS.md guardrail:
# Active Storage's own tables carry no institution_id/RLS).
module AttachmentServing
  extend ActiveSupport::Concern

  private

  def send_submission_attachment(attachment)
    send_data attachment.file.download,
      filename: attachment.file.filename.to_s,
      type: attachment.file.content_type,
      disposition: attachment.disposition
  end

  def attachment_error_message(error)
    case error
    when :assignment_closed then "La tarea está archivada; ya no admite adjuntos."
    when :no_file then "No se recibió ningún archivo."
    when :too_many then "Ya hay 5 archivos adjuntos, el máximo permitido por entrega."
    when :too_large then "El archivo supera el máximo de 10MB."
    when :invalid_type then "Tipo de archivo no permitido (solo docx, pdf, jpg o png)."
    end
  end
end
