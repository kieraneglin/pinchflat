// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html'
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import topbar from '../vendor/topbar'
import Alpine from 'alpinejs'
import './tabs'
import './alpine_helpers'

window.Alpine = Alpine
Alpine.start()

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute('content')
let liveSocket = new LiveSocket(document.body.dataset.socketPath, Socket, {
  params: { _csrf_token: csrfToken },
  dom: {
    onBeforeElUpdated(from, to) {
      if (from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  },
  hooks: {
    'supress-enter-submission': {
      mounted() {
        this.el.addEventListener('keypress', (event) => {
          if (event.key === 'Enter') {
            event.preventDefault()
          }
        })
      }
    },
    'formless-input': {
      mounted() {
        const subscribedEvents = this.el.dataset.subscribe.split(' ')
        const eventName = this.el.dataset.eventName || ''
        const identifier = this.el.dataset.identifier || ''

        subscribedEvents.forEach((domEvent) => {
          this.el.addEventListener(domEvent, () => {
            // This ensures that the event is pushed to the server after the input value has been updated
            // so that the server has the most up-to-date value
            setTimeout(() => {
              this.pushEvent('formless-input', {
                value: this.el.value,
                id: identifier,
                event: eventName,
                dom_id: this.el.id,
                dom_event: domEvent
              })
            }, 0)
          })
        })
      }
    }
  }
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: '#29d' }, shadowColor: 'rgba(0, 0, 0, .3)' })
window.addEventListener('phx:page-loading-start', (_info) => topbar.show(300))
window.addEventListener('phx:page-loading-stop', (_info) => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
