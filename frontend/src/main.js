import { Elm } from "./Main.elm";
import initWasm, { calculate_goal_json } from "../../wasm/pkg/bywhen_engine.js";
import "./style.css";

const app = Elm.Main.init({
  node: document.getElementById("app"),
  flags: { today: new Date().toLocaleDateString("en-CA") },
});

let engineReady;
app.ports.calculateGoal.subscribe(async (request) => {
  try {
    engineReady ??= initWasm();
    await engineReady;
    app.ports.calculationReceived.send(JSON.parse(calculate_goal_json(JSON.stringify(request))));
  } catch (error) {
    console.error("Unable to load the local calculation engine", error);
    app.ports.calculationReceived.send({
      ok: false,
      error: "The local calculation engine could not start. Refresh the page and try again.",
    });
  }
});

const LOCAL_GOALS_KEY = "bywhen.goals.v1";
const LEGACY_GOALS_KEY = "how-long-until.goals.v1";
const readGoals = () => {
  try {
    const stored = localStorage.getItem(LOCAL_GOALS_KEY) || localStorage.getItem(LEGACY_GOALS_KEY) || "[]";
    return JSON.parse(stored);
  }
  catch { return []; }
};

app.ports.requestLocalGoals.subscribe(() => app.ports.localGoalsReceived.send(readGoals()));
app.ports.saveLocalGoal.subscribe((goal) => {
  const goals = readGoals();
  const updated = [goal, ...goals.filter((item) => item.id !== goal.id)].slice(0, 100);
  localStorage.setItem(LOCAL_GOALS_KEY, JSON.stringify(updated));
  app.ports.localGoalsReceived.send(updated);
});
app.ports.copyResult.subscribe(async (summary) => {
  try { await navigator.clipboard.writeText(summary); }
  catch { /* Clipboard access can be unavailable in non-secure local contexts. */ }
});
const reportNetwork = () => app.ports.networkStatus.send(navigator.onLine);
window.addEventListener("online", reportNetwork);
window.addEventListener("offline", reportNetwork);
reportNetwork();

const API_URL = import.meta.env.VITE_API_URL || "http://127.0.0.1:4000";
app.ports.createSharedGoal.subscribe(async (goal) => {
  try {
    const response = await fetch(`${API_URL}/api/goals`, {
      method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(goal),
    });
    if (!response.ok) throw new Error(`Share API returned ${response.status}`);
    const { id } = await response.json();
    const url = new URL(location.href); url.search = ""; url.searchParams.set("goal", id);
    await navigator.clipboard.writeText(url.toString());
    app.ports.sharedGoalCreated.send(url.toString());
  } catch (error) {
    console.warn("Unable to create share link", error);
    app.ports.sharedGoalCreated.send("");
  }
});

const sharedId = new URL(location.href).searchParams.get("goal");
if (sharedId && /^[a-z0-9]{5,16}$/.test(sharedId)) {
  fetch(`${API_URL}/api/goals/${sharedId}`)
    .then((response) => response.ok ? response.json() : Promise.reject(new Error("Shared goal not found")))
    .then((goal) => app.ports.sharedGoalReceived.send(goal))
    .catch((error) => console.warn("Unable to load shared goal", error));
}

if ("serviceWorker" in navigator && import.meta.env.PROD) {
  window.addEventListener("load", () => navigator.serviceWorker.register("/service-worker.js"));
}
