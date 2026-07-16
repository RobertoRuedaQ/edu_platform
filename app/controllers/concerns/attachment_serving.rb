# Shared by every controller that serves a file attached to an
# Assignments::SubmissionAttachment (entrega, v1.24.0) or an
# Assignments::Material (tarea, v1.25.0) — both has_one_attached :file +
# #disposition — AFTER that controller's own scope has already resolved
# which row this actor may reach (StudentView/GuardianScope/roster/RBAC —
# never a bare .find on the model). Streams through the app, never
# rails_blob_path/rails_representation_path (OPEN_PROCESS.md guardrail:
# Active Storage's own tables carry no institution_id/RLS).
module AttachmentServing
  extend ActiveSupport::Concern

  private

  def send_attachable_file(attachable)
    send_data attachable.file.download,
      filename: attachable.file.filename.to_s,
      type: attachable.file.content_type,
      disposition: attachable.disposition
  end

  def attachment_error_message(error)
    case error
    when :assignment_closed then "La tarea está archivada; ya no admite adjuntos."
    when :no_file then "No se recibió ningún archivo."
    when :too_many then "Ya se alcanzó el máximo de archivos permitido."
    when :too_large then "El archivo supera el máximo de 10MB."
    when :invalid_type then "Tipo de archivo no permitido (solo docx, pdf, jpg o png)."
    end
  end
end
