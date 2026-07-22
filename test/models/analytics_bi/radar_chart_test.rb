require "test_helper"

# Slice 6 (BI_DOCUMENT.md §10.1): the server-rendered radar SVG. Same AA
# discipline as AnalyticsBi::Svg::SeatGrid — meaning never carried by shape/color
# alone. Critically (§1.1.2/§1.1.4): the ordinal drives geometry but is NEVER
# rendered; every readable field is the qualitative level_label + descriptor.
class AnalyticsBi::RadarChartTest < ActiveSupport::TestCase
  def axes
    [
      AnalyticsBi::Lens::CharacterCard::Axis.new(dimension_name: "Empatía", level_label: "Consolidado",
        descriptor: "Acompaña a sus compañeros.", ordinal: 1, levels_count: 3),
      AnalyticsBi::Lens::CharacterCard::Axis.new(dimension_name: "Perseverancia", level_label: "Destacado",
        descriptor: "Sostiene el esfuerzo.", ordinal: 2, levels_count: 3)
    ]
  end

  def render
    AnalyticsBi::Svg::RadarChart.render(axes: axes)
  end

  test "the svg carries a role and a qualitative aria-label" do
    html = render
    assert_match %r{<svg[^>]*role="img"}, html
    assert_match %r{aria-label="[^"]*Empatía, Consolidado}, html
  end

  test "each axis label renders the dimension name plus the qualitative level, never a number" do
    html = render
    assert_match "Empatía: Consolidado", html
    assert_match "Perseverancia: Destacado", html
    assert_no_match(/Empatía:\s*\d/, html, "the ordinal must never render as a score next to the dimension")
  end

  test "a visually-hidden table mirrors every axis in plain qualitative text" do
    html = render
    assert_match %r{<table class="visually-hidden">}, html
    assert_match "Acompaña a sus compañeros.", html
    assert_match "Sostiene el esfuerzo.", html
    assert_match ">Descripción<", html
  end

  test "no readable text node is a bare integer (no score/ordinal leaks to the reader)" do
    html = render
    text_nodes = html.scan(/>([^<]+)</).flatten.map(&:strip).reject(&:empty?)
    bare_integers = text_nodes.select { |node| node.match?(/\A\d+\z/) }
    assert_empty bare_integers, "no visible/accessible text is a bare number: #{bare_integers.inspect}"
  end
end
