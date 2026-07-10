module Core
  module RosterImport
    module Strategies
      # ONE ROW = ONE (guardian, student) RELATIONSHIP (G1) — a guardian with
      # N children is N rows sharing the same guardian_national_id, which is
      # NORMAL, not a collision (unlike students, where a repeated
      # national_id in one file IS a problem). The real in-batch collision
      # here is the SAME (guardian_national_id, student_national_id) PAIR
      # appearing twice — a redundant row.
      #
      # A guardian ALWAYS gets a login identity: unlike students (upserted
      # directly), this goes through Core::People::Resolver, which creates
      # Core::User + an institution_users membership — and crucially NEVER
      # creates any IdentityAccess::RoleAssignment, so a guardian imported
      # here holds zero RBAC grants by construction (G3) — no extra code
      # needed to "avoid" granting staff permissions, Resolver simply never
      # touches that table. The membership is not just "consistent" — recon
      # confirmed SessionsController#authenticate_credentials requires an
      # active institution_users row to authenticate at all, so creating it
      # is what makes the guardian's FUTURE login (post-invitation, a later
      # slice) possible in the first place.
      #
      # "duplicate" row status means the GuardianStudent LINK already
      # exists (not merely that the guardian does) — re-affirms it (G4:
      # additive, updates relationship/reactivates if revoked, never
      # destroys). resolved_record_id points at the LINK's id (the
      # per-row resolved entity), not the guardian's Core::User id.
      class Guardians
        EXPECTED_HEADERS = %w[
          guardian_national_id guardian_first_name guardian_last_name guardian_email
          relationship student_national_id
        ].freeze
        REQUIRED_FIELDS = EXPECTED_HEADERS
        SENSITIVE_FIELDS = %w[guardian_national_id student_national_id].freeze
        # No DB CHECK constrains guardian_students.relationship (confirmed in
        # recon) — this vocabulary is an application-level policy, matching
        # the "padre"/"madre" convention already used by db/seeds.rb, plus a
        # non-parent catch-all and a legal-tutor category.
        VALID_RELATIONSHIPS = %w[padre madre acudiente tutor].freeze
        PREVIEW_HEADERS = [ "Acudiente", "Documento acudiente", "Relación", "Documento estudiante" ].freeze

        def initialize(institution:)
          @institution = institution
        end

        def expected_headers = EXPECTED_HEADERS
        def required_fields = REQUIRED_FIELDS
        def sensitive_fields = SENSITIVE_FIELDS
        def preview_headers = PREVIEW_HEADERS

        def collision_key(plain)
          return nil if plain["guardian_national_id"].blank? || plain["student_national_id"].blank?

          "#{plain['guardian_national_id']}::#{plain['student_national_id']}"
        end

        def business_errors(plain)
          errors = []
          if plain["relationship"].present? && VALID_RELATIONSHIPS.exclude?(plain["relationship"].downcase)
            errors << "relationship debe ser uno de: #{VALID_RELATIONSHIPS.join(', ')}"
          end
          if plain["student_national_id"].present? && existing_student(plain["student_national_id"]).nil?
            errors << "estudiante no encontrado (student_national_id) — importar estudiantes primero"
          end
          errors
        end

        # Maps to the LINK's existence, not merely the guardian's — a
        # brand-new guardian with a brand-new child is "valid" (new link);
        # an existing guardian gaining a new child is ALSO "valid" (still a
        # new link, even though the guardian itself isn't new); only a row
        # re-affirming an ALREADY-linked (guardian, student) pair is
        # "duplicate".
        def existing_record?(plain)
          guardian = existing_guardian(plain["guardian_national_id"])
          student = existing_student(plain["student_national_id"])
          return false if guardian.nil? || student.nil?

          Core::GuardianStudent.exists?(institution_id: @institution.id, guardian_user_id: guardian.id, student_id: student.id)
        end

        # Idempotent (G4): Resolver never duplicates/overwrites an existing
        # Core::User, and the link's find_or_create key is the same real
        # unique index the DB enforces — re-committing the same row twice
        # converges to the same single link, never a duplicate. Additive:
        # relationship/status are only ever brought IN LINE with the CSV
        # (including reactivating a "revoked" link), never removed —
        # a link absent from the CSV is simply never touched.
        def commit_row!(plain)
          resolved = Core::People::Resolver.call(
            email: plain["guardian_email"],
            name: [ plain["guardian_first_name"], plain["guardian_last_name"] ].compact.join(" "),
            national_id: plain["guardian_national_id"], institution: @institution, role: "guardian"
          )
          student = existing_student(plain["student_national_id"])

          link = Core::GuardianStudent.find_or_create_by!(
            institution: @institution, guardian_user_id: resolved.user.id, student_id: student.id
          ) do |l|
            l.relationship = plain["relationship"]
            l.status = "active"
          end

          attrs = {}
          attrs[:relationship] = plain["relationship"] if plain["relationship"].present? && link.relationship != plain["relationship"]
          attrs[:status] = "active" if link.status != "active" # a row's presence only ever re-affirms, never revokes
          link.update!(attrs) if attrs.any?
          link
        end

        def preview_columns(plain)
          [
            [ plain["guardian_first_name"], plain["guardian_last_name"] ].compact.join(" ").presence || "—",
            Cipher.mask(plain["guardian_national_id"]),
            plain["relationship"],
            Cipher.mask(plain["student_national_id"])
          ]
        end

        private

        def existing_guardian(national_id)
          return nil if national_id.blank?

          Core::User.find_by(national_id: national_id)
        end

        def existing_student(national_id)
          return nil if national_id.blank?

          GroupManagement::Student.find_by(institution_id: @institution.id, national_id: national_id)
        end
      end
    end
  end
end
