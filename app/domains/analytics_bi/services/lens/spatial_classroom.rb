module AnalyticsBi
  module Lens
    # Read-model for ONE classroom's Lens 1 view (BI_DOCUMENT.md §9, Slice 2).
    # Composes the current ClassroomLayout, its active seat assignments, and
    # the derived heat (SpatialHeatmap) into the shape the SVG helper
    # (AnalyticsBi::Svg::SeatGrid) and the view consume. Reads the
    # group_management-owned tables with an explicit institution_id filter;
    # persists nothing. The controller resolves + authorizes the section first,
    # then hands it here (one object per controller, Sandi Metz).
    #
    # Lens 5 aura overlay (§5.7, care_auras) is ADDITIVE (Slice 3): pass
    # with_auras: true (the controller does so only when the observer holds
    # hps.aura.view for this section) and each seat gains its abstract aura
    # projections; without it seats.auras is always [] and the grid renders
    # exactly as in Slice 2.
    class SpatialClassroom
      Seat = Data.define(:row, :col, :student, :heat, :auras) do
        def auras? = auras.any?
      end

      Classroom = Data.define(:section, :layout, :seats) do
        def present?
          !layout.nil?
        end

        def rows = layout.rows
        def cols = layout.cols
        def board_orientation = layout.board_orientation
        def aisles = layout.aisles
        def student_count = seats.size
        def needs_attention_count = seats.count { |seat| seat.heat.needs_attention }
        def aura_count = seats.sum { |seat| seat.auras.size }
      end

      def self.for(**kwargs)
        new(**kwargs).build
      end

      def initialize(section:, institution: Current.institution, on: Date.current, with_auras: false)
        @section = section
        @institution = institution
        @on = on
        @with_auras = with_auras
      end

      def build
        layout = current_layout
        return Classroom.new(section: section, layout: nil, seats: []) if layout.nil?

        Classroom.new(section: section, layout: layout, seats: seats_for(layout))
      end

      private

      attr_reader :section, :institution, :on, :with_auras

      def current_layout
        term = Core::AcademicTerm.active.where(institution_id: institution.id).first
        return nil if term.nil?

        GroupManagement::ClassroomLayout
          .where(institution_id: institution.id, section_id: section.id, academic_term_id: term.id)
          .current
          .first
      end

      def seats_for(layout)
        assignments = GroupManagement::SeatAssignment
          .where(institution_id: institution.id, classroom_layout_id: layout.id)
          .effective_on(on)
          .includes(:student)
          .to_a
        student_ids = assignments.map(&:student_id)
        heat = AnalyticsBi::Lens::SpatialHeatmap.for(
          institution: institution, student_ids: student_ids
        )
        auras = auras_for(student_ids)
        assignments.map do |assignment|
          Seat.new(row: assignment.row, col: assignment.col, student: assignment.student,
            heat: heat.fetch(assignment.student_id),
            auras: auras.fetch(assignment.student_id, []))
        end
      end

      # Empty (no care_auras query at all) unless the observer was authorized
      # for hps.aura.view — the controller decides that, this only obeys it.
      def auras_for(student_ids)
        return {} unless with_auras

        AnalyticsBi::Lens::AuraScope.new(
          student_ids: student_ids, institution: institution, on: on
        ).by_student
      end
    end
  end
end
