module Assignments
  # Adds ONE file to an existing Submission — validated in the SERVICE,
  # never a model-level ActiveStorageValidations-style declaration (no new
  # gem; this project's own guardrail). Size is checked BEFORE attaching
  # (skip the disk write entirely for an obviously oversized upload);
  # content-type is checked AFTER attaching, because Active Storage's
  # Marcel-based sniffing (the REAL, magic-byte-detected type — never the
  # filename extension nor the client's declared header) only runs once
  # the blob exists. A rejected attachment is purged immediately — never
  # left as an orphaned blob on disk.
  class AttachmentAdder
    MAX_BYTES = 10.megabytes
    MAX_ATTACHMENTS = 5

    Result = Data.define(:attachment, :error)

    def self.call(submission:, file:, attached_by:)
      new(submission: submission, file: file, attached_by: attached_by).call
    end

    def initialize(submission:, file:, attached_by:)
      @submission = submission
      @file = file
      @attached_by = attached_by
    end

    def call
      return Result.new(attachment: nil, error: :assignment_closed) if submission.assignment.archived?
      return Result.new(attachment: nil, error: :no_file) if file.blank?
      return Result.new(attachment: nil, error: :too_many) if submission.submission_attachments.count >= MAX_ATTACHMENTS
      return Result.new(attachment: nil, error: :too_large) if file.size > MAX_BYTES

      attachment = submission.submission_attachments.create!(institution: submission.institution,
        attached_by: attached_by)
      attachment.file.attach(file)

      unless Assignments::SubmissionAttachment::ALLOWED_CONTENT_TYPES.include?(attachment.file.content_type)
        attachment.file.purge
        attachment.destroy!
        return Result.new(attachment: nil, error: :invalid_type)
      end

      Result.new(attachment: attachment, error: nil)
    end

    private

    attr_reader :submission, :file, :attached_by
  end
end
