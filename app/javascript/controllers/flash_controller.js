import { Controller } from "@hotwired/stimulus"

// Flash notice: auto-dismiss after a delay and close on demand.
// Markup: <div data-controller="flash" data-flash-dismiss-after-value="6000">
//           …<button data-action="flash#dismiss">…
export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 0 } }

  connect() {
    if (this.dismissAfterValue > 0) {
      this.timer = setTimeout(() => this.dismiss(), this.dismissAfterValue)
    }
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    clearTimeout(this.timer)
    this.element.classList.add("flash--leaving")
    // Remove after the fade-out; fire immediately if motion is reduced.
    const done = () => this.element.remove()
    this.element.addEventListener("transitionend", done, { once: true })
    setTimeout(done, 300) // fallback when no transition runs
  }
}
