module Core
  module RosterImport
    # Factory for the per-kind strategy (G7): Parser/Validator/Committer are
    # kind-AGNOSTIC orchestration — they never branch on `kind` themselves,
    # they just delegate to whatever strategy this returns. Adding a new kind
    # means adding a new Strategies:: class here, not editing the three
    # orchestrators.
    module Strategy
      # created_by: solo lo usa Guardians (atribuye la invitación batch-invite
      # al staff que subió el archivo, molde Bootstrap::FirstAdmin) — Students
      # nunca lo necesita, así que su rama simplemente lo ignora.
      def self.for(kind, institution:, created_by: nil)
        case kind.to_s
        when "students"  then Strategies::Students.new(institution: institution)
        when "guardians" then Strategies::Guardians.new(institution: institution, created_by: created_by)
        else raise ArgumentError, "unknown roster import kind: #{kind}"
        end
      end
    end
  end
end
