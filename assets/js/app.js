import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content");

// All hooks must be defined BEFORE LiveSocket is created
let Hooks = {};

// Infinite scroll hook for groups list
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

Hooks.ImageSlider = {
  mounted() {
    const images = JSON.parse(this.el.dataset.images);
    if (images.length === 0) return;

    this.currentIndex = 0;
    this.imgEl = document.getElementById("slider-img");
    this.dots = document.querySelectorAll("#slider-dots button");

    this.updateDots = () => {
      if (!this.dots) return;
      this.dots.forEach((dot, i) => {
        if (i === this.currentIndex) {
          dot.className = "w-2 h-2 rounded-full bg-white shadow";
        } else {
          dot.className = "w-2 h-2 rounded-full bg-white/60";
        }
      });
    };

    this.goTo = (index) => {
      this.currentIndex = index;
      this.imgEl.src = images[index];
      this.updateDots();
    };

    window.slideTo = (index) => this.goTo(index);

    window.slideNext = () => {
      this.goTo((this.currentIndex + 1) % images.length);
    };

    window.slidePrev = () => {
      this.goTo((this.currentIndex - 1 + images.length) % images.length);
    };

    this.updateDots();
  },
  updated() {
    this.imgEl = document.getElementById("slider-img");
    this.dots = document.querySelectorAll("#slider-dots button");
  },
};

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 25000,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

liveSocket.connect();
window.liveSocket = liveSocket;
