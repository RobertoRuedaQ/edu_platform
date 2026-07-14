module Core
  module RosterImport
    # Factory for the per-kind strategy (G7): Parser/Validator/Committer are
    # kind-AGNOSTIC orchestration — they never branch on `kind` themselves,
    # they just delegate to whatever strategy this returns. Adding a new kind
    # means adding a new Strategies:: class here, not editing the three
    # orchestrators.
    module Strategy
      def self.for(kind, institution:)
        case kind.to_s
        when "students"  then Strategies::Students.new(institution: institution)
        when "guardians" then Strategies::Guardians.new(institution: institution)
        else raise ArgumentError, "unknown roster import kind: #{kind}"
        end
      end
    end
  end
end
