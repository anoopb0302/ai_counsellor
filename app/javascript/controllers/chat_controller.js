import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submit"]

  connect() {
    console.log("✅ Chat controller connected")
    document.addEventListener("chat:enable", this.enableForm.bind(this))
    this.scrollToBottom()
    this.focusInput()
  }

  focusInput() {
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  // autoGrow() {
  //   this.inputTarget.style.height = 'auto'
  //   this.inputTarget.style.height = `${this.inputTarget.scrollHeight}px`
  // }

  autoGrow(event) {
    const textarea = event.target
    textarea.style.height = "auto"
    textarea.style.height = `${textarea.scrollHeight}px`
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submitTarget.click()
    }
  }

  arrowIcon() {
    return `
      <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14M12 5l7 7-7 7" />
      </svg>
    `
  }

  spinner() {
    return `
      <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"></path>
      </svg>
    `
  }

  disableForm() {
    console.log("🟡 Disabling form...")
    this.inputTarget.disabled = true
    this.submitTarget.disabled = true
    this.submitTarget.innerText = "Thinking..."

    this.timeout = setTimeout(() => {
      console.warn("⏱️ LLM timeout - re-enabling form")
      this.enableForm()
      alert("Sorry, response took too long. Please try again.")
    }, 60000)
  }

  enableForm() {
    if (!this.hasInputTarget || !this.hasSubmitTarget) {
      console.warn("⚠️ Chat controller enabled without input or submit targets. Skipping.")
      return
    }
  
    console.log("🟢 Re-enabling form...")
    clearTimeout(this.timeout)
    this.inputTarget.disabled = false
    this.submitTarget.disabled = false
    this.submitTarget.innerText = "Send"
    this.inputTarget.value = ""
    this.scrollToBottom()

  }
  

  scrollToBottom() {
    requestAnimationFrame(() => {
      window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" })
    })
  }
}
