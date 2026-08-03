/* Play page — 加载游戏数据并渲染 */

(async () => {
  const $ = (id) => document.getElementById(id);
  const params = new URLSearchParams(location.search);
  const gameId = params.get("id");

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
      listEl.appendChild(li);
    });
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
      if (e.key === "Escape" && lb && lb.getAttribute("aria-hidden") === "false") {
        closeLightbox();
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

  // Controls / roadmap / changelog
  renderControls($("controlsList"), game.controls);
  renderRoadmap($("roadmapList"), game.roadmap);
  renderChangelog($("changelogList"), game.changelog);

  // Giscus comments
  mountGiscus(game.giscus);
})();