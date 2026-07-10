module Core
  module RosterImport
    # Phase 2 (J4): per-row validation + preview. ZERO writes to real tables —
    # only annotates RosterImportRow#status/#message and the batch's summary
    # counters. Kind-AGNOSTIC orchestration (G7): every kind-specific rule
    # (required fields, business errors, what counts as "already exists",
    # what counts as an in-batch collision) comes from Strategy.for(batch.kind,
    # ...) — this file never branches on kind itself.
    #
    # Row statuses (fixed by the real schema's CHECK constraint): "valid"
    # (new — will create), "duplicate" (the strategy's #existing_record?
    # says this row's real counterpart already exists — will update/
    # re-affirm), "collision" (two rows in THIS batch share the same
    # strategy#collision_key — a problem with the file itself), "error"
    # (missing required field or a strategy business_errors failure).
    #
    # A batch can commit with error/collision rows present — those are
    # skipped, not blocking: the valid/duplicate rows still commit, and the
    # report shows both.
    class Validator
      def self.call(batch:)
        new(batch).call
      end

      def initialize(batch)
        @batch = batch
        @strategy = Strategy.for(batch.kind, institution: batch.institution)
      end

      def call
        rows = @batch.roster_import_rows.order(:line_number).to_a
        plains = rows.index_with { |row| Cipher.decrypt_row(row.raw, @strategy.sensitive_fields) }
        collided_keys = duplicated_values(plains.values.map { |plain| @strategy.collision_key(plain) }.compact)

        rows.each { |row| validate_row(row, plains[row], collided_keys) }

        update_summary!(rows)
      end

      private

      def validate_row(row, plain, collided_keys)
        errors = missing_field_errors(plain) + @strategy.business_errors(plain)
        key = @strategy.collision_key(plain)

        if errors.any?
          row.update!(status: "error", message: errors.join("; "))
        elsif key && collided_keys.include?(key)
          row.update!(status: "collision", message: "duplicado dentro del archivo")
        elsif @strategy.existing_record?(plain)
          row.update!(status: "duplicate", message: nil)
        else
          row.update!(status: "valid", message: nil)
        end
      end

      def missing_field_errors(plain)
        @strategy.required_fields.select { |field| plain[field].blank? }.map { |field| "falta #{field}" }
      end

      def duplicated_values(values)
        values.tally.select { |_key, count| count > 1 }.keys
      end

      # rows are the SAME in-memory objects validate_row already called
      # #update! on above — no need to re-fetch, their #status already
      # reflects the write.
      def update_summary!(rows)
        by_status = rows.group_by(&:status)
        summary = @batch.summary.merge(
          "total_rows"      => rows.size,
          "create_count"    => by_status.fetch("valid", []).size,
          "update_count"    => by_status.fetch("duplicate", []).size,
          "error_count"     => by_status.fetch("error", []).size,
          "collision_count" => by_status.fetch("collision", []).size
        )
        @batch.update!(status: "validated", summary: summary)
      end
    end
  end
end
