/* Play page — 加载游戏数据并渲染 */

(async () => {
  const $ = (id) => document.getElementById(id);
  const params = new URLSearchParams(location.search);
  const gameId = params.get("id");

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
    const lbFrame = $("lightboxFrame");

    if (frame) {
      frame.addEventListener("click", (e) => {
        // Don't open lightbox when clicking inside iframe content; instead let the user
        // explicitly click the "放大全屏" button to avoid stealing focus from the game.
        e.preventDefault();
        openLightbox(gameUrl);
      });
    }

    if (zoomBtn) {
      zoomBtn.addEventListener("click", () => openLightbox(gameUrl));
    }

    if (lb) {
      lb.addEventListener("click", (e) => {
        // Click on backdrop (but not on iframe content) closes the lightbox.
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

  // ---- Main flow ----
  if (!gameId) {
    $("playGrid").setAttribute("aria-busy", "false");
    $("playGrid").hidden = true;
    $("loadError").hidden = false;
    return;
  }

  let data;
  try {
    const res = await fetch("../data/games.json", { cache: "no-store" });
    if (!res.ok) throw new Error("HTTP " + res.status);
    data = await res.json();
  } catch (err) {
    console.error("加载游戏数据失败：", err);
    $("playGrid").setAttribute("aria-busy", "false");
    $("playGrid").hidden = true;
    $("loadError").hidden = false;
    return;
  }

  const game = data && data.games && data.games[gameId];
  if (!game) {
    $("playGrid").setAttribute("aria-busy", "false");
    $("playGrid").hidden = true;
    $("loadError").hidden = false;
    return;
  }

  // Title / subtitle / type
  setText("pageTitle", game.title + " · 游戏详情");
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

  // Game iframe
  const frame = $("gameFrame");
  if (frame && game.gameUrl) {
    frame.src = game.gameUrl;
    bindLightbox(game.gameUrl);
  }

  // Controls / roadmap / changelog
  renderControls($("controlsList"), game.controls);
  renderRoadmap($("roadmapList"), game.roadmap);
  renderChangelog($("changelogList"), game.changelog);

  // Giscus comments
  mountGiscus(game.giscus);

  $("playGrid").setAttribute("aria-busy", "false");
})();