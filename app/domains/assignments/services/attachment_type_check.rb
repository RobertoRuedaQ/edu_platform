module Assignments
  # Shared by Assignments::AttachmentAdder (entrega, v1.24.0) and
  # Assignments::MaterialAdder (tarea, v1.25.0) — the one piece of
  # validation genuinely identical between the two: real content-type via
  # Active Storage's Marcel-based detection (never the filename extension,
  # never the client's declared header), and purge-on-reject so a rejected
  # upload never leaves an orphaned blob. Everything else (cap size, owner
  # association, who's allowed to call) differs enough per Adder that
  # sharing it would cost more indirection than it saves.
  module AttachmentTypeCheck
    module_function

    DOCX_CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ALLOWED_CONTENT_TYPES = [
      DOCX_CONTENT_TYPE,
      "application/pdf",
      "image/jpeg",
      "image/png"
    ].freeze

    MAX_BYTES = 10.megabytes

    def too_large?(file)
      file.size > MAX_BYTES
    end

    # attachable: any record with has_one_attached :file, ALREADY attached.
    # Returns nil when the type is allowed, :invalid_type (after purging)
    # otherwise.
    def reject_if_invalid_type!(attachable)
      return nil if ALLOWED_CONTENT_TYPES.include?(attachable.file.content_type)

      attachable.file.purge
      attachable.destroy!
      :invalid_type
    end
  end
end
