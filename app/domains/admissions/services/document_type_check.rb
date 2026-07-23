module Admissions
  # Molde Assignments::AttachmentTypeCheck — real content-type vía Active
  # Storage/Marcel (nunca la extensión del archivo ni el header declarado
  # por el cliente), purge-on-reject. Copia propia deliberada (no una
  # dependencia cross-domain hacia app/domains/assignments) — cada dominio
  # replica esta forma compartida, molde ya establecido en este codebase.
  module DocumentTypeCheck
    module_function

    ALLOWED_CONTENT_TYPES = [
      "application/pdf",
      "image/jpeg",
      "image/png"
    ].freeze

    MAX_BYTES = 10.megabytes

    def too_large?(file)
      file.size > MAX_BYTES
    end

    def reject_if_invalid_type!(attachable)
      return nil if ALLOWED_CONTENT_TYPES.include?(attachable.file.content_type)

      attachable.file.purge
      attachable.destroy!
      :invalid_type
    end
  end
end
