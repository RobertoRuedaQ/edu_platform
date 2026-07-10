module Core
  module RosterImport
    # Phase 2 (J4): per-row validation + preview. ZERO writes to `students` —
    # only annotates RosterImportRow#status/#message and the batch's summary
    # counters. Real row statuses (confirmed against the schema, not the ones
    # originally assumed): "valid" (new — will create), "duplicate" (matches
    # an existing Student by national_id — will update), "collision" (two
    # rows in THIS batch share the same national_id — a problem with the
    # file itself, not with either row alone), "error" (missing required
    # field or an unresolvable grade_level/section reference).
    #
    # A batch can commit with error/collision rows present — those are
    # skipped, not blocking (§4.2 of the prompt's recommended policy): the
    # valid/duplicate rows still commit, and the report shows both.
    class Validator
      REQUIRED_FIELDS = %w[national_id first_name last_name gender birthdate student_code].freeze
      VALID_GENDERS = %w[male female].freeze

      def self.call(batch:)
        new(batch).call
      end

      def initialize(batch)
        @batch = batch
        @institution = batch.institution
      end

      def call
        rows = @batch.roster_import_rows.order(:line_number).to_a
        national_ids = rows.index_with { |row| Cipher.decrypt(row.raw["national_id"]) }
        collided_ids = duplicated_values(national_ids.values.compact)

        rows.each { |row| validate_row(row, national_ids[row], collided_ids) }

        update_summary!(rows)
      end

      private

      def validate_row(row, national_id, collided_ids)
        errors = missing_field_errors(row.raw)
        errors << "gender debe ser \"male\" o \"female\"" if row.raw["gender"].present? && VALID_GENDERS.exclude?(row.raw["gender"])
        errors << "birthdate inválida" if row.raw["birthdate"].present? && parse_date(row.raw["birthdate"]).nil?

        grade_level, grade_level_error = resolve_grade_level(row.raw["grade_level"])
        errors << grade_level_error if grade_level_error
        _section, section_error = resolve_section(row.raw["section"], grade_level)
        errors << section_error if section_error

        if errors.any?
          row.update!(status: "error", message: errors.join("; "))
        elsif national_id && collided_ids.include?(national_id)
          row.update!(status: "collision", message: "national_id duplicado dentro del archivo")
        elsif existing_student(national_id)
          row.update!(status: "duplicate", message: nil)
        else
          row.update!(status: "valid", message: nil)
        end
      end

      def missing_field_errors(raw)
        REQUIRED_FIELDS.select { |field| raw[field].blank? }.map { |field| "falta #{field}" }
      end

      def resolve_grade_level(name)
        return [ nil, nil ] if name.blank?

        grade_level = GroupManagement::GradeLevel.find_by(institution_id: @institution.id, name: name)
        grade_level ? [ grade_level, nil ] : [ nil, "grade_level \"#{name}\" no existe" ]
      end

      def resolve_section(name, grade_level)
        return [ nil, nil ] if name.blank?

        scope = GroupManagement::Section.where(institution_id: @institution.id)
        scope = scope.where(grade_level_id: grade_level.id) if grade_level
        section = scope.find_by(name: name)
        section ? [ section, nil ] : [ nil, "section \"#{name}\" no existe" ]
      end

      def existing_student(national_id)
        return nil if national_id.blank?

        GroupManagement::Student.find_by(institution_id: @institution.id, national_id: national_id)
      end

      def duplicated_values(values)
        values.tally.select { |_id, count| count > 1 }.keys
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
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
