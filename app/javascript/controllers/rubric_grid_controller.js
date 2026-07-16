import { Controller } from "@hotwired/stimulus"

// Live score preview for a rubric grading grid (v1.26.0) — tap a level,
// see the calculated score immediately, zero round-trips per click. This
// is DISPLAY ONLY: the form still submits the picked radios normally, and
// the server (Assignments::RubricScore) recomputes and persists the real
// grade — this never sends anything itself.
// Formula mirrors the server exactly: (Σ points×weight)/(Σ maxPoints×weight)×5.
// Markup:
//   <div data-controller="rubric-grid">
//     <tr data-rubric-grid-target="criterionRow" data-weight="2.0">
//       <input type="radio" data-action="rubric-grid#recompute" data-points="5.0">
//     </tr>
//     <output data-rubric-grid-target="output">—</output>
//   </div>
export default class extends Controller {
  static targets = ["criterionRow", "output"]

  connect() {
    this.recompute()
  }

  recompute() {
    const maxPoints = Math.max(
      ...this.criterionRowTargets.flatMap((row) =>
        Array.from(row.querySelectorAll("input[type=radio]")).map((input) => parseFloat(input.dataset.points))
      )
    )

    let numerator = 0
    let denominator = 0
    let allPicked = true

    this.criterionRowTargets.forEach((row) => {
      const weight = parseFloat(row.dataset.weight)
      const checked = row.querySelector("input[type=radio]:checked")
      denominator += maxPoints * weight
      if (checked) {
        numerator += parseFloat(checked.dataset.points) * weight
      } else {
        allPicked = false
      }
    })

    if (denominator === 0) {
      this.outputTarget.textContent = "—"
    } else if (!allPicked) {
      this.outputTarget.textContent = "incompleto"
    } else {
      this.outputTarget.textContent = ((numerator / denominator) * 5).toFixed(1)
    }
  }
}
