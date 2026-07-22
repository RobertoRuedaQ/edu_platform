module AnalyticsBi
  module Svg
    # Server-rendered SVG seat grid for Lens 1 (BI_DOCUMENT.md §10.1, Slice 2).
    # No charting/JS library — hand-rolled SVG, same discipline as
    # shared/_bar_chart / _line_chart. Each occupied seat carries its heat as a
    # CSS variable (style="--heat: hsl(...)", computed server-side by
    # AnalyticsBi::Lens::SpatialHeatmap) plus data-* attributes the Stimulus
    # controller reads to dim/filter WITHOUT a round-trip. Meaning is never
    # color-alone (AA, UX_UI §7): a "needs attention" seat also gets a "!"
    # marker and an aria-label, and a visually-hidden table mirrors every seat.
    #
    # Zero PII beyond what the observer may already see server-side: only the
    # student's initials render in the SVG; the hidden table uses the full name
    # the observer is already permitted to read on this classroom.
    class SeatGrid
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::OutputSafetyHelper

      SEAT = 60
      GAP = 14
      PAD = 18
      BOARD = 26

      def self.render(**kwargs)
        new(**kwargs).render
      end

      def initialize(classroom:)
        @classroom = classroom
        @rows = classroom.rows
        @cols = classroom.cols
        @orientation = classroom.board_orientation
        @by_cell = classroom.seats.index_by { |seat| [ seat.row, seat.col ] }
      end

      def render
        content_tag(:figure, class: "seat-grid",
          data: { controller: "spatial-map" }) do
          safe_join([ controls, svg, hidden_table ])
        end
      end

      private

      attr_reader :classroom, :rows, :cols, :orientation, :by_cell

      def controls
        content_tag(:label, class: "seat-grid__filter") do
          safe_join([
            tag.input(type: "checkbox", data: { action: "spatial-map#toggle", "spatial-map-target": "filter" }),
            content_tag(:span, "Atenuar a los estables (resaltar quienes necesitan atención)")
          ])
        end
      end

      def svg
        content_tag(:svg, safe_join([ board, cells ]),
          class: "seat-grid__svg", role: "img",
          "aria-label": "Plano del aula #{classroom.section.name}: #{classroom.needs_attention_count} de #{classroom.student_count} estudiantes necesitan atención.",
          "viewBox" => "0 0 #{width} #{height}", "preserveAspectRatio" => "xMidYMid meet")
      end

      def cells
        seats = []
        rows.times do |r|
          cols.times do |c|
            seats << cell(r, c)
          end
        end
        safe_join(seats)
      end

      def cell(row, col)
        seat = by_cell[[ row, col ]]
        return empty_cell(row, col) if seat.nil?

        occupied_cell(seat)
      end

      def empty_cell(row, col)
        x, y = xy(row, col)
        tag.rect(class: "seat seat--empty", x: x, y: y, width: SEAT, height: SEAT, rx: 8)
      end

      def occupied_cell(seat)
        x, y = xy(seat.row, seat.col)
        heat = seat.heat
        content_tag(:g, safe_join([
          tag.rect(class: "seat__pad", x: x, y: y, width: SEAT, height: SEAT, rx: 8),
          content_tag(:text, initials(seat.student), class: "seat__initials",
            x: x + SEAT / 2, y: y + SEAT / 2, "text-anchor" => "middle", "dominant-baseline" => "central"),
          attention_marker(x, y, heat),
          aura_marker(x, y, seat)
        ].compact),
          class: "seat",
          style: "--heat: #{heat.hsl};",
          data: {
            "spatial-map-target": "seat",
            heat: heat.known? ? heat.heat : "unknown",
            "needs-attention": heat.needs_attention
          },
          "aria-label": seat_label(seat))
      end

      def attention_marker(x, y, heat)
        return nil unless heat.needs_attention

        content_tag(:text, "!", class: "seat__flag", x: x + SEAT - 10, y: y + 16, "text-anchor" => "middle")
      end

      # Lens 5 (§5.7, Slice 3): a discrete abstract aura badge over the seat —
      # ONLY the projection (kind label + counselor guidance), NEVER anything
      # clinical. Empty when the observer lacks hps.aura.view (seat.auras == []),
      # so the plain grid is unchanged. AA: never color-alone — the badge is a
      # visible "♥" glyph with an <title> (SVG tooltip) + aria-label carrying
      # the kind + guidance, and the hidden table mirrors it.
      def aura_marker(x, y, seat)
        return nil unless seat.auras?

        content_tag(:g, safe_join([
          content_tag(:title, aura_summary(seat)),
          content_tag(:circle, nil, class: "seat__aura-dot", cx: x + 12, cy: y + 12, r: 9),
          content_tag(:text, "♥", class: "seat__aura-glyph", x: x + 12, y: y + 12,
            "text-anchor" => "middle", "dominant-baseline" => "central")
        ]),
          class: "seat__aura",
          role: "img",
          "aria-label": "Aura de cuidado: #{aura_summary(seat)}")
      end

      def aura_summary(seat)
        seat.auras.map { |aura|
          "#{AnalyticsBi::CareAura.kind_label(aura.kind)} — #{aura.guidance}"
        }.join(" · ")
      end

      def board
        return nil if rows.zero? || cols.zero?

        rect = board_rect
        safe_join([
          tag.rect(class: "seat-grid__board", **rect, rx: 4),
          content_tag(:text, "Tablero", class: "seat-grid__board-label",
            x: rect[:x] + rect[:width] / 2, y: rect[:y] + rect[:height] / 2,
            "text-anchor" => "middle", "dominant-baseline" => "central")
        ])
      end

      # The board band sits on the oriented edge, spanning the grid extent.
      def board_rect
        case orientation
        when 90  then { x: PAD + grid_w + GAP, y: origin_y, width: BOARD, height: grid_h }
        when 180 then { x: origin_x, y: PAD + grid_h + GAP, width: grid_w, height: BOARD }
        when 270 then { x: PAD, y: origin_y, width: BOARD, height: grid_h }
        else          { x: origin_x, y: PAD, width: grid_w, height: BOARD }
        end
      end

      def xy(row, col)
        [ origin_x + col * (SEAT + GAP), origin_y + row * (SEAT + GAP) ]
      end

      def origin_x
        orientation == 270 ? PAD + BOARD + GAP : PAD
      end

      def origin_y
        orientation.zero? ? PAD + BOARD + GAP : PAD
      end

      def grid_w
        cols * SEAT + (cols - 1) * GAP
      end

      def grid_h
        rows * SEAT + (rows - 1) * GAP
      end

      def width
        extra = [ 90, 270 ].include?(orientation) ? BOARD + GAP : 0
        PAD * 2 + grid_w + extra
      end

      def height
        extra = [ 0, 180 ].include?(orientation) ? BOARD + GAP : 0
        PAD * 2 + grid_h + extra
      end

      def initials(student)
        "#{student.first_name.to_s[0]}#{student.last_name.to_s[0]}".upcase
      end

      def seat_label(seat)
        name = "#{seat.student.first_name} #{seat.student.last_name}"
        state = if seat.heat.needs_attention then "necesita atención"
        elsif seat.heat.known? then "estable"
        else "sin datos suficientes"
        end
        "#{name} — #{state}"
      end

      # Non-visual, accessible mirror of every seated student — so the meaning
      # never depends on reading the color. The "Aura de cuidado" column only
      # appears when the observer is authorized (some seat carries an aura), so
      # the plain grid's table is unchanged.
      def hidden_table
        content_tag(:table, class: "visually-hidden") do
          safe_join([
            content_tag(:caption, "Estudiantes por asiento en #{classroom.section.name}"),
            content_tag(:thead, content_tag(:tr, safe_join([
              content_tag(:th, "Estudiante", scope: "col"),
              content_tag(:th, "Estado", scope: "col"),
              (content_tag(:th, "Aura de cuidado", scope: "col") if any_auras?)
            ].compact))),
            content_tag(:tbody, safe_join(classroom.seats.map { |seat|
              content_tag(:tr, safe_join([
                content_tag(:td, "#{seat.student.first_name} #{seat.student.last_name}"),
                content_tag(:td, seat_label(seat).split(" — ").last),
                (content_tag(:td, seat.auras? ? aura_summary(seat) : "—") if any_auras?)
              ].compact))
            }))
          ])
        end
      end

      def any_auras?
        classroom.respond_to?(:aura_count) && classroom.aura_count.positive?
      end
    end
  end
end
