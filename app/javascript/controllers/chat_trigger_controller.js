// app/javascript/controllers/chat_trigger_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("🚀 chat-trigger controller connected — dispatching event")
    this.element.dispatchEvent(new CustomEvent("chat:enable", { bubbles: true }))
    this.element.remove() // cleanup
  }
}
