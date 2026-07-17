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
    # NOTE: the aura icon overlay (§5.7, care_auras) is DEFERRED to Slice 3 —
    # this slice builds the spatial map + heat only.
    class SpatialClassroom
      Seat = Data.define(:row, :col, :student, :heat)

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
      end

      def self.for(**kwargs)
        new(**kwargs).build
      end

      def initialize(section:, institution: Current.institution, on: Date.current)
        @section = section
        @institution = institution
        @on = on
      end

      def build
        layout = current_layout
        return Classroom.new(section: section, layout: nil, seats: []) if layout.nil?

        Classroom.new(section: section, layout: layout, seats: seats_for(layout))
      end

      private

      attr_reader :section, :institution, :on

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
        heat = AnalyticsBi::Lens::SpatialHeatmap.for(
          institution: institution, student_ids: assignments.map(&:student_id)
        )
        assignments.map do |assignment|
          Seat.new(row: assignment.row, col: assignment.col, student: assignment.student,
            heat: heat.fetch(assignment.student_id))
        end
      end
    end
  end
end
