module AnalyticsBi
  module Character
    # Records a single peer/guardian appreciation with ALL the §5.4 safeguards.
    # The ACT of giving is NOT an RBAC permission (§4) — it's an identity action
    # (co-membership + consent), so this service is the gate, not authorize!.
    #
    # Safeguards enforced here:
    #  1. No free text: the only content is a PeerAppreciationTag (closed
    #     catalog). The tag must be active — an archived/removed tag is rejected.
    #  5. Guardian consent (§5.4 point 5): the RECEIVING student must have active
    #     consent, and a peer_student GIVER must too (a minor giving needs their
    #     own guardian's consent). A guardian giver is an adult — no giver-side
    #     consent needed. Missing consent raises ConsentRequired (a friendly
    #     rejection the future portal controller rescues — never a 500).
    #  2. Anti-duplicate: re-giving the same tag to the same recipient in the
    #     same term is an idempotent no-op (returns the existing active row), so a
    #     resubmit never churns — and the DB partial unique index is the backstop.
    #
    # Aggregation threshold (§5.4 resguardo #2 / decision A3): a tag is only ever
    # SURFACED once it has AGGREGATION_THRESHOLD distinct legitimate
    # contributions. That threshold is read by AnalyticsBi::Character::
    # PeerAppreciationDigest. A single module constant, NOT a per-institution
    # settings table — there is no such tunable table in this codebase and
    # inventing one for a single number is speculative (documented as deferred
    # until a real institution asks; "boring over speculative").
    class PeerAppreciationRecorder
      AGGREGATION_THRESHOLD = 3

      ConsentRequired = Class.new(StandardError)
      TagUnavailable = Class.new(StandardError)

      Result = Data.define(:appreciation, :created)

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(student:, tag:, academic_term:, giver_student: nil, giver_guardian: nil,
                     institution: Current.institution)
        @student = student
        @tag = tag
        @academic_term = academic_term
        @giver_student = giver_student
        @giver_guardian = giver_guardian
        @institution = institution
      end

      def call
        ensure_tag_available!
        ensure_consent!

        # requires_new: true -> SAVEPOINT: a race against the partial unique
        # index rolls back only this unit and re-raises cleanly.
        ActiveRecord::Base.transaction(requires_new: true) do
          existing = existing_active
          next Result.new(appreciation: existing, created: false) if existing

          appreciation = AnalyticsBi::PeerAppreciation.create!(
            institution: institution, student: student, tag: tag,
            academic_term: academic_term, giver_kind: giver_kind,
            giver_student: giver_student, giver_guardian: giver_guardian,
            status: "active"
          )
          Result.new(appreciation: appreciation, created: true)
        end
      end

      private

      attr_reader :student, :tag, :academic_term, :giver_student, :giver_guardian, :institution

      def giver_kind
        giver_student ? "peer_student" : "guardian"
      end

      def ensure_tag_available!
        return if tag&.active?

        raise TagUnavailable, "la etiqueta no está disponible para aportes"
      end

      # The receiving student always needs consent; a peer_student giver needs
      # their own too. A guardian giver is an adult, no giver-side consent.
      def ensure_consent!
        raise ConsentRequired, "el estudiante no tiene consentimiento activo" unless consented?(student)
        return unless giver_student

        raise ConsentRequired, "el par no tiene consentimiento activo" unless consented?(giver_student)
      end

      def consented?(a_student)
        AnalyticsBi::CharacterProgramConsent.active_for?(a_student.id, institution: institution)
      end

      def existing_active
        AnalyticsBi::PeerAppreciation
          .active
          .find_by(institution_id: institution.id, student_id: student.id, tag_id: tag.id,
            academic_term_id: academic_term.id,
            giver_student_id: giver_student&.id, giver_guardian_user_id: giver_guardian&.id)
      end
    end
  end
end
