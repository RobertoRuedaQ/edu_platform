module AnalyticsBi
  module Lens
    # Assembles the Lens 4 orbital graph in memory (BI_DOCUMENT.md §5.6, §7
    # default). The student sits at the center; guardians orbit by
    # is_primary_caregiver (closer orbit = primary); siblings (detected via
    # AnalyticsBi::Lens::FamilyCoreScope, no new table) sit alongside as their
    # own linked nodes.
    #
    # SEGREGATION (§6.2): custody_kind NEVER appears in this graph's payload —
    # not in the Data objects, not in cytoscape_elements. It is genuinely absent
    # from this class's output, not merely unused; a caller who needs it must
    # go to AnalyticsBi::GuardianRelationship directly (an explicit, separate
    # read, never bundled into the graph an orientador/directivo browses).
    #
    # "Tensión del vínculo" (AnalyticsBi::Lens::BondTension) rides on each
    # guardian node as a QUALITATIVE label only (Result#label) — the raw
    # engagement/tension float is an internal input, never rendered (same
    # discipline as CharacterCard's ordinal-never-shown rule, v1.40.0).
    class FamilyGraph
      GuardianNode = Data.define(:id, :name, :relationship_label, :is_primary_caregiver, :tension_label)
      SiblingNode = Data.define(:id, :name, :initials)

      Graph = Data.define(:student_name, :student_initials, :guardians, :siblings) do
        def any? = guardians.any? || siblings.any?

        # The student sits at the CENTER (§5.6), connected to every guardian
        # orbit and every detected sibling — never isolated nodes floating with
        # no relation to the person the page is about.
        def cytoscape_elements
          [ center_element ] + guardian_elements + sibling_elements + edge_elements
        end

        private

        def center_element
          { data: { id: "center", type: "student", label: student_initials, name: student_name } }
        end

        def guardian_elements
          guardians.map do |g|
            { data: { id: "g-#{g.id}", type: "guardian", label: g.name,
                      primary: g.is_primary_caregiver, tension: g.tension_label } }
          end
        end

        def sibling_elements
          siblings.map { |s| { data: { id: "sib-#{s.id}", type: "sibling", label: s.initials, name: s.name } } }
        end

        def edge_elements
          guardian_edges = guardians.map { |g| edge("center", "g-#{g.id}") }
          sibling_edges = siblings.map { |s| edge("center", "sib-#{s.id}") }
          guardian_edges + sibling_edges
        end

        def edge(source, target)
          { data: { id: "e-#{source}-#{target}", source: source, target: target } }
        end
      end

      def self.for(student:, institution: Current.institution)
        new(student: student, institution: institution).build
      end

      def initialize(student:, institution:)
        @student = student
        @institution = institution
        @scope = FamilyCoreScope.new(institution: institution)
      end

      def build
        Graph.new(student_name: full_name(student), student_initials: initials(student),
          guardians: guardian_nodes, siblings: sibling_nodes)
      end

      private

      attr_reader :student, :institution, :scope

      def guardian_nodes
        scope.guardians_for(student).map do |relationship|
          GuardianNode.new(
            id: relationship.guardian_student_id,
            name: full_name(relationship.guardian),
            relationship_label: AnalyticsBi::GuardianRelationship.relationship_label(relationship.relationship_kind),
            is_primary_caregiver: relationship.is_primary_caregiver,
            tension_label: tension_label_for(relationship.guardian.id)
          )
        end
      end

      def sibling_nodes
        scope.siblings_for(student).map { |sibling| SiblingNode.new(id: sibling.id, name: full_name(sibling), initials: initials(sibling)) }
      end

      def tension_label_for(guardian_user_id)
        BondTension.for(guardian_user_id: guardian_user_id, institution: institution).label
      end

      # Guardians (Core::User) carry a single `name`; students carry
      # first_name/last_name — this graph mixes both kinds of node, so the
      # name reader has to handle either shape.
      def full_name(person)
        return person.name if person.respond_to?(:name)

        "#{person.first_name} #{person.last_name}".strip
      end

      def initials(student)
        "#{student.first_name.to_s[0]}#{student.last_name.to_s[0]}".upcase
      end
    end
  end
end
