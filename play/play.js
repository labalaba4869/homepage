/* Play page — 加载游戏数据并渲染 */

(async () => {
  const $ = (id) => document.getElementById(id);
  const params = new URLSearchParams(location.search);
  const gameId = params.get("id");
  let logReturnFocus = null;
  let logPreviousOverflow = "";

  // JSON 里 gameUrl 是相对仓库根的路径（如 "games/card-search-and-attack/index.html"），
  // 在 play.html 里 iframe 用相对路径会基于 play/ 目录解析，导致 404。
  // 这里用 location.href 做 base，加上 "../" 跨出 play/ 目录，再解析成绝对 URL。
  const resolveFromRepoRoot = (rel) => {
    if (!rel) return "";
    try {
      return new URL("../" + rel, location.href).href;
    } catch (e) {
      console.error("URL 解析失败:", rel, e);
      return rel;
    }
  };

  const setText = (id, text) => {
    const el = $(id);
    if (el) el.textContent = text;
  };

  const renderEmpty = (listEl, emptyText) => {
    listEl.innerHTML = "";
    const li = document.createElement("li");
    li.className = "empty";
    li.textContent = emptyText;
    listEl.appendChild(li);
  };

  const renderControls = (listEl, controls) => {
    listEl.innerHTML = "";
    if (!controls || controls.length === 0) {
      renderEmpty(listEl, "操作说明待补充");
      return;
    }
    controls.forEach((c) => {
      const li = document.createElement("li");
      const key = document.createElement("span");
      key.className = "key";
      key.textContent = c.key || "—";
      const act = document.createElement("span");
      act.textContent = c.action || "";
      li.appendChild(key);
      li.appendChild(act);
      listEl.appendChild(li);
    });
  };

  const renderRoadmap = (listEl, items) => {
    listEl.innerHTML = "";
    if (!items || items.length === 0) {
      renderEmpty(listEl, "暂无更新计划");
      return;
    }
    items.forEach((text) => {
      const li = document.createElement("li");
      li.textContent = text;
      listEl.appendChild(li);
    });
  };

  const renderChangelog = (listEl, entries) => {
    listEl.innerHTML = "";
    if (!entries || entries.length === 0) {
      renderEmpty(listEl, "暂无更新记录");
      return;
    }
    entries.forEach((e) => {
      const li = document.createElement("li");
      const date = document.createElement("span");
      date.className = "date";
      date.textContent = e.date || "";
      const text = document.createElement("span");
      text.className = "text";
      text.textContent = e.text || "";
      li.appendChild(date);
      li.appendChild(text);

      if (e.detailHtml || e.detail) {
        li.classList.add("clickable");
        li.tabIndex = 0;
        li.setAttribute("role", "button");
        li.setAttribute("aria-haspopup", "dialog");
        li.setAttribute("aria-label", `${e.date || ""} ${e.text || ""}，查看详情`);
        const openLog = () => {
          setText("logModalTitle", `${e.date || ""} · ${e.text || "更新日志"}`);
          const body = $("logModalDetail");
          if (!body) return;
          // detailHtml is sanitized at build time by tools/content/build.mjs.
          body.classList.toggle("is-plain-text", !e.detailHtml);
          if (e.detailHtml) body.innerHTML = e.detailHtml;
          else body.textContent = e.detail || "";
          const modal = $("logModal");
          if (modal) {
            logReturnFocus = li;
            logPreviousOverflow = document.body.style.overflow;
            modal.setAttribute("aria-hidden", "false");
            document.body.style.overflow = "hidden";
            modal.querySelector(".log-modal-body").scrollTop = 0;
            $("logModalClose").focus();
          }
        };
        li.addEventListener("click", openLog);
        li.addEventListener("keydown", (event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            openLog();
          }
        });
      }

      listEl.appendChild(li);
    });
  };

  const bindChangelog = (entries) => {
    const list = $("changelogList");
    if (!list) return;
    const previewSize = 5;
    const pageSize = 10;
    const logs = Array.isArray(entries)
      ? [...entries].sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")))
      : [];
    const footer = $("changelogFooter");
    const toggle = $("changelogToggle");
    const pagination = $("changelogPagination");
    const previous = $("changelogPrev");
    const next = $("changelogNext");
    const status = $("changelogPageStatus");
    if (!footer || !toggle || !pagination || !previous || !next || !status) {
      renderChangelog(list, logs.slice(0, previewSize));
      return;
    }

    // Page-local state: reloading or reopening the page restores the 5-entry preview.
    let expanded = false;
    let currentPage = 0;
    const pageCount = Math.max(1, Math.ceil(logs.length / pageSize));
    const render = () => {
      const start = expanded ? currentPage * pageSize : 0;
      renderChangelog(list, logs.slice(start, start + (expanded ? pageSize : previewSize)));
      footer.hidden = logs.length <= previewSize;
      toggle.textContent = expanded ? "收起更新日志" : "更多更新日志";
      toggle.setAttribute("aria-expanded", String(expanded));
      pagination.hidden = !expanded || pageCount <= 1;
      previous.disabled = currentPage === 0;
      next.disabled = currentPage === pageCount - 1;
      status.textContent = `第 ${currentPage + 1} / ${pageCount} 页`;
    };

    toggle.addEventListener("click", () => {
      expanded = !expanded;
      currentPage = 0;
      render();
    });

    const changePage = (delta) => {
      currentPage = Math.max(0, Math.min(pageCount - 1, currentPage + delta));
      render();
      status.focus({ preventScroll: true });
      if (list.getBoundingClientRect().top < 0) {
        list.closest(".changelog-block").scrollIntoView({ block: "start" });
      }
    };
    previous.addEventListener("click", () => changePage(-1));
    next.addEventListener("click", () => changePage(1));
    // A browser Back navigation may restore this document from its back-forward cache.
    window.addEventListener("pageshow", (event) => {
      if (event.persisted) {
        expanded = false;
        currentPage = 0;
        render();
      }
    });
    render();
  };

  const mountGiscus = (giscusCfg) => {
    if (!giscusCfg || !giscusCfg.repo || !giscusCfg.repoId) return;
    const container = $("giscusContainer");
    if (!container) return;

    container.innerHTML = "";

    const script = document.createElement("script");
    script.src = "https://giscus.app/client.js";
    script.async = true;
    script.crossOrigin = "anonymous";
    script.setAttribute("data-repo", giscusCfg.repo);
    script.setAttribute("data-repo-id", giscusCfg.repoId);
    script.setAttribute("data-category", giscusCfg.category || "General");
    if (giscusCfg.categoryId) script.setAttribute("data-category-id", giscusCfg.categoryId);
    script.setAttribute("data-mapping", "specific");
    script.setAttribute("data-term", "play-" + gameId);
    script.setAttribute("data-strict", "0");
    script.setAttribute("data-reactions-enabled", "1");
    script.setAttribute("data-emit-metadata", "0");
    script.setAttribute("data-input-position", "top");
    script.setAttribute("data-theme", "dark_dimmed");
    script.setAttribute("data-lang", "zh-CN");
    script.setAttribute("data-loading", "lazy");

    container.appendChild(script);
  };

  const openLightbox = (url) => {
    const lb = $("lightbox");
    const frame = $("lightboxFrame");
    if (!lb || !frame) return;
    frame.src = url;
    lb.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
  };

  const closeLightbox = () => {
    const lb = $("lightbox");
    const frame = $("lightboxFrame");
    if (!lb || !frame) return;
    lb.setAttribute("aria-hidden", "true");
    frame.src = "";
    document.body.style.overflow = "";
  };

  const bindLightbox = (gameUrl) => {
    const frame = $("gameFrame");
    const zoomBtn = $("gameZoomBtn");
    const lb = $("lightbox");
    const lbClose = $("lightboxClose");

    if (frame) {
      frame.addEventListener("click", () => openLightbox(gameUrl));
    }

    if (zoomBtn) {
      zoomBtn.addEventListener("click", () => openLightbox(gameUrl));
    }

    if (lb) {
      lb.addEventListener("click", (e) => {
        if (e.target === lb || e.target === lbClose) closeLightbox();
      });
    }
    if (lbClose) lbClose.addEventListener("click", closeLightbox);

    document.addEventListener("keydown", (e) => {
      if (e.key !== "Escape") return;
      if (lb && lb.getAttribute("aria-hidden") === "false") {
        closeLightbox();
        return;
      }
    });
  };

  const bindLogModal = () => {
    const bg = $("logModalBg");
    const closeBtn = $("logModalClose");
    const closeModal = () => {
      const lm = $("logModal");
      if (lm) {
        lm.setAttribute("aria-hidden", "true");
        document.body.style.overflow = logPreviousOverflow;
        logReturnFocus?.focus();
      }
    };
    if (bg) bg.addEventListener("click", closeModal);
    if (closeBtn) closeBtn.addEventListener("click", closeModal);
    document.addEventListener("keydown", (event) => {
      const modal = $("logModal");
      if (!modal || modal.getAttribute("aria-hidden") !== "false") return;
      if (event.key === "Escape") closeModal();
      if (event.key !== "Tab") return;
      const focusable = [...modal.querySelectorAll('button, a[href], [tabindex="0"]')];
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    });
  };

  const showError = () => {
    const grid = document.querySelector(".play-grid");
    if (grid) grid.style.display = "none";
    const errEl = $("loadError");
    if (errEl) errEl.hidden = false;
  };

  // ---- Main flow ----
  if (!gameId) {
    showError();
    return;
  }

  let data;
  try {
    const res = await fetch("../data/games.json", { cache: "no-store" });
    if (!res.ok) throw new Error("HTTP " + res.status);
    data = await res.json();
  } catch (err) {
    console.error("加载游戏数据失败：", err);
    showError();
    return;
  }

  const game = data && data.games && data.games[gameId];
  if (!game) {
    showError();
    return;
  }

  // Title / subtitle / type
  document.title = (game.title || "游戏") + " · 游戏详情";
  setText("gameTitle", game.title || "");
  setText("gameSubtitle", game.subtitle || "");
  const typeEl = $("gameTypeTag");
  if (typeEl) {
    if (game.type) {
      typeEl.textContent = game.type;
      typeEl.style.display = "";
    } else {
      typeEl.style.display = "none";
    }
  }

  // Game iframe — 用绝对 URL（基于 location.href + ../ 跳出 play/ 目录）
  const gameUrl = resolveFromRepoRoot(game.gameUrl);
  const frame = $("gameFrame");
  if (frame && gameUrl) {
    frame.src = gameUrl;
    bindLightbox(gameUrl);
  }

  bindLogModal();

  // Controls / roadmap / changelog
  renderControls($("controlsList"), game.controls);
  renderRoadmap($("roadmapList"), game.roadmap);
  bindChangelog(game.changelog);

  // Giscus comments
  mountGiscus(game.giscus);
})();
