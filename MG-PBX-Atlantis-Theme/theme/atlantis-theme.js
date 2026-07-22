/*
 * MG PBX Atlantis Command Interface
 * Original fan-style UI behavior. No external dependencies.
 * Version 1.0.0
 */

(() => {
  "use strict";

  const THEME_ID = "mgpbx-atlantis-shell";
  const STORAGE_KEY = "mgpbx-atlantis-tones";

  function getAssetUrl(fileName) {
    const activeScript = document.currentScript || Array.from(document.scripts).find((script) =>
      script.src && script.src.includes("atlantis-theme.js")
    );

    if (!activeScript || !activeScript.src) {
      return fileName;
    }

    return new URL(fileName, new URL(".", activeScript.src)).href;
  }

  function createElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) {
      element.className = className;
    }
    if (typeof text === "string") {
      element.textContent = text;
    }
    return element;
  }

  function buildShell() {
    if (document.getElementById(THEME_ID)) {
      return;
    }

    document.body.classList.add("mgpbx-atlantis");

    const shell = createElement("header");
    shell.id = THEME_ID;
    shell.setAttribute("role", "banner");

    const brand = createElement("div", "atl-brand");
    const emblem = document.createElement("img");
    emblem.src = getAssetUrl("mg-pbx-atlantis.svg");
    emblem.alt = "MG PBX command interface emblem";
    emblem.width = 54;
    emblem.height = 54;

    const brandCopy = createElement("div", "atl-brand-copy");
    brandCopy.append(
      createElement("div", "atl-kicker", "CARTER PRIMARY CONTROL"),
      createElement("div", "atl-title", "MG PBX • Atlantis Communications")
    );
    brand.append(emblem, brandCopy);

    const center = createElement("div", "atl-shell-center");
    const pulse = createElement("span", "atl-pulse-core");
    pulse.setAttribute("aria-hidden", "true");
    center.append(pulse, createElement("span", "atl-interface-label", "Interface active"));

    const right = createElement("div", "atl-shell-right");
    const clockBlock = createElement("div", "atl-clock-block");
    const clock = createElement("div");
    clock.id = "mgpbx-atlantis-clock";
    const date = createElement("div");
    date.id = "mgpbx-atlantis-date";
    clockBlock.append(clock, date);

    const toneToggle = createElement("button", "atl-tone-toggle", "◈");
    toneToggle.type = "button";
    toneToggle.title = "Toggle interface tones";
    toneToggle.setAttribute("aria-label", "Toggle interface tones");
    toneToggle.setAttribute("aria-pressed", localStorage.getItem(STORAGE_KEY) === "on" ? "true" : "false");

    toneToggle.addEventListener("click", () => {
      const enable = toneToggle.getAttribute("aria-pressed") !== "true";
      toneToggle.setAttribute("aria-pressed", enable ? "true" : "false");
      localStorage.setItem(STORAGE_KEY, enable ? "on" : "off");
      if (enable) {
        playTone(660, 0.07, 0.025);
        window.setTimeout(() => playTone(880, 0.09, 0.02), 80);
      }
    });

    right.append(clockBlock, toneToggle);
    shell.append(brand, center, right);
    document.body.prepend(shell);

    const scanline = createElement("div", "atl-scanline");
    scanline.setAttribute("aria-hidden", "true");
    const cornerGlyph = createElement("div", "atl-corner-glyph", "ATL-COM • LOCAL CONTROL • MG-01");
    cornerGlyph.setAttribute("aria-hidden", "true");
    document.body.append(scanline, cornerGlyph);

    updateClock();
    window.setInterval(updateClock, 1000);
  }

  function updateClock() {
    const clock = document.getElementById("mgpbx-atlantis-clock");
    const date = document.getElementById("mgpbx-atlantis-date");
    if (!clock || !date) {
      return;
    }

    const now = new Date();
    clock.textContent = new Intl.DateTimeFormat(undefined, {
      hour: "numeric",
      minute: "2-digit",
      second: "2-digit"
    }).format(now);

    date.textContent = new Intl.DateTimeFormat(undefined, {
      weekday: "short",
      month: "short",
      day: "numeric",
      year: "numeric"
    }).format(now);
  }

  function tonesEnabled() {
    return localStorage.getItem(STORAGE_KEY) === "on";
  }

  function playTone(frequency = 560, duration = 0.045, volume = 0.018) {
    if (!tonesEnabled() && frequency !== 660) {
      return;
    }

    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) {
      return;
    }

    try {
      const context = new AudioContextClass();
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.type = "sine";
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(0.0001, context.currentTime);
      gain.gain.exponentialRampToValueAtTime(volume, context.currentTime + 0.008);
      gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + duration);
      oscillator.connect(gain);
      gain.connect(context.destination);
      oscillator.start();
      oscillator.stop(context.currentTime + duration + 0.015);
      oscillator.addEventListener("ended", () => context.close());
    } catch (_error) {
      // Audio is decorative. Ignore browser or device audio restrictions.
    }
  }

  function attachInteractionTones() {
    document.addEventListener("click", (event) => {
      if (!tonesEnabled()) {
        return;
      }

      const target = event.target instanceof Element
        ? event.target.closest("button, .btn, [role='button'], nav a, .sidebar a")
        : null;

      if (!target || target.classList.contains("atl-tone-toggle")) {
        return;
      }

      playTone(520, 0.045, 0.015);
    }, { passive: true });
  }

  function annotateStatusText(root = document) {
    const candidates = root.querySelectorAll?.(".status, .badge, .chip, .tag, .label") || [];
    candidates.forEach((element) => {
      const text = element.textContent.trim().toLowerCase();
      if (/online|registered|healthy|available|ready|active/.test(text)) {
        element.dataset.state = "online";
      } else if (/offline|failed|error|critical|unavailable|down/.test(text)) {
        element.dataset.state = "offline";
      } else if (/warning|pending|ringing|connecting|unknown/.test(text)) {
        element.dataset.state = "warning";
      }
    });
  }

  function observeDynamicDashboard() {
    annotateStatusText(document);
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        mutation.addedNodes.forEach((node) => {
          if (node instanceof Element) {
            if (node.matches(".status, .badge, .chip, .tag, .label")) {
              annotateStatusText(node.parentElement || document);
            } else {
              annotateStatusText(node);
            }
          }
        });
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  function initialize() {
    if (!document.body) {
      return;
    }

    document.title = document.title.includes("MG PBX")
      ? document.title
      : `MG PBX | ${document.title || "Atlantis Command"}`;

    buildShell();
    attachInteractionTones();
    observeDynamicDashboard();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initialize, { once: true });
  } else {
    initialize();
  }
})();