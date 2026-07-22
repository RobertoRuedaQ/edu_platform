module AnalyticsBi
  module Lens
    # Assembles the Lens 3 constellation read-model in memory (BI_DOCUMENT.md §7
    # default: in-memory over indexed AR, Slice 7). Given the viewer's authorized
    # taxonomy set (AnalyticsBi::Lens::ConstellationScope), it loads every student
    # who holds one of those talents (transversal al colegio, §1.2) and returns a
    # Graph of nodes + links — the SAME server-renders-everything model as Slice 2:
    # the whole scope ships to the DOM once, the client dims/filters without a
    # round-trip (§10.4).
    #
    # ZERO sensitive data beyond the viewer's authorization: only talent nodes in
    # their scope and the students linked to them (whom a hps.constellation.view
    # holder is already permitted to see). Student graph labels are INITIALS; the
    # full name lives only in the accessible fallback the same authorized viewer
    # reads (same posture as AnalyticsBi::Svg::SeatGrid). Never a ranking (§1.1.3).
    class ConstellationBuilder
      TaxonomyNode = Data.define(:id, :name, :kind, :parent_id) do
        def kind_label = AnalyticsBi::AffinityTaxonomy.kind_label(kind)
      end
      StudentNode = Data.define(:id, :name, :initials, :taxonomy_ids)
      Link = Data.define(:student_id, :taxonomy_id, :source, :context)

      # In-memory graph. `student_nodes_for` / `taxonomy_nodes_present` drive the
      # accessible fallback; `cytoscape_elements` is the (non-sensitive) payload
      # the Stimulus controller feeds to Cytoscape.
      Graph = Data.define(:taxonomy_nodes, :student_nodes, :links) do
        def any? = student_nodes.any?
        def student_count = student_nodes.size
        def taxonomy_count = taxonomy_nodes.size

        def student_nodes_for(taxonomy_id)
          ids = links.select { |l| l.taxonomy_id == taxonomy_id }.map(&:student_id)
          student_nodes.select { |s| ids.include?(s.id) }
        end

        # Only nodes that actually have a linked student — the fallback and the
        # graph both show the constellation, not the empty catalog.
        def taxonomy_nodes_present
          linked = links.map(&:taxonomy_id).to_set
          taxonomy_nodes.select { |node| linked.include?(node.id) }
        end

        def cytoscape_elements
          taxonomy_elements + student_elements + link_elements
        end

        private

        def taxonomy_elements
          taxonomy_nodes_present.map do |node|
            { data: { id: "t-#{node.id}", type: "taxonomy", label: node.name, kind: node.kind } }
          end
        end

        def student_elements
          student_nodes.map do |node|
            { data: { id: "s-#{node.id}", type: "student", label: node.initials, name: node.name } }
          end
        end

        def link_elements
          links.map do |link|
            { data: { id: "e-#{link.student_id}-#{link.taxonomy_id}",
                      source: "s-#{link.student_id}", target: "t-#{link.taxonomy_id}" } }
          end
        end
      end

      def self.for(context:, institution: Current.institution)
        new(context: context, institution: institution).build
      end

      def initialize(context:, institution:)
        @context = context
        @institution = institution
      end

      def build
        nodes = taxonomy_nodes
        affinities = affinities_for(nodes.map(&:id))
        Graph.new(taxonomy_nodes: nodes, student_nodes: student_nodes(affinities),
          links: links(affinities))
      end

      private

      attr_reader :context, :institution

      def taxonomy_nodes
        ConstellationScope.new(context: context, institution: institution).resolve
          .order(:kind, :name)
          .map { |n| TaxonomyNode.new(id: n.id, name: n.name, kind: n.kind, parent_id: n.parent_id) }
      end

      # One query, scoped to the visible talents, feeds BOTH links and student
      # nodes — no second broad load, no N+1 (student is eager-loaded).
      def affinities_for(taxonomy_ids)
        return AnalyticsBi::StudentAffinity.none if taxonomy_ids.empty?

        AnalyticsBi::StudentAffinity
          .where(institution_id: institution.id, taxonomy_id: taxonomy_ids)
          .includes(:student)
      end

      def links(affinities)
        affinities.map do |a|
          Link.new(student_id: a.student_id, taxonomy_id: a.taxonomy_id, source: a.source, context: a.context)
        end
      end

      def student_nodes(affinities)
        affinities.group_by(&:student).sort_by { |student, _| [ student.last_name.to_s, student.first_name.to_s ] }
          .map { |student, links| student_node(student, links) }
      end

      def student_node(student, student_affinities)
        StudentNode.new(id: student.id, name: full_name(student), initials: initials(student),
          taxonomy_ids: student_affinities.map(&:taxonomy_id).uniq)
      end

      def full_name(student)
        "#{student.first_name} #{student.last_name}".strip
      end

      def initials(student)
        "#{student.first_name.to_s[0]}#{student.last_name.to_s[0]}".upcase
      end
    end
  end
end
