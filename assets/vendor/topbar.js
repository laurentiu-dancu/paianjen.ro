// vendored from topbar package
(function(global, factory) {
  typeof exports === "object" && typeof module !== "undefined" ? module.exports = factory() :
  typeof define === "function" && define.amd ? define(factory) :
  (global = typeof globalThis !== "undefined" ? globalThis : global || self, global.topbar = factory());
})(this, function() {
  "use strict";
  var options = {
    barThickness: 3,
    barColors: { "0": "rgba(255, 165, 0, .9)" },
    shadowBlur: 10,
    shadowColor: "rgba(255, 165, 0, .4)"
  };
  var canvas, progressTimerId, fadeTimerId, currentProgress = 0, showing = false;
  function createCanvas() {
    canvas = document.createElement("canvas");
    canvas.style.cssText = "position:fixed;top:0;left:0;width:100%;z-index:10000;pointer-events:none;";
    canvas.height = options.barThickness;
    document.body.appendChild(canvas);
    return canvas;
  }
  function render() {
    if (!canvas) createCanvas();
    var ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = options.barColors["0"];
    ctx.fillRect(0, 0, canvas.width * (currentProgress / 100), canvas.height);
  }
  return {
    show: function() {
      if (showing) return;
      showing = true;
      if (fadeTimerId) clearTimeout(fadeTimerId);
      if (!canvas) createCanvas();
      canvas.style.opacity = "1";
      canvas.style.display = "block";
      currentProgress = 0;
      progressTimerId = setInterval(function() {
        currentProgress += Math.random() * 10;
        if (currentProgress > 90) currentProgress = 90;
        render();
      }, 200);
    },
    hide: function() {
      if (!showing) return;
      showing = false;
      clearInterval(progressTimerId);
      currentProgress = 100;
      render();
      fadeTimerId = setTimeout(function() {
        if (canvas) {
          canvas.style.opacity = "0";
          setTimeout(function() {
            if (canvas) canvas.style.display = "none";
          }, 300);
        }
      }, 300);
    }
  };
});
