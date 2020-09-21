import { Controller } from "stimulus"

export default class extends Controller {
    static targets = ["toggleable"]


  connect() {
    console.log(this.toggleableTarget)
  }

  toggle() {  
    console.log('clicked')
    this.toggleableTarget.classList.toggle("show")
  }
}