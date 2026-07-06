import { Controller } from "@hotwired/stimulus"

// Accessible tabs. Progressive enhancement: the server renders every panel
// visible with in-page-anchor tabs; on connect we collapse to the selected
// panel and add roving-tabindex + arrow-key navigation (WAI-ARIA pattern).
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Activate whichever tab the markup marked selected (defaults to the first).
    const start = Math.max(0, this.tabTargets.findIndex(t => t.getAttribute("aria-selected") === "true"))
    this.activate(start)
  }

  // Click a tab.
  select(event) {
    event.preventDefault()
    this.activate(this.tabTargets.indexOf(event.currentTarget))
  }

  // Left/Right/Home/End move between tabs (roving focus).
  navigate(event) {
    const step = { ArrowRight: 1, ArrowLeft: -1, Home: "first", End: "last" }[event.key]
    if (step === undefined) return
    event.preventDefault()

    const count = this.tabTargets.length
    const current = this.tabTargets.findIndex(t => t.getAttribute("aria-selected") === "true")
    let next
    if (step === "first") next = 0
    else if (step === "last") next = count - 1
    else next = (current + step + count) % count

    this.activate(next)
    this.tabTargets[next].focus()
  }

  activate(index) {
    this.tabTargets.forEach((tab, i) => {
      const selected = i === index
      tab.setAttribute("aria-selected", String(selected))
      tab.tabIndex = selected ? 0 : -1
    })
    this.panelTargets.forEach((panel, i) => { panel.hidden = i !== index })
  }
}
