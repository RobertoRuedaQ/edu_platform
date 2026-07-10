module Core
  module RosterImport
    # Phase 3 (J4): applies a validated batch. Upserts GroupManagement::Student
    # DIRECTLY by national_id — NOT via Core::People::Resolver (P1 recon: that
    # resolver creates Core::User + Core::InstitutionUser, the global LOGIN
    # identity; a K-12 student usually has none, students.user_id is nullable
    # by design, and this slice's own guardrail forbids touching Core::User).
    # The guardians slice (next) is where Resolver actually applies.
    #
    # Additive, never destructive (J2/J9): re-running commit on the same
    # batch (or re-importing the same CSV into a fresh batch) upserts by
    # national_id and never duplicates — the lookup happens AT COMMIT TIME
    # against real students, not from the row's (possibly stale) validated
    # status, so a second run behaves as an update even for a row the
    # validator originally called "valid". A field blank in the CSV never
    # blanks out an existing value on update. Only "valid"/"duplicate" rows
    # are applied; "error"/"collision" rows are skipped and left as-is — the
    # batch still commits, just with those omitted (§4.2's recommended
    # policy). Never invites (J3) — this only ever writes to `students`.
    class Committer
      COMMITTABLE_STATUSES = %w[valid duplicate].freeze

      def self.call(batch:)
        new(batch).call
      end

      def initialize(batch)
        @batch = batch
        @institution = batch.institution
      end

      def call
        rows = @batch.roster_import_rows.where(status: COMMITTABLE_STATUSES).order(:line_number)
        rows.each { |row| commit_row(row) }

        @batch.update!(status: "committed")
      end

      private

      def commit_row(row)
        national_id = Cipher.decrypt(row.raw["national_id"])
        return if national_id.blank? # error/collision rows never reach COMMITTABLE_STATUSES; belt-and-suspenders

        student = GroupManagement::Student.find_by(institution_id: @institution.id, national_id: national_id)
        student = student ? update_student!(student, row.raw) : create_student!(row.raw, national_id)
        row.update!(resolved_record_id: student.id)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        row.update!(status: "error", message: "commit falló: #{e.message}")
      end

      def create_student!(raw, national_id)
        grade_level, section = resolve_references(raw)
        GroupManagement::Student.create!(
          institution: @institution, national_id: national_id,
          first_name: raw["first_name"], last_name: raw["last_name"], gender: raw["gender"],
          birthdate: Date.parse(raw["birthdate"]), student_code: raw["student_code"],
          entry_year: raw["entry_year"].presence&.to_i || Date.current.year,
          grade_level: grade_level, section: section, email: raw["email"]
        )
      end

      # Only overwrites a field when the CSV actually supplied a value —
      # never blanks an existing one out just because a re-import omitted it.
      def update_student!(student, raw)
        grade_level, section = resolve_references(raw)
        attrs = {
          first_name: raw["first_name"], last_name: raw["last_name"], gender: raw["gender"],
          student_code: raw["student_code"], email: raw["email"]
        }.compact_blank
        attrs[:birthdate] = Date.parse(raw["birthdate"]) if raw["birthdate"].present?
        attrs[:grade_level] = grade_level if grade_level
        attrs[:section] = section if section

        student.update!(attrs)
        student
      end

      def resolve_references(raw)
        grade_level = raw["grade_level"].presence &&
          GroupManagement::GradeLevel.find_by(institution_id: @institution.id, name: raw["grade_level"])
        scope = GroupManagement::Section.where(institution_id: @institution.id)
        scope = scope.where(grade_level_id: grade_level.id) if grade_level
        section = raw["section"].presence && scope.find_by(name: raw["section"])
        [ grade_level, section ]
      end
    end
  end
end
