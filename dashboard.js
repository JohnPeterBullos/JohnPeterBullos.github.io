
import { supabase } from "./supabase.js";

const $ = id => document.getElementById(id);

const userEmail = $("user-email");
const logoutBtn = $("logout-btn");

const groupForm = $("create-group-form");
const groupName = $("group-name");
const thesisTitle = $("thesis-title");
const createGroupBtn = $("create-group-btn");
const groupMessage = $("group-message");
const groupsList = $("groups-list");

const memberSection = $("member-section");
const memberForm = $("add-member-form");
const memberGroup = $("member-group");
const memberEmail = $("member-email");
const addMemberBtn = $("add-member-btn");
const memberMessage = $("member-message");

const taskCreateSection = $("task-create-section");
const taskForm = $("create-task-form");
const taskGroup = $("task-group");
const taskTitle = $("task-title");
const taskDescription = $("task-description");
const taskAssignee = $("task-assignee");
const taskDueDate = $("task-due-date");
const createTaskBtn = $("create-task-btn");
const taskMessage = $("task-message");

const filterGroup = $("filter-group");
const filterStatus = $("filter-status");
const tasksList = $("tasks-list");

const statPending = $("stat-pending");
const statProgress = $("stat-progress");
const statCompleted = $("stat-completed");

let currentUser;
let groups = [];
let allTasks = [];
let leaderGroupIds = new Set();

const statuses = {
    todo: "Pending",
    in_progress: "In Progress",
    done: "Completed"
};

function createElement(tag, text = "", className = "") {
    const el = document.createElement(tag);
    el.textContent = text;
    if (className) el.className = className;
    return el;
}

function addOption(select, value, text) {
    const option = new Option(text, value);
    select.add(option);
}

function resetSelect(select, text) {
    select.replaceChildren();
    addOption(select, "", text);
}

function isLeader(groupId) {
    return leaderGroupIds.has(String(groupId));
}

function field(label, input) {
    const wrapper = document.createElement("div");
    const text = createElement("label", label);
    wrapper.append(text, input);
    return wrapper;
}

async function checkUser() {
    const { data, error } = await supabase.auth.getUser();

    if (error || !data.user) {
        location.replace("./index.html");
        return;
    }

    currentUser = data.user;
    userEmail.textContent = `Logged in as: ${currentUser.email}`;

    await refreshDashboard();
}

async function refreshDashboard() {
    await loadGroups();
    await loadTasks();
}

groupForm.addEventListener("submit", async e => {
    e.preventDefault();

    const name = groupName.value.trim();
    const thesis_title = thesisTitle.value.trim();

    if (!currentUser || !name || !thesis_title) return;

    createGroupBtn.disabled = true;
    groupMessage.textContent = "Creating group...";

    try {
        const { error } = await supabase.from("groups").insert({
            name,
            thesis_title,
            description: "",
            research_stage: "Planning",
            created_by: currentUser.id
        });

        if (error) throw error;

        groupForm.reset();
        groupMessage.textContent = "Group created successfully!";
        await refreshDashboard();

    } catch (error) {
        groupMessage.textContent = error.message;
    } finally {
        createGroupBtn.disabled = false;
    }
});

async function loadGroups() {
    groupsList.textContent = "Loading groups...";

    const { data, error } = await supabase
        .from("groups")
        .select("id, name, thesis_title, created_by")
        .order("created_at", { ascending: false });

    if (error) {
        groupsList.textContent = error.message;
        return;
    }

    groups = data || [];

    leaderGroupIds = new Set(
        groups
            .filter(group => group.created_by === currentUser.id)
            .map(group => String(group.id))
    );

    const hasLeaderGroup = leaderGroupIds.size > 0;

    memberSection.hidden = !hasLeaderGroup;
    taskCreateSection.hidden = !hasLeaderGroup;

    resetSelect(memberGroup, "Select Group");
    resetSelect(taskGroup, "Select Group");

    const selectedGroup = filterGroup.value;

    filterGroup.replaceChildren();
    addOption(filterGroup, "all", "All Groups");

    groups.forEach(group => {
        addOption(filterGroup, group.id, group.name);

        if (isLeader(group.id)) {
            addOption(memberGroup, group.id, group.name);
            addOption(taskGroup, group.id, group.name);
        }
    });

    if (groups.some(group => String(group.id) === selectedGroup)) {
        filterGroup.value = selectedGroup;
    }

    resetSelect(taskAssignee, "Select Member");
    taskAssignee.disabled = true;

    groupsList.replaceChildren();

    if (!groups.length) {
        groupsList.textContent = "You haven't created or joined a thesis group yet.";
        return;
    }

    groups.forEach(group => {
        const card = createElement("div", "", "group-card");
        const members = createElement("div", "Loading members...", "members-list");

        card.append(
            createElement("h3", group.name),
            createElement("p", `Thesis: ${group.thesis_title || "Not specified"}`),
            createElement("p", `Your Role: ${isLeader(group.id) ? "Group Leader" : "Member"}`),
            createElement("h4", "Members"),
            members
        );

        groupsList.append(card);
        loadMembers(group.id, members);
    });
}

