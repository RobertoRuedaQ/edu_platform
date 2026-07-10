require "csv"

module Core
  module RosterImport
    # Phase 1 (J4): CSV (stdlib, no gem) -> raw RosterImportRow per line. Pure
    # structure — no business validation (Validator's job), no writes to real
    # tables besides the raw rows themselves. Unknown extra columns are kept
    # in `raw` but ignored downstream; missing expected columns just become
    # blank values (Validator reports missing-required as a row error, not
    # Parser). national_id is encrypted (Cipher) before it ever reaches the
    # row's jsonb payload — the plaintext CSV value never touches the
    # database (J6). The uploaded io is read once, in memory, and never
    # persisted (see RosterImportBatch's comment on why).
    module Parser
      EXPECTED_HEADERS = %w[
        national_id first_name last_name gender birthdate student_code
        entry_year grade_level section email
      ].freeze

      Result = Data.define(:batch, :row_count)

      # `content` is the ALREADY-READ file body (a String, never a path or an
      # open file handle) — the controller reads the uploaded file into
      # memory and hands it here; nothing about the upload ever touches disk
      # or Active Storage (J6). Strips a leading UTF-8 BOM if Excel/Sheets
      # added one — the single realistic encoding wrinkle for a school's CSV
      # ("bom|utf-8" as a CSV `encoding:` option only works when CSV itself
      # opens the file/IO, not against an already-read String).
      def self.call(batch:, content:)
        institution = batch.institution
        row_count = 0

        content = content.dup.force_encoding(Encoding::UTF_8).delete_prefix("﻿")
        csv = CSV.new(content, headers: true, header_converters: :downcase, skip_blanks: true,
          liberal_parsing: true)

        csv.each do |csv_row|
          row_count += 1
          payload = EXPECTED_HEADERS.index_with { |h| csv_row[h]&.to_s&.strip.presence }
          payload["national_id"] = Cipher.encrypt(payload["national_id"])

          Core::RosterImportRow.create!(
            institution: institution, roster_import_batch: batch,
            line_number: row_count, raw: payload
          )
        end

        batch.update!(status: "uploaded", summary: batch.summary.merge("total_rows" => row_count))
        Result.new(batch: batch, row_count: row_count)
      end
    end
  end
end
