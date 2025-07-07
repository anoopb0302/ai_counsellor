import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  
  connect() {

    console.log("🔵 This is the ESBuild-based application.js");
    this.scrollToBottom()
  }

  // scrollToBottom() {
  //   this.element.scrollTop = this.element.scrollHeight
  // }

  scrollToBottom() {
    requestAnimationFrame(() => {
      window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' })
    })
  }
}
