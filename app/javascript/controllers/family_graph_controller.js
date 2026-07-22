import { Controller } from "@hotwired/stimulus"

// Lens 4 orbital graph (v1.43.0, BI_DOCUMENT.md §5.6/§10.3/§10.4). PROGRESSIVE
// ENHANCEMENT, same posture as the Lens 3 constellation controller and the SAME
// already-pinned Cytoscape.js (no second JS library introduced for this lens).
// The server renders the whole authorized graph (this one student's guardians +
// detected siblings) as an accessible fallback list; this controller tries to
// upgrade it to an interactive graph. A DYNAMIC import wrapped in try/catch
// means a missing/broken pin never breaks the page — the fallback just stays
// visible.
export default class extends Controller {
  static targets = ["canvas", "fallback"]
  static values = { graph: Object }

  async connect() {
    const elements = this.graphValue.elements || []
    if (elements.length === 0) return // empty state — nothing to enhance

    try {
      const { default: cytoscape } = await import("cytoscape")
      this.renderGraph(cytoscape, elements)
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
        { selector: "node[type='student']", style: { "background-color": "#e35b5b", label: "data(label)", "font-size": "12px", color: "#1f2933" } },
        { selector: "node[type='guardian']", style: { "background-color": "#5b6ee1", label: "data(label)", "font-size": "10px", color: "#1f2933" } },
        { selector: "node[type='sibling']", style: { "background-color": "#f2c14e", label: "data(label)", "font-size": "9px", color: "#1f2933" } },
        { selector: "edge", style: { width: 1, "line-color": "#c9ccd1", "curve-style": "bezier" } }
      ]
    })
  }
}
