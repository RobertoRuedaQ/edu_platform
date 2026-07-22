module AnalyticsBi
  module Svg
    # Server-rendered SVG radar for Lens 2 (BI_DOCUMENT.md §10.1, Slice 6). Same
    # discipline as AnalyticsBi::Svg::SeatGrid — hand-rolled SVG, no charting/JS
    # library, plain PORO. One axis per character dimension; the vertex distance
    # is driven by the level's ORDINAL position (CharacterCard::Axis#ordinal),
    # which is a GEOMETRY input ONLY — it is never emitted as text/number.
    #
    # AA discipline (UX_UI §7, §1.1.2/§1.1.4): meaning is NEVER carried by the
    # polygon shape/color alone. Every axis label is real SVG text carrying the
    # dimension name + the QUALITATIVE level_label (never a number), the <svg>
    # has role="img" + a descriptive aria-label, and a visually-hidden table
    # mirrors every axis's dimension name + level_label + descriptor in plain
    # text. Call only with a non-empty axes list — the empty state (no published
    # evaluation) is a caller concern, rendered as an honest message, never a
    # fake flat shape.
    class RadarChart
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::OutputSafetyHelper

      SIZE = 320
      CENTER = SIZE / 2
      RADIUS = 120
      RINGS = 4

      def self.render(**kwargs) = new(**kwargs).render

      def initialize(axes:, title: "Radar de fortalezas")
        @axes = axes
        @title = title
      end

      def render
        content_tag(:figure, class: "radar-chart") do
          safe_join([ svg, hidden_table ])
        end
      end

      private

      attr_reader :axes, :title

      def svg
        content_tag(:svg, safe_join([ rings, spokes, shape, labels ]),
          class: "radar-chart__svg", role: "img", "aria-label": aria_label,
          "viewBox" => "0 0 #{SIZE} #{SIZE}", "preserveAspectRatio" => "xMidYMid meet")
      end

      def rings
        safe_join((1..RINGS).map do |ring|
          tag.circle(class: "radar-chart__ring", cx: CENTER, cy: CENTER, r: RADIUS * ring / RINGS)
        end)
      end

      def spokes
        safe_join(axes.size.times.map do |index|
          x, y = point(index, 1.0)
          tag.line(class: "radar-chart__spoke", x1: CENTER, y1: CENTER, x2: x, y2: y)
        end)
      end

      def shape
        safe_join([ tag.polygon(class: "radar-chart__area", points: polygon_points), vertices ])
      end

      def polygon_points
        axes.each_with_index.map { |axis, index| point(index, fraction_for(axis)).join(",") }.join(" ")
      end

      def vertices
        safe_join(axes.each_with_index.map do |axis, index|
          x, y = point(index, fraction_for(axis))
          tag.circle(class: "radar-chart__vertex", cx: x, cy: y, r: 4)
        end)
      end

      # Each axis label is the dimension name + the QUALITATIVE level_label —
      # never the ordinal (§1.1.2). Real text so the meaning is readable without
      # color.
      def labels
        safe_join(axes.each_with_index.map do |axis, index|
          x, y = point(index, 1.18)
          content_tag(:text, "#{axis.dimension_name}: #{axis.level_label}", class: "radar-chart__label",
            x: x, y: y, "text-anchor" => anchor(x), "dominant-baseline" => "middle")
        end)
      end

      def hidden_table
        content_tag(:table, class: "visually-hidden") do
          safe_join([ content_tag(:caption, title), table_head, table_body ])
        end
      end

      def table_head
        content_tag(:thead, content_tag(:tr, safe_join([
          content_tag(:th, "Dimensión", scope: "col"),
          content_tag(:th, "Nivel", scope: "col"),
          content_tag(:th, "Descripción", scope: "col")
        ])))
      end

      def table_body
        content_tag(:tbody, safe_join(axes.map do |axis|
          content_tag(:tr, safe_join([
            content_tag(:td, axis.dimension_name),
            content_tag(:td, axis.level_label),
            content_tag(:td, axis.descriptor.to_s)
          ]))
        end))
      end

      def aria_label
        "#{title}: " + axes.map { |axis| "#{axis.dimension_name}, #{axis.level_label}" }.join("; ")
      end

      # Vertex distance from center as a fraction of RADIUS, driven by the
      # ordinal. A single-level dimension maps to the outer ring.
      def fraction_for(axis)
        axis.ordinal.to_f / [ axis.levels_count - 1, 1 ].max
      end

      def point(index, fraction)
        angle = (-90 + index * (360.0 / axes.size)) * Math::PI / 180
        [ CENTER + Math.cos(angle) * RADIUS * fraction, CENTER + Math.sin(angle) * RADIUS * fraction ]
      end

      def anchor(x)
        return "start" if x > CENTER + 1
        return "end" if x < CENTER - 1

        "middle"
      end
    end
  end
end
