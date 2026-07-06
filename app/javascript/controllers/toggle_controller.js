import { Controller } from "@hotwired/stimulus"

// Disclosure / dropdown menu. Progressive enhancement: without JS the panel
// stays visible; on connect we collapse it and drive aria-expanded.
// Markup:
//   <div data-controller="toggle"
//        data-action="click@window->toggle#hide keydown.esc@window->toggle#hide">
//     <button data-toggle-target="button" data-action="toggle#toggle" aria-expanded="false">Menú</button>
//     <div data-toggle-target="panel">…</div>
//   </div>
export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    this.close()
  }

  toggle() {
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    this.buttonTarget?.setAttribute("aria-expanded", "true")
  }

  close() {
    this.panelTarget.hidden = true
    this.buttonTarget?.setAttribute("aria-expanded", "false")
  }

  // Bound to window: close when interacting outside this controller's element.
  hide(event) {
    if (event.type === "keydown" || !this.element.contains(event.target)) {
      this.close()
    }
  }
}
