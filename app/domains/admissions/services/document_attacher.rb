module Admissions
  # Adjunta UN documento a una solicitud existente — molde exacto
  # Assignments::AttachmentAdder: tamaño validado ANTES de adjuntar (nunca
  # escribir a disco un archivo obviamente sobredimensionado), content-type
  # real validado DESPUÉS (Marcel solo corre una vez existe el blob); un
  # adjunto rechazado se purga de inmediato, nunca queda huérfano.
  class DocumentAttacher
    MAX_DOCUMENTS = 10

    Result = Data.define(:document, :error)

    def self.call(application:, document_type:, file:, uploaded_by: nil)
      new(application: application, document_type: document_type, file: file, uploaded_by: uploaded_by).call
    end

    def initialize(application:, document_type:, file:, uploaded_by:)
      @application = application
      @document_type = document_type
      @file = file
      @uploaded_by = uploaded_by
    end

    def call
      return Result.new(document: nil, error: :no_file) if file.blank?
      return Result.new(document: nil, error: :no_document_type) if document_type.blank?
      return Result.new(document: nil, error: :too_many) if application.documents.count >= MAX_DOCUMENTS
      return Result.new(document: nil, error: :too_large) if Admissions::DocumentTypeCheck.too_large?(file)

      document = application.documents.create!(institution: application.institution,
        document_type: document_type, uploaded_by: uploaded_by)
      document.file.attach(file)

      error = Admissions::DocumentTypeCheck.reject_if_invalid_type!(document)
      return Result.new(document: nil, error: error) if error

      Result.new(document: document, error: nil)
    end

    private

    attr_reader :application, :document_type, :file, :uploaded_by
  end
end
