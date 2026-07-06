import { Controller } from "@hotwired/stimulus"

// Modal built on the native <dialog> element (free focus-trap + Esc + backdrop).
// Markup:
//   <div data-controller="dialog">
//     <button data-action="dialog#open">Abrir</button>
//     <dialog data-dialog-target="dialog" data-action="click->dialog#clickOutside">
//       …<button data-action="dialog#close">Cerrar</button>
//     </dialog>
//   </div>
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Native <dialog> backdrop clicks land on the dialog element itself.
  clickOutside(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
