import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import htmx from "htmx.org";

// Make htmx available globally
window.htmx = htmx;

// HTMX + LiveView integration
// When HTMX swaps content, we need to tell LiveView about it
document.addEventListener("htmx:afterSettle", (event) => {
  // Re-initialize any LiveView hooks in the swapped content
  window.liveSocket?.execJS(event.detail.elt, event.detail.elt.getAttribute("data-phx-hook"));
});

// Show topbar progress on HTMX requests
document.addEventListener("htmx:beforeRequest", () => {
  topbar.show();
});
document.addEventListener("htmx:afterRequest", () => {
  topbar.hide();
});

// LiveView setup
let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 25000,
  params: { _csrf_token: csrfToken },
});

// Show topbar on LiveView navigation
liveSocket.onInfo((info) => {
  if (info.type === "redirect") {
    topbar.show();
  }
});

liveSocket.connect();
window.liveSocket = liveSocket;
