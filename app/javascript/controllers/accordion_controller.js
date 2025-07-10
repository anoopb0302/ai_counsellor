// app/javascript/controllers/accordion_controller.js
// import { Controller } from "@hotwired/stimulus"

// export default class extends Controller {
//   static targets = ["details"]

//   toggle(event) {
//     const sessionId = event.currentTarget.dataset.sessionId
//     const detailRow = this.detailsTargets.find(el => el.dataset.sessionId === sessionId)
//     if (detailRow) {
//       detailRow.classList.toggle("hidden")
//     }
//   }
// }


// app/javascript/controllers/accordion_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["details"]

  toggle(event) {
    const sessionId = event.currentTarget.dataset.sessionId
    const detailRow = this.detailsTargets.find(el => el.dataset.sessionId === sessionId)
    if (detailRow) {
      detailRow.classList.toggle("hidden")
    }
  }
}
