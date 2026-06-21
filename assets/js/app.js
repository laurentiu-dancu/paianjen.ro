import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 25000,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Infinite scroll hook for groups list
let Hooks = {};
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          this.pushEvent("load_more", {});
        }
      },
      { rootMargin: "200px" }
    );
    // Observe the sentinel element at the bottom
    this.sentinel = document.getElementById("scroll-sentinel");
    if (this.sentinel) {
      this.observer.observe(this.sentinel);
    }
  },
  updated() {
    // Re-observe after new content is loaded
    if (this.sentinel) {
      this.observer.unobserve(this.sentinel);
    }
    this.sentinel = document.getElementById("scroll-sentinel");
    if (this.sentinel) {
      this.observer.observe(this.sentinel);
    }
  },
  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  },
};

liveSocket.connect();
window.liveSocket = liveSocket;
