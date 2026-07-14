import { Controller } from "@hotwired/stimulus"

// Progressive disclosure for the addon form: the metering fields
// (included_quota/unit/overage_unit_price_cents) only make sense — and are
// only required — when `metered` is checked. Without JS all fields stay
// visible; the DB CHECK constraint is the real backstop either way.
// Markup:
//   <div data-controller="metered-fields">
//     <input type="checkbox" data-metered-fields-target="toggle" data-action="metered-fields#sync">
//     <div data-metered-fields-target="fields">…</div>
//   </div>
export default class extends Controller {
  static targets = ["toggle", "fields"]

  connect() {
    this.sync()
  }

  sync() {
    this.fieldsTarget.hidden = !this.toggleTarget.checked
  }
}
