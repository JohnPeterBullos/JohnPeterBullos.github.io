
import { supabase } from "./supabase.js";

const loginTab = document.getElementById("login-tab");
const registerTab = document.getElementById("register-tab");
const nameField = document.getElementById("name-field");
const fullName = document.getElementById("full-name");
const submitBtn = document.getElementById("submit-btn");
const message = document.getElementById("message");
const form = document.getElementById("auth-form");

let isRegister = false;

// LOGIN TAB
loginTab.addEventListener("click", () => {
    isRegister = false;

    loginTab.classList.add("active");
    registerTab.classList.remove("active");

    nameField.style.display = "none";
    fullName.required = false;

    submitBtn.textContent = "Login";
    message.textContent = "";
});

// REGISTER TAB
registerTab.addEventListener("click", () => {
    isRegister = true;

    registerTab.classList.add("active");
    loginTab.classList.remove("active");

    nameField.style.display = "block";
    fullName.required = true;

    submitBtn.textContent = "Register";
    message.textContent = "";
});

// REGISTER AND LOGIN
form.addEventListener("submit", async (event) => {
    event.preventDefault();

    const email = document.getElementById("email").value.trim();
    const password = document.getElementById("password").value;

    message.textContent = "Please wait...";
    submitBtn.disabled = true;

    try {
        if (isRegister) {
            const name = fullName.value.trim();

            if (!name) {
                throw new Error("Please enter your full name.");
            }

            const { data, error } = await supabase.auth.signUp({
                email: email,
                password: password,
                options: {
                    data: {
                        full_name: name
                    }
                }
            });

            if (error) throw error;

         if (data.session) {
    window.location.replace("./dashboard.html");
} else {
    message.textContent =
        "Registration submitted. Check your email if confirmation is required.";
}
        } else {
            const { error } = await supabase.auth.signInWithPassword({
                email: email,
                password: password
            });

            if (error) throw error;

            window.location.replace("./dashboard.html");
        }

    } catch (error) {
        message.textContent = error.message;
    } finally {
        submitBtn.disabled = false;
    }
});
