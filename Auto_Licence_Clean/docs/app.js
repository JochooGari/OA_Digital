/* ============================================================
   Auto Licence Clean — Interactions
   ============================================================ */

document.addEventListener("DOMContentLoaded", () => {
  // ── Expand/collapse endpoint details ──────────────
  document.querySelectorAll(".endpoint-row").forEach((row) => {
    row.addEventListener("click", () => {
      const detail = row.nextElementSibling;
      if (detail && detail.classList.contains("endpoint-detail")) {
        detail.classList.toggle("open");
      }
    });
  });

  // ── Expand/collapse API groups ────────────────────
  document.querySelectorAll(".api-group-toggle").forEach((toggle) => {
    toggle.addEventListener("click", (e) => {
      e.preventDefault();
      const group = toggle.closest(".api-group");
      const body = group.querySelector(".api-group-body");
      if (body) {
        body.style.display = body.style.display === "none" ? "block" : "none";
        toggle.textContent = body.style.display === "none" ? "Expand" : "Collapse";
      }
    });
  });

  // ── Copy curl commands ────────────────────────────
  document.querySelectorAll(".copy-btn").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const block = btn.closest(".curl-block");
      const code = block.querySelector("code").textContent;
      navigator.clipboard.writeText(code).then(() => {
        btn.textContent = "Copied!";
        setTimeout(() => (btn.textContent = "Copy"), 1500);
      });
    });
  });

  // ── Sidebar active state on scroll ────────────────
  const sections = document.querySelectorAll(".section[id]");
  const sidebarLinks = document.querySelectorAll(".sidebar a[href^='#']");

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          sidebarLinks.forEach((link) => link.classList.remove("active"));
          const activeLink = document.querySelector(
            `.sidebar a[href="#${entry.target.id}"]`
          );
          if (activeLink) activeLink.classList.add("active");
        }
      });
    },
    { rootMargin: "-120px 0px -60% 0px" }
  );

  sections.forEach((section) => observer.observe(section));

  // ── Smooth scroll for sidebar links ───────────────
  sidebarLinks.forEach((link) => {
    link.addEventListener("click", (e) => {
      e.preventDefault();
      const target = document.querySelector(link.getAttribute("href"));
      if (target) {
        target.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  });

  // ── Environment selector ──────────────────────────
  document.querySelectorAll(".env-selector .badge").forEach((badge) => {
    badge.addEventListener("click", () => {
      document.querySelectorAll(".env-selector .badge").forEach((b) => {
        b.style.opacity = "0.4";
      });
      badge.style.opacity = "1";
    });
  });
});
