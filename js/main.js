document.addEventListener("DOMContentLoaded", () => {
  const navToggle = document.querySelector(".nav-toggle");
  const navLinks = document.querySelector(".nav-links");
  const filterButtons = document.querySelectorAll(".filter-btn");
  const gameCards = document.querySelectorAll(".game-card");
  const playButtons = document.querySelectorAll(".play-btn");
  const modal = document.querySelector("#gameModal");
  const modalTitle = document.querySelector("#modalTitle");
  const gameFrame = document.querySelector("#gameFrame");
  const closeModalButtons = document.querySelectorAll("[data-close-modal]");
  const avatarTrigger = document.querySelector(".avatar-preview-trigger");
  const avatarModal = document.getElementById("avatarModal");
  const avatarCloseEls = document.querySelectorAll("[data-avatar-close]");
  const emailAddress = "huixiang4869@126.com";

  // Mobile navigation menu.
  navToggle.addEventListener("click", () => {
    const isOpen = navLinks.classList.toggle("is-open");
    navToggle.setAttribute("aria-expanded", String(isOpen));
  });

  navLinks.addEventListener("click", (event) => {
    if (event.target.tagName === "A") {
      navLinks.classList.remove("is-open");
      navToggle.setAttribute("aria-expanded", "false");
    }
  });

  function closeAvatarModal() {
    if (!avatarModal) return;
    avatarModal.classList.remove("show");
    avatarModal.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
  }

  if (avatarTrigger && avatarModal) {
    avatarTrigger.addEventListener("click", () => {
      avatarModal.classList.add("show");
      avatarModal.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
    });

    avatarCloseEls.forEach((el) => {
      el.addEventListener("click", closeAvatarModal);
    });

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && avatarModal.classList.contains("show")) {
        closeAvatarModal();
      }
    });
  }

  // Email copy popover. It avoids mailto navigation and keeps the contact text compact.
  const existingEmailLinks = document.querySelectorAll('.contact-card .contact-list a[href^="mailto:"]');
  const hasStaticEmailCopy = document.getElementById("emailText");
  if (hasStaticEmailCopy) {
    existingEmailLinks.forEach((link) => link.remove());
  } else if (existingEmailLinks.length > 0) {
    const existingEmailLink = existingEmailLinks[0];
    const wrapper = document.createElement("div");
    wrapper.className = "email-copy-wrapper";
    wrapper.innerHTML = `
      <span class="email-text" id="emailText">Email: ${emailAddress}</span>
      <button class="copy-tooltip" id="copyEmailBtn" type="button">复制邮箱</button>
    `;
    existingEmailLink.replaceWith(wrapper);
  }

  const emailText = document.getElementById("emailText");
  const copyEmailBtn = document.getElementById("copyEmailBtn");

  if (emailText && copyEmailBtn) {
    const resetCopyTooltip = () => {
      copyEmailBtn.classList.remove("show");
      copyEmailBtn.textContent = "复制邮箱";
    };

    emailText.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      copyEmailBtn.classList.add("show");
    });

    copyEmailBtn.addEventListener("click", async (event) => {
      event.stopPropagation();

      try {
        await navigator.clipboard.writeText(emailAddress);
        copyEmailBtn.textContent = "已复制";
      } catch (error) {
        copyEmailBtn.textContent = "复制失败";
      }

      setTimeout(resetCopyTooltip, 800);
    });

    document.addEventListener("click", resetCopyTooltip);
  }

  // Filter game cards by the values stored in data-category.
  filterButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const filter = button.dataset.filter;

      filterButtons.forEach((item) => item.classList.remove("active"));
      button.classList.add("active");

      gameCards.forEach((card) => {
        const categories = card.dataset.category || "";
        const shouldShow = filter === "全部" || categories.includes(filter);
        card.classList.toggle("is-hidden", !shouldShow);
      });
    });
  });

  // Open the game in a new full-screen browser tab instead of the in-page modal.
  // (The modal markup is kept in index.html for future use, but play buttons no longer trigger it.)
  playButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const url = button.dataset.gameUrl;
      if (!url) return;
      window.open(url, "_blank", "noopener,noreferrer");
    });
  });

  function closeModal() {
    modal.classList.remove("is-open");
    modal.setAttribute("aria-hidden", "true");
    gameFrame.src = "";
    document.body.classList.remove("modal-open");
  }

  closeModalButtons.forEach((button) => {
    button.addEventListener("click", closeModal);
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && modal.classList.contains("is-open")) {
      closeModal();
    }
  });
});
