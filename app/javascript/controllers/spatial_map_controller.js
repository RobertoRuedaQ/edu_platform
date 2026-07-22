import { Controller } from "@hotwired/stimulus"

// Lens 1 dimming toggle (v1.36.0, BI_DOCUMENT.md §10.4). Pure client-side
// emphasis: when the filter is on, seats that do NOT need attention get the
// .seat--dimmed class so the ones that do stand out. Zero round-trips — every
// seat's data-needs-attention is already in the DOM (server-rendered by
// AnalyticsBi::Svg::SeatGrid). No localStorage: UI state that must survive
// belongs in params/session/DB, never here (UX_UI §6).
export default class extends Controller {
  static targets = ["seat", "filter"]

  toggle() {
    const dimStable = this.hasFilterTarget && this.filterTarget.checked
    this.seatTargets.forEach((seat) => {
      const needsAttention = seat.dataset.needsAttention === "true"
      seat.classList.toggle("seat--dimmed", dimStable && !needsAttention)
    })
  }
}