async function loadMembers(groupId, container) {
    const { data, error } = await supabase
        .from("group_members")
        .select("user_id, role, profiles(full_name)")
        .eq("group_id", groupId);

    if (error) {
        container.textContent = error.message;
        return;
    }

    container.replaceChildren();

    if (!data?.length) {
        container.textContent = "No members found.";
        return;
    }

    data.forEach(member => {
        const row = createElement("div", "", "member-row");

        row.append(
            createElement("span", member.profiles?.full_name || "Unnamed User"),
            createElement("span", member.role === "admin" ? "Leader" : "Member", "member-role")
        );

        container.append(row);
    });
}

memberForm.addEventListener("submit", async e => {
    e.preventDefault();

    const groupId = memberGroup.value;
    const email = memberEmail.value.trim();

    if (!isLeader(groupId) || !email) {
        memberMessage.textContent = "Select your group and enter an email.";
        return;
    }

    addMemberBtn.disabled = true;
    memberMessage.textContent = "Adding member...";

    try {
        const { error } = await supabase.rpc("add_member_by_email", {
            p_group_id: groupId,
            p_email: email
        });

        if (error) throw error;

        memberEmail.value = "";
        memberMessage.textContent = "Member added successfully!";

        await loadGroups();

        if (taskGroup.value === groupId) {
            await loadTaskMembers(groupId);
        }

    } catch (error) {
        memberMessage.textContent = error.message;
    } finally {
        addMemberBtn.disabled = false;
    }
});

async function loadTaskMembers(groupId) {
    resetSelect(taskAssignee, "Select Member");
    taskAssignee.disabled = true;

    if (!groupId || !isLeader(groupId)) return;

    const { data, error } = await supabase
        .from("group_members")
        .select("user_id, profiles(full_name)")
        .eq("group_id", groupId);

    if (error) {
        taskMessage.textContent = error.message;
        return;
    }

    (data || []).forEach(member => {
        addOption(
            taskAssignee,
            member.user_id,
            member.profiles?.full_name || "Unnamed User"
        );
    });

    taskAssignee.disabled = false;
}

taskGroup.addEventListener("change", () => {
    loadTaskMembers(taskGroup.value);
});

taskForm.addEventListener("submit", async e => {
    e.preventDefault();

    const groupId = taskGroup.value;
    const title = taskTitle.value.trim();
    const assignedTo = taskAssignee.value;

    if (!isLeader(groupId)) {
        taskMessage.textContent = "Only the group leader can assign tasks.";
        return;
    }

    if (!title || !assignedTo) {
        taskMessage.textContent = "Enter a title and select a member.";
        return;
    }

    createTaskBtn.disabled = true;
    taskMessage.textContent = "Assigning task...";

    try {
        const { error } = await supabase.from("tasks").insert({
            group_id: groupId,
            title,
            description: taskDescription.value.trim(),
            assigned_to: assignedTo,
            due_date: taskDueDate.value || null,
            status: "todo",
            priority: "medium",
            chapter: "General Tasks",
            created_by: currentUser.id
        });

        if (error) throw error;

        taskTitle.value = "";
        taskDescription.value = "";
        taskDueDate.value = "";
        taskAssignee.value = "";

        taskMessage.textContent = "Task assigned successfully!";
        await loadTasks();

    } catch (error) {
        taskMessage.textContent = error.message;
    } finally {
        createTaskBtn.disabled = false;
    }
});

function updateStatistics() {
    statPending.textContent = allTasks.filter(task => task.status === "todo").length;
    statProgress.textContent = allTasks.filter(task => task.status === "in_progress").length;
    statCompleted.textContent = allTasks.filter(task => task.status === "done").length;
}

async function loadTasks() {
    tasksList.textContent = "Loading tasks...";

    const { data, error } = await supabase
        .from("tasks")
        .select(`
            id, group_id, created_by, title, description,
            assigned_to, status, due_date, created_at,
            groups(name),
            profiles!tasks_assigned_to_fkey(full_name)
        `)
        .order("created_at", { ascending: false });

    if (error) {
        tasksList.textContent = error.message;
        return;
    }

    allTasks = data || [];
    updateStatistics();
    renderTasks();
}

function renderTasks() {
    const groupId = filterGroup.value;
    const status = filterStatus.value;

    const visibleTasks = allTasks.filter(task =>
        (groupId === "all" || String(task.group_id) === groupId) &&
        (status === "all" || task.status === status)
    );

    tasksList.replaceChildren();

    if (!visibleTasks.length) {
        tasksList.textContent = allTasks.length
            ? "No matching tasks."
            : "No tasks assigned yet.";
        return;
    }

    visibleTasks.forEach(renderTaskCard);
}

