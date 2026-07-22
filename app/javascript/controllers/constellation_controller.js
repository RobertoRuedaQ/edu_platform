import { Controller } from "@hotwired/stimulus"

// Lens 3 constellation (v1.42.0, BI_DOCUMENT.md §10.3/§10.4). PROGRESSIVE
// ENHANCEMENT: the server renders the whole authorized scope as an accessible
// fallback list (grouped by talent); this controller tries to upgrade it to an
// interactive Cytoscape.js graph with drag/zoom. Cytoscape is loaded with a
// DYNAMIC import inside connect() and wrapped in try/catch, so a missing/broken
// importmap pin never breaks the page — it just leaves the fallback visible.
//
// Zero round-trips (§10.4): the graph data is already in the DOM (graph value,
// server-emitted with only authorized, non-sensitive attributes — initials, not
// names, on the canvas). The search filters the nodes/list client-side; the
// <form> only submits to the server when JS is absent (the no-JS fallback path).
export default class extends Controller {
  static targets = ["canvas", "fallback", "search", "group"]
  static values = { graph: Object }

  async connect() {
    this.enhanced = false
    const elements = this.graphValue.elements || []
    if (elements.length === 0) return // empty state — nothing to enhance

    try {
      const { default: cytoscape } = await import("cytoscape")
      this.renderGraph(cytoscape, elements)
      this.enhanced = true
      if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
      if (this.hasCanvasTarget) this.canvasTarget.hidden = false
    } catch (_error) {
      // Cytoscape unavailable — keep the server-rendered fallback as-is.
    }
  }

  disconnect() {
    if (this.cy) this.cy.destroy()
  }

  renderGraph(cytoscape, elements) {
    this.cy = cytoscape({
      container: this.canvasTarget,
      elements,
      layout: { name: "cose", animate: false },
      style: [
        { selector: "node[type='taxonomy']", style: { "background-color": "#5b6ee1", label: "data(label)", "font-size": "11px", color: "#1f2933" } },
        { selector: "node[type='student']", style: { "background-color": "#f2c14e", label: "data(label)", "font-size": "9px", "text-valign": "center", color: "#1f2933" } },
        { selector: "edge", style: { width: 1, "line-color": "#c9ccd1", "curve-style": "bezier" } },
        { selector: ".dimmed", style: { opacity: 0.12 } }
      ]
    })
  }

  // Client-side narrowing, no round-trip. With the graph up we dim non-matching
  // talents (and students left with no visible talent); otherwise we filter the
  // fallback list in place, so live search works even if Cytoscape didn't load.
  filter() {
    const term = this.searchTarget.value.trim().toLowerCase()
    this.enhanced ? this.filterGraph(term) : this.filterFallback(term)
  }

  // Enter must not round-trip when JS is handling the search live.
  onSubmit(event) {
    event.preventDefault()
    this.filter()
  }

  filterGraph(term) {
    this.cy.elements().removeClass("dimmed")
    if (term === "") return

    const matchedTaxonomy = this.cy.nodes("[type='taxonomy']").filter((n) => !n.data("label").toLowerCase().includes(term))
    matchedTaxonomy.addClass("dimmed")
    const visibleTalents = this.cy.nodes("[type='taxonomy']").not(".dimmed")
    this.cy.nodes("[type='student']").forEach((student) => {
      if (student.connectedEdges().connectedNodes().intersection(visibleTalents).length === 0) student.addClass("dimmed")
    })
  }

  filterFallback(term) {
    this.groupTargets.forEach((group) => {
      const name = (group.dataset.talentName || "").toLowerCase()
      group.hidden = term !== "" && !name.includes(term)
    })
  }
}
