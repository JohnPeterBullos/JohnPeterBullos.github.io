
document.addEventListener("DOMContentLoaded", () => {
    const navButtons = document.querySelectorAll("[data-page]");
    const pages = document.querySelectorAll(".app-page[data-section]");
    const pageTitle = document.getElementById("current-page-title");

    const titles = {
        dashboard: "Dashboard",
        groups: "Thesis Groups",
        members: "Group Members",
        assign: "Assign Tasks",
        tasks: "Group Tasks"
    };

    function showPage(pageName) {
        const selectedPage = document.querySelector(
            `.app-page[data-section="${pageName}"]`
        );

        if (!selectedPage) {
            console.error("Page not found:", pageName);
            return;
        }

        pages.forEach(page => {
            page.hidden = true;
            page.style.display = "none";
        });

        selectedPage.hidden = false;
        selectedPage.style.display = "block";

        navButtons.forEach(button => {
            const active = button.dataset.page === pageName;

            button.classList.toggle("active", active);

            if (active) {
                button.setAttribute("aria-current", "page");
            } else {
                button.removeAttribute("aria-current");
            }
        });

        if (pageTitle) {
            pageTitle.textContent = titles[pageName];
        }

        updateLeaderNotices();

        console.log("Showing page:", pageName);
        console.log("Page visible:", !selectedPage.hidden);

        window.scrollTo(0, 0);
    }

    function updateLeaderNotices() {
        const sections = [
            {
                sectionId: "member-section",
                notice: "members"
            },
            {
                sectionId: "task-create-section",
                notice: "assign"
            }
        ];

        sections.forEach(({ sectionId, notice }) => {
            const section = document.getElementById(sectionId);
            const message = document.querySelector(
                `[data-leader-notice="${notice}"]`
            );

            if (!section || !message) return;

            message.hidden = !section.hidden;
        });
    }

    navButtons.forEach(button => {
        button.addEventListener("click", () => {
            showPage(button.dataset.page);
        });
    });

    const leaderSections = [
        document.getElementById("member-section"),
        document.getElementById("task-create-section")
    ].filter(Boolean);

    if (leaderSections.length) {
        const observer = new MutationObserver(updateLeaderNotices);

        leaderSections.forEach(section => {
            observer.observe(section, {
                attributes: true,
                attributeFilter: ["hidden"]
            });
        });
    }

    showPage("dashboard");
});
