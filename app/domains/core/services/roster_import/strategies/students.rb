module Core
  module RosterImport
    module Strategies
      # Extracted from the original hardcoded Parser/Validator/Committer
      # (v1.7.0) WITHOUT changing behavior — see committer_test.rb/
      # validator_test.rb/parser_test.rb, unedited, still green. Upserts
      # GroupManagement::Student DIRECTLY by national_id — NOT via
      # Core::People::Resolver (that resolver creates Core::User, the
      # global LOGIN identity; a K-12 student usually has none).
      class Students
        EXPECTED_HEADERS = %w[
          national_id first_name last_name gender birthdate student_code
          entry_year grade_level section email
        ].freeze
        REQUIRED_FIELDS = %w[national_id first_name last_name gender birthdate student_code].freeze
        SENSITIVE_FIELDS = %w[national_id].freeze
        VALID_GENDERS = %w[male female].freeze
        PREVIEW_HEADERS = %w[Nombre Documento].freeze

        def initialize(institution:)
          @institution = institution
        end

        def expected_headers = EXPECTED_HEADERS
        def required_fields = REQUIRED_FIELDS
        def sensitive_fields = SENSITIVE_FIELDS
        def preview_headers = PREVIEW_HEADERS

        def collision_key(plain) = plain["national_id"]

        def business_errors(plain)
          errors = []
          errors << "gender debe ser \"male\" o \"female\"" if plain["gender"].present? && VALID_GENDERS.exclude?(plain["gender"])
          errors << "birthdate inválida" if plain["birthdate"].present? && parse_date(plain["birthdate"]).nil?

          grade_level, grade_level_error = resolve_grade_level(plain["grade_level"])
          errors << grade_level_error if grade_level_error
          _section, section_error = resolve_section(plain["section"], grade_level)
          errors << section_error if section_error
          errors
        end

        def existing_record?(plain)
          existing_student(plain["national_id"]).present?
        end

        # Idempotent (J9): resolves against real students AT COMMIT TIME, not
        # from the row's (possibly stale) validated status — a second commit
        # of the same batch behaves as an update even for a row the validator
        # originally called "valid". Additive: a blank CSV field never blanks
        # an existing value on update.
        def commit_row!(plain)
          national_id = plain["national_id"]
          student = existing_student(national_id)
          student ? update_student!(student, plain) : create_student!(plain, national_id)
        end

        def preview_columns(plain)
          [
            [ plain["first_name"], plain["last_name"] ].compact.join(" ").presence || "—",
            Cipher.mask(plain["national_id"])
          ]
        end

        private

        def create_student!(plain, national_id)
          grade_level, section = resolve_references(plain)
          GroupManagement::Student.create!(
            institution: @institution, national_id: national_id,
            first_name: plain["first_name"], last_name: plain["last_name"], gender: plain["gender"],
            birthdate: Date.parse(plain["birthdate"]), student_code: plain["student_code"],
            entry_year: plain["entry_year"].presence&.to_i || Date.current.year,
            grade_level: grade_level, section: section, email: plain["email"]
          )
        end

        def update_student!(student, plain)
          grade_level, section = resolve_references(plain)
          attrs = {
            first_name: plain["first_name"], last_name: plain["last_name"], gender: plain["gender"],
            student_code: plain["student_code"], email: plain["email"]
          }.compact_blank
          attrs[:birthdate] = Date.parse(plain["birthdate"]) if plain["birthdate"].present?
          attrs[:grade_level] = grade_level if grade_level
          attrs[:section] = section if section

          student.update!(attrs)
          student
        end

        def resolve_references(plain)
          grade_level = plain["grade_level"].presence &&
            GroupManagement::GradeLevel.find_by(institution_id: @institution.id, name: plain["grade_level"])
          scope = GroupManagement::Section.where(institution_id: @institution.id)
          scope = scope.where(grade_level_id: grade_level.id) if grade_level
          section = plain["section"].presence && scope.find_by(name: plain["section"])
          [ grade_level, section ]
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

        def parse_date(value)
          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
