/**
 * ============================================================================
 * CPU-From-Scratch: 5-Stage Pipelined CPU Visualizer Application Logic
 * Completely Offline - Zero External Dependencies - Uses window.CPU_TRACES
 * ============================================================================
 */

(function () {
  "use strict";

  // --- Check Data Availability ---
  if (!window.CPU_TRACES) {
    alert("Error: window.CPU_TRACES is not defined. Ensure visualizer/data/traces.js is loaded.");
    return;
  }

  // --- Constants & Palette ---
  // High-contrast distinct colors for instructions as they move through the pipeline
  const INSTRUCTION_COLORS = [
    "#38bdf8", // Sky Blue
    "#4ade80", // Vibrant Green
    "#a855f7", // Electric Purple
    "#f43f5e", // Rose Red
    "#fbbf24", // Amber Gold
    "#06b6d4", // Cyan
    "#ec4899", // Vivid Pink
    "#818cf8", // Indigo
    "#f97316", // Bright Orange
    "#14b8a6", // Teal
    "#e879f9", // Fuchsia
    "#34d399", // Emerald
    "#60a5fa", // Cornflower Blue
    "#f87171", // Coral
    "#a3e635", // Lime
    "#c084fc", // Purple Light
    "#2dd4bf", // Mint
    "#fb923c"  // Tangerine
  ];

  // ABI Register Names mapping (RISC-V standard)
  const ABI_NAMES = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0/fp", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
  ];

  // --- Application State ---
  let currentProgramKey = "bubble_sort";
  let currentCycleIndex = 0; // 0-indexed into program.cycles
  let isPlaying = false;
  let playTimer = null;
  let stepDelayMs = 400; // Default playback speed
  let isKioskMode = false;
  let kioskPauseTimer = null;
  let selectedSourceFile = null;

  // --- Cache Pre-computed Cumulative Stats ---
  const cumulativeStats = {};

  function precomputeStats() {
    Object.keys(window.CPU_TRACES).forEach(progKey => {
      const prog = window.CPU_TRACES[progKey];
      cumulativeStats[progKey] = [];
      let retired = 0;
      let stalls = 0;
      let flushes = 0;

      prog.cycles.forEach((c, idx) => {
        if (c.stall === 1) stalls++;
        if (c.flush === 1) flushes++;
        if (c.stages.WB && !c.stages.WB.bubble && c.stages.WB.pc !== null) {
          retired++;
        }
        cumulativeStats[progKey].push({
          retired,
          stalls,
          flushes,
          cpi: retired > 0 ? (c.cycle / retired).toFixed(2) : "1.00"
        });
      });
    });
  }
  precomputeStats();

  // Helper: Get instruction color by PC
  function getInstructionColor(pc) {
    if (pc === null || pc === undefined) return null;
    const idx = Math.abs(Math.floor(pc / 4)) % INSTRUCTION_COLORS.length;
    return INSTRUCTION_COLORS[idx];
  }

  // Helper: Format signed 32-bit decimal
  function toSigned32(val) {
    return (val | 0);
  }

  // Helper: Format 32-bit Hex string
  function toHex32(val) {
    return "0x" + (val >>> 0).toString(16).padStart(8, "0").toUpperCase();
  }

  // --- DOM Elements ---
  const elProgramSelect = document.getElementById("program-select");
  const elBtnKiosk = document.getElementById("btn-kiosk");
  const elBtnFirst = document.getElementById("btn-first");
  const elBtnPrev = document.getElementById("btn-prev");
  const elBtnPlay = document.getElementById("btn-play");
  const elBtnNext = document.getElementById("btn-next");
  const elBtnLast = document.getElementById("btn-last");
  const elBtnReset = document.getElementById("btn-reset");
  const elScrubber = document.getElementById("scrubber-slider");
  const elCycleBadge = document.getElementById("cycle-badge");

  const elBannerStall = document.getElementById("banner-stall");
  const elBannerFlush = document.getElementById("banner-flush");

  const elStageCards = {
    IF: document.getElementById("stage-card-if"),
    ID: document.getElementById("stage-card-id"),
    EX: document.getElementById("stage-card-ex"),
    MEM: document.getElementById("stage-card-mem"),
    WB: document.getElementById("stage-card-wb")
  };

  const elFwdA = document.getElementById("fwd-a-badge");
  const elFwdB = document.getElementById("fwd-b-badge");
  const elAluRes = document.getElementById("alu-res-badge");
  const elWbCommit = document.getElementById("wb-commit-badge");

  const elBarChart = document.getElementById("bar-chart");
  const elMemWordsGrid = document.getElementById("mem-words-grid");

  const elStatCycles = document.getElementById("stat-cycles");
  const elStatRetired = document.getElementById("stat-retired");
  const elStatStalls = document.getElementById("stat-stalls");
  const elStatFlushes = document.getElementById("stat-flushes");
  const elStatCpi = document.getElementById("stat-cpi");
  const elSummaryBox = document.getElementById("summary-box");

  const elListingBody = document.getElementById("listing-body");
  const elRegfileGrid = document.getElementById("regfile-grid");

  // Tabs
  const elTabButtons = document.querySelectorAll(".nav-tab-btn");
  const elTabContents = {
    pipeline: document.getElementById("tab-pipeline"),
    sources: document.getElementById("tab-sources"),
    explainer: document.getElementById("tab-explainer")
  };

  // Source Viewer
  const elSourceFileList = document.getElementById("source-file-list");
  const elSourceCodePre = document.getElementById("source-code-pre");
  const elSourceFileName = document.getElementById("source-file-name");

  // --- Render Functions ---

  // 1. Render Program Disassembly Listing
  function renderProgramListing() {
    const prog = window.CPU_TRACES[currentProgramKey];
    elListingBody.innerHTML = "";

    prog.program.forEach(item => {
      const tr = document.createElement("tr");
      tr.className = "listing-row";
      tr.id = `listing-row-${item.pc}`;

      const color = getInstructionColor(item.pc);
      tr.innerHTML = `
        <td class="listing-cell listing-pc mono">0x${item.pc.toString(16).padStart(2, "0").toUpperCase()}</td>
        <td class="listing-cell listing-hex mono">0x${item.hex}</td>
        <td class="listing-cell listing-asm mono">
          <span style="color: ${color}; font-weight: bold; margin-right: 6px;">●</span>
          <span>${item.asm}</span>
          <span class="stage-tag-slot" id="tag-slot-${item.pc}"></span>
        </td>
      `;
      elListingBody.appendChild(tr);
    });
  }

  // 2. Render Register File Cards (Initial Structure)
  function initRegisterFile() {
    elRegfileGrid.innerHTML = "";
    for (let i = 0; i < 32; i++) {
      const card = document.createElement("div");
      card.className = "reg-card";
      card.id = `reg-card-${i}`;
      card.innerHTML = `
        <div class="reg-name">x${i} <span style="font-size:8px; opacity:0.7">(${ABI_NAMES[i]})</span></div>
        <div class="reg-val-dec mono" id="reg-val-dec-${i}">0</div>
        <div class="reg-val-hex mono" id="reg-val-hex-${i}">0x00000000</div>
      `;
      elRegfileGrid.appendChild(card);
    }
  }

  // 3. Render Memory Words Grid (Initial Structure)
  function initMemWordsGrid() {
    elMemWordsGrid.innerHTML = "";
    for (let i = 0; i < 16; i++) {
      const cell = document.createElement("div");
      cell.className = "mem-cell";
      cell.id = `mem-cell-${i}`;
      cell.innerHTML = `
        <div class="mem-cell-idx">0x${(i * 4).toString(16).padStart(2, "0").toUpperCase()} [${i}]</div>
        <div class="mem-cell-val mono" id="mem-cell-val-${i}">0</div>
      `;
      elMemWordsGrid.appendChild(cell);
    }
  }

  // 4. Update the Pipeline View for Current Cycle
  function updateView() {
    const progData = window.CPU_TRACES[currentProgramKey];
    const cycles = progData.cycles;
    const cur = cycles[currentCycleIndex];
    const prev = currentCycleIndex > 0 ? cycles[currentCycleIndex - 1] : null;
    const stats = cumulativeStats[currentProgramKey][currentCycleIndex];

    // Scrubber & Cycle Counter Badge
    elScrubber.max = cycles.length;
    elScrubber.value = cur.cycle;
    elCycleBadge.innerHTML = `Cycle <span class="text-cyan">${cur.cycle}</span> of ${cycles.length}`;

    // Stalls & Flushes Banners
    if (cur.stall === 1) {
      elBannerStall.style.display = "flex";
      document.getElementById("stall-cycle-label").textContent = `Cycle ${cur.cycle}`;
    } else {
      elBannerStall.style.display = "none";
    }

    if (cur.flush === 1) {
      elBannerFlush.style.display = "flex";
      document.getElementById("flush-cycle-label").textContent = `Cycle ${cur.cycle}`;
    } else {
      elBannerFlush.style.display = "none";
    }

    // Clear previous listing stage tags & active IF highlights
    document.querySelectorAll(".stage-tag-slot").forEach(el => el.innerHTML = "");
    document.querySelectorAll(".listing-row.current-if").forEach(el => el.classList.remove("current-if"));

    // Render 5 Stages (IF, ID, EX, MEM, WB)
    ["IF", "ID", "EX", "MEM", "WB"].forEach(stageName => {
      const stage = cur.stages[stageName];
      const card = elStageCards[stageName];

      const asmEl = card.querySelector(".stage-asm");
      const hexEl = card.querySelector(".stage-hex");
      const pcEl = card.querySelector(".stage-pc-val");
      const stateBadge = card.querySelector(".stage-badge");

      // Reset card styles
      card.className = "stage-card";
      card.style.borderColor = "";
      card.style.backgroundColor = "";

      if (!stage || stage.bubble || stage.pc === null) {
        card.classList.add("is-bubble");
        asmEl.textContent = "nop (bubble)";
        hexEl.textContent = "0x00000013";
        pcEl.textContent = "--";
        stateBadge.textContent = "BUBBLE";
        stateBadge.style.color = "var(--text-dim)";
      } else {
        const color = getInstructionColor(stage.pc);
        card.style.borderColor = color;
        card.style.backgroundColor = `rgba(${hexToRgb(color)}, 0.12)`;
        card.style.boxShadow = `0 0 15px rgba(${hexToRgb(color)}, 0.25)`;

        asmEl.textContent = stage.asm;
        hexEl.textContent = `0x${stage.hex}`;
        pcEl.textContent = `0x${stage.pc.toString(16).padStart(2, "0").toUpperCase()}`;
        stateBadge.textContent = "ACTIVE";
        stateBadge.style.color = color;

        // Add stage pill badge in listing
        const tagSlot = document.getElementById(`tag-slot-${stage.pc}`);
        if (tagSlot) {
          tagSlot.innerHTML += `<span class="stage-pill-tag mono" style="background: ${color}; color: #04101e">${stageName}</span>`;
        }

        // Highlight IF current row in listing
        if (stageName === "IF") {
          const row = document.getElementById(`listing-row-${stage.pc}`);
          if (row) {
            row.classList.add("current-if");
            // Auto-scroll listing to keep current instruction in view
            row.scrollIntoView({ behavior: "smooth", block: "nearest" });
          }
        }
      }

      // Mark Stalled or Flushed stages
      if (cur.stall === 1 && (stageName === "IF" || stageName === "ID")) {
        card.classList.add("is-frozen");
        stateBadge.textContent = "🔒 FROZEN";
        stateBadge.style.color = "var(--rose)";
      }
      if (cur.flush === 1 && (stageName === "IF" || stageName === "ID")) {
        card.classList.add("is-flushed");
        stateBadge.textContent = "✂ FLUSHED";
        stateBadge.style.color = "var(--amber)";
      }
    });

    // Forwarding Pills & ALU Result
    renderForwarding(cur);

    // Render Data Memory Bar Chart (First 8 Words)
    renderMemoryBars(cur.mem, prev ? prev.mem : null);

    // Render Live Register File
    renderRegisters(cur.regs, cur.wb);

    // Render Live Statistics & Summary
    renderStats(cur, stats, progData.summary, cycles.length);
  }

  // Forwarding Badges
  function renderForwarding(cur) {
    // Fwd A
    if (cur.fwd_a === 2) {
      elFwdA.className = "forwarding-pill fwd-active";
      elFwdA.innerHTML = `⚡ FwdA: <strong>EX/MEM ➔ EX</strong>`;
    } else if (cur.fwd_a === 1) {
      elFwdA.className = "forwarding-pill fwd-active";
      elFwdA.innerHTML = `⚡ FwdA: <strong>WB ➔ EX</strong>`;
    } else {
      elFwdA.className = "forwarding-pill fwd-idle";
      elFwdA.textContent = `FwdA: RegFile`;
    }

    // Fwd B
    if (cur.fwd_b === 2) {
      elFwdB.className = "forwarding-pill fwd-active";
      elFwdB.innerHTML = `⚡ FwdB: <strong>EX/MEM ➔ EX</strong>`;
    } else if (cur.fwd_b === 1) {
      elFwdB.className = "forwarding-pill fwd-active";
      elFwdB.innerHTML = `⚡ FwdB: <strong>WB ➔ EX</strong>`;
    } else {
      elFwdB.className = "forwarding-pill fwd-idle";
      elFwdB.textContent = `FwdB: RegFile`;
    }

    // ALU Result & WB Write
    elAluRes.textContent = `ALU Out: ${toSigned32(cur.alu_result)} (${toHex32(cur.alu_result)})`;
    if (cur.wb && cur.wb.write === 1 && cur.wb.reg !== 0) {
      elWbCommit.className = "forwarding-pill fwd-active";
      elWbCommit.innerHTML = `✔ WB Commit: x${cur.wb.reg} &larr; ${toSigned32(cur.wb.data)}`;
    } else {
      elWbCommit.className = "forwarding-pill fwd-idle";
      elWbCommit.textContent = `WB: No write`;
    }
  }

  // Memory Bar Chart Renderer
  function renderMemoryBars(memArray, prevMem) {
    elBarChart.innerHTML = "";
    const first8 = memArray.slice(0, 8);
    // Find dynamic maximum for scaling bar height
    const maxVal = Math.max(...first8, 10);

    first8.forEach((val, idx) => {
      const slot = document.createElement("div");
      slot.className = "bar-slot";

      const signedVal = toSigned32(val);
      const isChanged = prevMem && prevMem[idx] !== val;
      const heightPercent = Math.max(6, Math.round((Math.abs(signedVal) / maxVal) * 85));

      slot.innerHTML = `
        <div class="bar-val-text">${signedVal}</div>
        <div class="bar-column ${isChanged ? 'changed' : ''}" style="height: ${heightPercent}%;"></div>
        <div class="bar-label-text">[${idx}] 0x${(idx * 4).toString(16).padStart(2, "0").toUpperCase()}</div>
      `;
      elBarChart.appendChild(slot);
    });

    // Update 16 Words Grid below
    memArray.slice(0, 16).forEach((val, idx) => {
      const cellVal = document.getElementById(`mem-cell-val-${idx}`);
      if (cellVal) {
        cellVal.textContent = toSigned32(val);
        const cell = document.getElementById(`mem-cell-${idx}`);
        if (prevMem && prevMem[idx] !== val) {
          cell.style.borderColor = "var(--emerald)";
          cell.style.backgroundColor = "rgba(16, 185, 129, 0.15)";
        } else {
          cell.style.borderColor = "var(--border)";
          cell.style.backgroundColor = "var(--bg-input)";
        }
      }
    });
  }

  // Register File Update
  function renderRegisters(regs, wb) {
    regs.forEach((val, idx) => {
      const decEl = document.getElementById(`reg-val-dec-${idx}`);
      const hexEl = document.getElementById(`reg-val-hex-${idx}`);
      const card = document.getElementById(`reg-card-${idx}`);

      if (decEl && hexEl) {
        decEl.textContent = toSigned32(val);
        hexEl.textContent = toHex32(val);
      }

      // Flash highlight written register
      if (card) {
        if (wb && wb.write === 1 && wb.reg === idx && idx !== 0) {
          card.classList.add("just-written");
        } else {
          card.classList.remove("just-written");
        }
      }
    });
  }

  // Statistics Renderer
  function renderStats(cur, stats, summary, totalCycles) {
    elStatCycles.textContent = `${cur.cycle} / ${totalCycles}`;
    elStatRetired.textContent = stats.retired;
    elStatStalls.textContent = stats.stalls;
    elStatFlushes.textContent = stats.flushes;
    elStatCpi.textContent = stats.cpi;

    // Summary Box (at the end or showing target metrics)
    const isEnd = (cur.cycle === totalCycles);
    elSummaryBox.innerHTML = `
      <div style="font-size: 11px; color: var(--text-muted); text-transform: uppercase; font-weight: bold; margin-bottom: 6px;">
        ${isEnd ? "🏁 SIMULATION COMPLETED — OFFICIAL RESULTS:" : "TARGET PROGRAM SPECIFICATION:"}
      </div>
      <div style="display: flex; flex-wrap: wrap; gap: 14px; font-family: var(--font-mono); font-size: 13px;">
        <span>Total Cycles: <strong class="text-cyan">${summary.cycles}</strong></span>
        <span>Instructions: <strong class="text-emerald">${summary.instructions}</strong></span>
        <span>Stalls: <strong class="text-rose">${summary.stalls}</strong></span>
        <span>Flushes: <strong class="text-amber">${summary.branch_flushes}</strong></span>
        <span>CPI: <strong style="color:#e2e8f0">${summary.cpi}</strong></span>
      </div>
    `;
    if (isEnd) {
      elSummaryBox.style.borderColor = "var(--emerald)";
      elSummaryBox.style.background = "rgba(16, 185, 129, 0.1)";
    } else {
      elSummaryBox.style.borderColor = "var(--border)";
      elSummaryBox.style.background = "var(--bg-input)";
    }
  }

  // Helper: Hex color to RGB
  function hexToRgb(hex) {
    hex = hex.replace("#", "");
    const bigint = parseInt(hex, 16);
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    return `${r}, ${g}, ${b}`;
  }

  // --- Source Code Tab Renderer ---
  function initSourceViewer() {
    if (!window.CPU_SOURCES) {
      elSourceCodePre.textContent = "// window.CPU_SOURCES not loaded.";
      return;
    }

    const files = Object.keys(window.CPU_SOURCES);
    elSourceFileList.innerHTML = "";

    files.forEach((filename, idx) => {
      const btn = document.createElement("button");
      btn.className = "source-file-btn" + (idx === 0 ? " active" : "");
      btn.textContent = filename;
      btn.onclick = () => {
        document.querySelectorAll(".source-file-btn").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        showSourceFile(filename);
      };
      elSourceFileList.appendChild(btn);
    });

    if (files.length > 0) {
      showSourceFile(files[0]);
    }
  }

  function showSourceFile(filename) {
    selectedSourceFile = filename;
    elSourceFileName.textContent = filename;
    const code = window.CPU_SOURCES[filename] || "// File not found";
    elSourceCodePre.textContent = code;
  }

  // --- Playback Navigation Controls ---
  function stepForward() {
    const total = window.CPU_TRACES[currentProgramKey].cycles.length;
    if (currentCycleIndex < total - 1) {
      currentCycleIndex++;
      updateView();
      return true;
    } else {
      pausePlayback();
      // In Kiosk mode: pause and switch to other program
      if (isKioskMode) {
        handleKioskLoop();
      }
      return false;
    }
  }

  function stepBackward() {
    if (currentCycleIndex > 0) {
      currentCycleIndex--;
      updateView();
    }
  }

  function jumpToFirst() {
    pausePlayback();
    currentCycleIndex = 0;
    updateView();
  }

  function jumpToLast() {
    pausePlayback();
    currentCycleIndex = window.CPU_TRACES[currentProgramKey].cycles.length - 1;
    updateView();
  }

  function resetSimulation() {
    pausePlayback();
    currentCycleIndex = 0;
    updateView();
  }

  function startPlayback() {
    isPlaying = true;
    elBtnPlay.innerHTML = `⏸ Pause`;
    elBtnPlay.style.background = "var(--amber)";
    elBtnPlay.style.borderColor = "var(--amber)";
    elBtnPlay.style.color = "#000";

    playTimer = setInterval(() => {
      stepForward();
    }, stepDelayMs);
  }

  function pausePlayback() {
    isPlaying = false;
    elBtnPlay.innerHTML = `▶ Play`;
    elBtnPlay.style.background = "var(--cyan)";
    elBtnPlay.style.borderColor = "var(--cyan)";
    elBtnPlay.style.color = "#04101e";
    if (playTimer) {
      clearInterval(playTimer);
      playTimer = null;
    }
  }

  function togglePlayback() {
    if (isPlaying) {
      pausePlayback();
    } else {
      startPlayback();
    }
  }

  // --- Kiosk Mode (Continuous Exhibition Auto-Loop) ---
  function toggleKioskMode() {
    isKioskMode = !isKioskMode;
    if (isKioskMode) {
      document.body.classList.add("kiosk-mode");
      elBtnKiosk.classList.add("active");
      elBtnKiosk.innerHTML = `★ KIOSK MODE [ACTIVE]`;
      if (!isPlaying) startPlayback();
    } else {
      document.body.classList.remove("kiosk-mode");
      elBtnKiosk.classList.remove("active");
      elBtnKiosk.innerHTML = `★ Kiosk Mode`;
      if (kioskPauseTimer) clearTimeout(kioskPauseTimer);
    }
  }

  function handleKioskLoop() {
    if (!isKioskMode) return;
    // Pause 3.5 seconds on final result, then swap program and continue
    kioskPauseTimer = setTimeout(() => {
      if (!isKioskMode) return;
      currentProgramKey = (currentProgramKey === "bubble_sort") ? "fibonacci" : "bubble_sort";
      elProgramSelect.value = currentProgramKey;
      loadProgram(currentProgramKey);
      startPlayback();
    }, 3500);
  }

  // --- Program Loader ---
  function loadProgram(key) {
    pausePlayback();
    currentProgramKey = key;
    currentCycleIndex = 0;
    renderProgramListing();
    updateView();
  }

  // --- Tab Switcher ---
  function switchTab(targetTab) {
    elTabButtons.forEach(btn => {
      if (btn.dataset.tab === targetTab) {
        btn.classList.add("active");
      } else {
        btn.classList.remove("active");
      }
    });

    Object.keys(elTabContents).forEach(tabKey => {
      if (tabKey === targetTab) {
        elTabContents[tabKey].style.display = "block";
      } else {
        elTabContents[tabKey].style.display = "none";
      }
    });
  }

  // --- Event Listeners Initialization ---
  function initEvents() {
    // Program Select
    elProgramSelect.addEventListener("change", (e) => {
      loadProgram(e.target.value);
    });

    // Kiosk Mode
    elBtnKiosk.addEventListener("click", toggleKioskMode);

    // Playback buttons
    elBtnPlay.addEventListener("click", togglePlayback);
    elBtnNext.addEventListener("click", () => { pausePlayback(); stepForward(); });
    elBtnPrev.addEventListener("click", () => { pausePlayback(); stepBackward(); });
    elBtnFirst.addEventListener("click", jumpToFirst);
    elBtnLast.addEventListener("click", jumpToLast);
    elBtnReset.addEventListener("click", resetSimulation);

    // Scrubber
    elScrubber.addEventListener("input", (e) => {
      pausePlayback();
      currentCycleIndex = parseInt(e.target.value, 10) - 1;
      updateView();
    });

    // Speed Selector
    document.querySelectorAll(".speed-btn").forEach(btn => {
      btn.addEventListener("click", () => {
        document.querySelectorAll(".speed-btn").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        stepDelayMs = parseInt(btn.dataset.speed, 10);
        if (isPlaying) {
          pausePlayback();
          startPlayback();
        }
      });
    });

    // Tab buttons
    elTabButtons.forEach(btn => {
      btn.addEventListener("click", () => switchTab(btn.dataset.tab));
    });

    // Keyboard Shortcuts (Space: play/pause, Left: prev, Right: next, R: reset)
    window.addEventListener("keydown", (e) => {
      if (e.target.tagName === "INPUT" || e.target.tagName === "SELECT") return;
      if (e.code === "Space") {
        e.preventDefault();
        togglePlayback();
      } else if (e.code === "ArrowRight") {
        e.preventDefault();
        pausePlayback();
        stepForward();
      } else if (e.code === "ArrowLeft") {
        e.preventDefault();
        pausePlayback();
        stepBackward();
      } else if (e.code === "KeyR") {
        resetSimulation();
      }
    });
  }

  // --- App Startup ---
  function initApp() {
    initRegisterFile();
    initMemWordsGrid();
    initSourceViewer();
    initEvents();

    loadProgram(currentProgramKey);
  }

  // Start when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initApp);
  } else {
    initApp();
  }

})();
