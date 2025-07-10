import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  fillPrompt(event) {
    console.log("Filling chat prompt:", event.currentTarget.dataset.chatPrompt)
    const prompt = event.currentTarget.dataset.chatPrompt
    const input = document.querySelector("textarea[name='query']")

    if (input) {
      input.value = prompt
      input.focus()

      // Trigger input event for auto-grow in chat controller
      const inputEvent = new Event("input", { bubbles: true })
      input.dispatchEvent(inputEvent)
    } else {
      console.warn("⚠️ Chat input not found.")
    }
  }
}