function renderTaskCard(task) {
    const card = createElement("div", "", "task-card");
    const leader = isLeader(task.group_id);
    const assignedToMe = task.assigned_to === currentUser.id;

    card.append(
        createElement("h3", task.title),
        createElement("p", `Group: ${task.groups?.name || "Unknown Group"}`),
        createElement("p", task.description || "No description"),
        createElement("p", `Assigned To: ${task.profiles?.full_name || "Unnamed User"}`),
        createElement("p", `Deadline: ${task.due_date || "Not set"}`)
    );

    const badges = createElement("div", "", "task-badges");

    badges.append(
        createElement(
            "span",
            statuses[task.status] || task.status,
            `task-status status-${task.status}`
        )
    );

    card.append(badges);

    if (leader || assignedToMe) {
        const select = document.createElement("select");
        select.className = "task-status-select";

        Object.entries(statuses).forEach(([value, label]) => {
            addOption(select, value, label);
        });

        select.value = task.status;

        select.addEventListener("change", async () => {
            const previous = task.status;
            select.disabled = true;

            const { data, error } = await supabase
                .from("tasks")
                .update({ status: select.value })
                .eq("id", task.id)
                .select("id");

            if (error || !data?.length) {
                alert(error?.message || "Status update not allowed.");
                select.value = previous;
                select.disabled = false;
                return;
            }

            await loadTasks();
        });

        card.append(createElement("label", "Update Status"), select);
    }

    if (leader) {
        const actions = createElement("div", "", "task-actions");

        const editBtn = createElement("button", "Edit Task", "task-edit-btn");
        const deleteBtn = createElement("button", "Delete Task", "task-delete-btn");

        editBtn.type = "button";
        deleteBtn.type = "button";

        editBtn.onclick = () => showEditTask(task, card);

        deleteBtn.onclick = async () => {
            if (!confirm(`Delete "${task.title}"?`)) return;

            deleteBtn.disabled = true;

            const { data, error } = await supabase
                .from("tasks")
                .delete()
                .eq("id", task.id)
                .select("id");

            if (error || !data?.length) {
                alert(error?.message || "Delete not allowed.");
                deleteBtn.disabled = false;
                return;
            }

            await loadTasks();
        };

        actions.append(editBtn, deleteBtn);
        card.append(actions);
    }

    tasksList.append(card);
}

async function showEditTask(task, card) {
    if (!isLeader(task.group_id) || card.querySelector(".task-edit-form")) return;

    const { data, error } = await supabase
        .from("group_members")
        .select("user_id, profiles(full_name)")
        .eq("group_id", task.group_id);

    if (error) {
        alert(error.message);
        return;
    }

    const form = document.createElement("form");
    form.className = "task-edit-form";

    const titleInput = document.createElement("input");
    titleInput.type = "text";
    titleInput.value = task.title;
    titleInput.required = true;

    const descriptionInput = document.createElement("textarea");
    descriptionInput.value = task.description || "";

    const assigneeSelect = document.createElement("select");
    addOption(assigneeSelect, "", "Unassigned");

    (data || []).forEach(member => {
        addOption(
            assigneeSelect,
            member.user_id,
            member.profiles?.full_name || "Unnamed User"
        );
    });

    assigneeSelect.value = task.assigned_to || "";

    const dueInput = document.createElement("input");
    dueInput.type = "date";
    dueInput.value = task.due_date || "";

    const saveBtn = createElement("button", "Save Changes", "task-save-btn");
    saveBtn.type = "submit";

    const cancelBtn = createElement("button", "Cancel", "task-cancel-btn");
    cancelBtn.type = "button";

    const feedback = createElement("p");

    form.append(
        createElement("h4", "Edit Task"),
        field("Task Title", titleInput),
        field("Description", descriptionInput),
        field("Assign To", assigneeSelect),
        field("Deadline", dueInput),
        saveBtn,
        cancelBtn,
        feedback
    );

    card.append(form);

    cancelBtn.onclick = () => form.remove();

    form.addEventListener("submit", async e => {
        e.preventDefault();

        const title = titleInput.value.trim();
        if (!title) return;

        saveBtn.disabled = true;
        feedback.textContent = "Saving...";

        const { data, error } = await supabase
            .from("tasks")
            .update({
                title,
                description: descriptionInput.value.trim(),
                assigned_to: assigneeSelect.value || null,
                due_date: dueInput.value || null
            })
            .eq("id", task.id)
            .select("id");

        if (error || !data?.length) {
            feedback.textContent = error?.message || "Update not allowed.";
            saveBtn.disabled = false;
            return;
        }

        await loadTasks();
    });
}

filterGroup.addEventListener("change", renderTasks);
filterStatus.addEventListener("change", renderTasks);

logoutBtn.addEventListener("click", async () => {
    const { error } = await supabase.auth.signOut();

    if (error) {
        alert(error.message);
        return;
    }

    location.replace("./index.html");
});

checkUser();
