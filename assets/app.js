const QUIZ_LENGTH = 15;
const STORAGE_KEYS = {
  attempts: "econ-millionaire-attempts",
  sourcePrefs: "econ-millionaire-source-prefs",
  flags: "econ-millionaire-flags"
};
const LADDER = [
  "£100",
  "£200",
  "£300",
  "£500",
  "£1,000",
  "£2,000",
  "£4,000",
  "£8,000",
  "£16,000",
  "£32,000",
  "£64,000",
  "£125,000",
  "£250,000",
  "£500,000",
  "£1,000,000"
];

const state = {
  allQuestions: [],
  allPapers: [],
  enabledPaperIds: new Set(),
  quizQuestions: [],
  currentIndex: 0,
  score: 0,
  selectedAnswer: null,
  lifelines: {
    fifty: true,
    audience: true,
    switch: true,
    second: true
  },
  secondChanceActive: false,
  currentQuizId: ""
};

const el = {
  answerGrid: document.querySelector("#answer-grid"),
  answerTemplate: document.querySelector("#answer-template"),
  feedbackCard: document.querySelector("#feedback-card"),
  feedbackStatus: document.querySelector("#feedback-status"),
  feedbackExplanation: document.querySelector("#feedback-explanation"),
  paperLink: document.querySelector("#paper-link"),
  jstorLink: document.querySelector("#jstor-link"),
  nextQuestion: document.querySelector("#next-question"),
  questionText: document.querySelector("#question-text"),
  questionCount: document.querySelector("#question-count"),
  questionTopic: document.querySelector("#question-topic"),
  scoreValue: document.querySelector("#score-value"),
  resultsCard: document.querySelector("#results-card"),
  resultsHeading: document.querySelector("#results-heading"),
  resultsSummary: document.querySelector("#results-summary"),
  reviewList: document.querySelector("#review-list"),
  historyList: document.querySelector("#history-list"),
  ladderList: document.querySelector("#ladder-list"),
  quizStamp: document.querySelector("#quiz-stamp"),
  openSettings: document.querySelector("#open-settings"),
  settingsDialog: document.querySelector("#settings-dialog"),
  sourceList: document.querySelector("#source-list"),
  sourceSummary: document.querySelector("#source-summary"),
  flagQuestion: document.querySelector("#flag-question"),
  reviewAttempt: document.querySelector("#review-attempt"),
  installApp: document.querySelector("#install-app"),
  exportHistory: document.querySelector("#export-history"),
  lifelineFifty: document.querySelector("#lifeline-fifty"),
  lifelineAudience: document.querySelector("#lifeline-audience"),
  lifelineSwitch: document.querySelector("#lifeline-switch"),
  lifelineSecond: document.querySelector("#lifeline-second")
};

let deferredPrompt = null;

boot().catch((error) => {
  console.error(error);
  el.questionText.textContent = "The quiz could not load. Please refresh to try again.";
});

async function boot() {
  const [questions, papers] = await Promise.all([
    fetchJSON("./data/questions.json"),
    fetchJSON("./data/papers.json")
  ]);
  state.allQuestions = questions;
  state.allPapers = papers;
  hydrateSourcePreferences();
  renderLadder();
  renderSources();
  setupEvents();
  await registerPwa();
  startWeeklyQuiz();
  renderHistory();
}

async function fetchJSON(path) {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`Failed to load ${path}`);
  }
  return response.json();
}

function hydrateSourcePreferences() {
  const saved = JSON.parse(localStorage.getItem(STORAGE_KEYS.sourcePrefs) || "[]");
  const overrides = new Set(saved);
  state.enabledPaperIds = new Set(
    state.allPapers
      .filter((paper) => (saved.length ? overrides.has(paper.id) : paper.enabled !== false))
      .map((paper) => paper.id)
  );
}

function setupEvents() {
  el.nextQuestion.addEventListener("click", advanceQuiz);
  el.openSettings.addEventListener("click", () => {
    el.settingsDialog.showModal();
    el.openSettings.setAttribute("aria-expanded", "true");
  });
  el.settingsDialog.addEventListener("close", () => {
    el.openSettings.setAttribute("aria-expanded", "false");
  });
  el.flagQuestion.addEventListener("click", flagCurrentQuestion);
  el.reviewAttempt.addEventListener("click", renderReview);
  el.exportHistory.addEventListener("click", exportHistory);
  el.lifelineFifty.addEventListener("click", useFiftyFifty);
  el.lifelineAudience.addEventListener("click", useAudiencePoll);
  el.lifelineSwitch.addEventListener("click", useSwitchQuestion);
  el.lifelineSecond.addEventListener("click", useSecondChance);
  window.addEventListener("beforeinstallprompt", (event) => {
    event.preventDefault();
    deferredPrompt = event;
    el.installApp.classList.remove("hidden");
  });
  el.installApp.addEventListener("click", async () => {
    if (!deferredPrompt) {
      return;
    }
    deferredPrompt.prompt();
    await deferredPrompt.userChoice;
    deferredPrompt = null;
    el.installApp.classList.add("hidden");
  });
}

function startWeeklyQuiz() {
  state.currentQuizId = currentQuizId();
  el.quizStamp.textContent = `Week of ${formatWeekLabel()} • ${state.currentQuizId}`;
  const previousAttempt = getAttempts().find((attempt) => attempt.quizId === state.currentQuizId);
  if (previousAttempt) {
    lockToPreviousAttempt(previousAttempt);
    return;
  }

  resetRuntimeState();
  state.quizQuestions = buildWeeklyQuestionSet();
  renderQuestion();
}

function currentQuizId() {
  const now = new Date();
  const current = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const day = current.getUTCDay() || 7;
  current.setUTCDate(current.getUTCDate() - day + 1);
  return `quiz-${current.toISOString().slice(0, 10)}`;
}

function formatWeekLabel() {
  const [_, date] = currentQuizId().split("quiz-");
  return new Date(date).toLocaleDateString(undefined, {
    year: "numeric",
    month: "long",
    day: "numeric"
  });
}

function buildWeeklyQuestionSet() {
  const enabledQuestions = state.allQuestions.filter((question) =>
    state.enabledPaperIds.has(question.paperId)
  );
  const deduped = [...enabledQuestions];
  const seeded = seededShuffle(deduped, state.currentQuizId);
  return seeded.slice(0, QUIZ_LENGTH);
}

function seededShuffle(items, seedString) {
  const seed = hashCode(seedString);
  const copy = [...items];
  let random = mulberry32(seed);
  for (let index = copy.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(random() * (index + 1));
    [copy[index], copy[swapIndex]] = [copy[swapIndex], copy[index]];
  }
  return copy;
}

function renderQuestion() {
  const question = state.quizQuestions[state.currentIndex];
  if (!question) {
    finishQuiz();
    return;
  }

  el.feedbackCard.classList.add("hidden");
  el.resultsCard.classList.add("hidden");
  el.reviewList.classList.add("hidden");
  el.answerGrid.innerHTML = "";
  el.questionCount.textContent = `Question ${state.currentIndex + 1} of ${QUIZ_LENGTH}`;
  el.questionTopic.textContent = question.topic;
  el.questionText.textContent = question.prompt;
  el.scoreValue.textContent = `${state.score} / ${QUIZ_LENGTH}`;
  updateLadder();

  question.answers.forEach((answer, index) => {
    const node = el.answerTemplate.content.firstElementChild.cloneNode(true);
    node.dataset.answerId = answer.id;
    node.querySelector(".answer-letter").textContent = String.fromCharCode(65 + index);
    node.querySelector(".answer-text").textContent = answer.text;
    node.addEventListener("click", () => submitAnswer(answer.id));
    el.answerGrid.appendChild(node);
  });
}

function submitAnswer(answerId) {
  const question = state.quizQuestions[state.currentIndex];
  const selected = question.answers.find((answer) => answer.id === answerId);
  if (!selected || el.feedbackCard.classList.contains("hidden") === false) {
    return;
  }

  if (state.secondChanceActive && !selected.correct) {
    state.secondChanceActive = false;
    state.lifelines.second = false;
    updateLifelineButtons();
    pulseFeedback("Incorrect. Your second chance is still alive, so choose again.");
    markSelection(answerId, false, true);
    return;
  }

  const correct = Boolean(selected.correct);
  if (correct) {
    state.score += 1;
  }
  markSelection(answerId, correct, false);
  revealFeedback(question, correct, answerId);
}

function markSelection(answerId, correct, temporary) {
  [...el.answerGrid.children].forEach((button) => {
    const matches = button.dataset.answerId === answerId;
    button.disabled = temporary;
    button.classList.toggle("is-selected", matches);
    if (temporary) {
      button.classList.toggle("is-wrong", matches);
      setTimeout(() => {
        button.classList.remove("is-selected", "is-wrong");
        [...el.answerGrid.children].forEach((innerButton) => {
          innerButton.disabled = false;
        });
      }, 900);
      return;
    }
    const answer = state.quizQuestions[state.currentIndex].answers.find(
      (item) => item.id === button.dataset.answerId
    );
    button.disabled = true;
    button.classList.toggle("is-correct", Boolean(answer.correct));
    button.classList.toggle("is-wrong", matches && !correct);
  });
}

function revealFeedback(question, correct, chosenAnswerId) {
  el.feedbackCard.classList.remove("hidden");
  el.feedbackStatus.textContent = correct ? "Correct answer" : "Not quite";
  el.feedbackExplanation.textContent = question.explanation;
  el.paperLink.href = question.sourceUrl;
  el.jstorLink.href = question.jstorUrl || "#";
  el.jstorLink.classList.toggle("hidden", !question.jstorUrl);
  const chosenAnswer = question.answers.find((answer) => answer.id === chosenAnswerId);
  question.userAnswerId = chosenAnswerId;
  question.wasCorrect = correct;
  question.chosenAnswerText = chosenAnswer ? chosenAnswer.text : "";
  state.secondChanceActive = false;
}

function pulseFeedback(message) {
  el.feedbackCard.classList.remove("hidden");
  el.feedbackStatus.textContent = message;
  el.feedbackExplanation.textContent =
    "This lifeline lets you recover from one wrong answer before locking in the result.";
  el.paperLink.href = "#";
  el.jstorLink.classList.add("hidden");
}

function advanceQuiz() {
  const question = state.quizQuestions[state.currentIndex];
  if (typeof question.wasCorrect !== "boolean") {
    return;
  }
  state.currentIndex += 1;
  renderQuestion();
}

function finishQuiz() {
  const attempt = {
    quizId: state.currentQuizId,
    completedAt: new Date().toISOString(),
    score: state.score,
    total: QUIZ_LENGTH,
    questions: state.quizQuestions.map((question) => ({
      id: question.id,
      prompt: question.prompt,
      topic: question.topic,
      chosenAnswerId: question.userAnswerId,
      chosenAnswerText: question.chosenAnswerText,
      correctAnswerText: question.answers.find((answer) => answer.correct)?.text,
      correct: question.wasCorrect,
      sourceUrl: question.sourceUrl,
      jstorUrl: question.jstorUrl || ""
    }))
  };

  saveAttempt(attempt);
  renderHistory();
  el.resultsCard.classList.remove("hidden");
  el.resultsHeading.textContent = `Your score is ${state.score} / ${QUIZ_LENGTH}`;
  el.resultsSummary.textContent =
    state.score === QUIZ_LENGTH
      ? "A flawless run through this week's economics draw."
      : "This weekly set is now locked. Review the sources below and come back next week.";
}

function renderReview() {
  const attempt = getAttempts().find((item) => item.quizId === state.currentQuizId);
  if (!attempt) {
    return;
  }

  el.reviewList.classList.remove("hidden");
  el.reviewList.innerHTML = attempt.questions
    .map(
      (question, index) => `
        <article class="review-card">
          <header>
            <div>
              <p class="status-label">Question ${index + 1}</p>
              <h3>${escapeHtml(question.prompt)}</h3>
            </div>
            <span class="pill">${question.correct ? "Correct" : "Incorrect"}</span>
          </header>
          <p>Your answer: ${escapeHtml(question.chosenAnswerText || "No answer recorded")}</p>
          <p>Correct answer: ${escapeHtml(question.correctAnswerText || "Unavailable")}</p>
          <p><a href="${question.sourceUrl}" target="_blank" rel="noreferrer">Paper link</a></p>
        </article>
      `
    )
    .join("");
}

function renderHistory() {
  const attempts = getAttempts().sort((a, b) => b.completedAt.localeCompare(a.completedAt));
  if (!attempts.length) {
    el.historyList.innerHTML = "<p>No attempts saved on this device yet.</p>";
    return;
  }

  el.historyList.innerHTML = attempts
    .map(
      (attempt) => `
        <article class="history-item">
          <div>
            <p>${new Date(attempt.completedAt).toLocaleString()}</p>
            <p>${attempt.quizId}</p>
          </div>
          <strong>${attempt.score} / ${attempt.total}</strong>
        </article>
      `
    )
    .join("");
}

function renderLadder() {
  el.ladderList.innerHTML = LADDER.map((item, index) => `<li data-step="${index}">${item}</li>`).join("");
}

function updateLadder() {
  [...el.ladderList.children].forEach((node, index) => {
    node.classList.toggle("active", index === state.currentIndex);
  });
}

function renderSources() {
  const enabledCount = state.enabledPaperIds.size;
  el.sourceSummary.textContent = `${enabledCount} papers enabled • ${state.allQuestions.length} generated starter questions`;
  el.sourceList.innerHTML = state.allPapers
    .map(
      (paper) => `
        <label class="source-row">
          <input class="source-toggle" type="checkbox" data-paper-id="${paper.id}" ${
            state.enabledPaperIds.has(paper.id) ? "checked" : ""
          } />
          <div>
            <p><strong>${escapeHtml(paper.title)}</strong></p>
            <p>${escapeHtml(paper.author)} • ${paper.year} • ${escapeHtml(paper.source)}</p>
            <p>${escapeHtml(paper.topic)}</p>
          </div>
        </label>
      `
    )
    .join("");

  [...el.sourceList.querySelectorAll(".source-toggle")].forEach((checkbox) => {
    checkbox.addEventListener("change", (event) => {
      const paperId = event.target.dataset.paperId;
      if (event.target.checked) {
        state.enabledPaperIds.add(paperId);
      } else {
        state.enabledPaperIds.delete(paperId);
      }
      localStorage.setItem(STORAGE_KEYS.sourcePrefs, JSON.stringify([...state.enabledPaperIds]));
      renderSources();
      startWeeklyQuiz();
    });
  });
}

function lockToPreviousAttempt(attempt) {
  el.questionText.textContent = "This week's quiz has already been completed on this device.";
  el.answerGrid.innerHTML = "";
  el.questionCount.textContent = `Question ${QUIZ_LENGTH} of ${QUIZ_LENGTH}`;
  el.questionTopic.textContent = "Attempt locked";
  el.scoreValue.textContent = `${attempt.score} / ${attempt.total}`;
  el.feedbackCard.classList.add("hidden");
  el.resultsCard.classList.remove("hidden");
  el.resultsHeading.textContent = `Your stored score is ${attempt.score} / ${attempt.total}`;
  el.resultsSummary.textContent = "One attempt per weekly quiz is enabled. You can review the saved answers below.";
  renderHistory();
  renderReview();
  disableLifelines();
}

function disableLifelines() {
  Object.keys(state.lifelines).forEach((key) => {
    state.lifelines[key] = false;
  });
  updateLifelineButtons();
}

function resetRuntimeState() {
  state.quizQuestions = [];
  state.currentIndex = 0;
  state.score = 0;
  state.selectedAnswer = null;
  state.lifelines = {
    fifty: true,
    audience: true,
    switch: true,
    second: true
  };
  state.secondChanceActive = false;
  updateLifelineButtons();
}

function updateLifelineButtons() {
  el.lifelineFifty.disabled = !state.lifelines.fifty;
  el.lifelineAudience.disabled = !state.lifelines.audience;
  el.lifelineSwitch.disabled = !state.lifelines.switch;
  el.lifelineSecond.disabled = !state.lifelines.second;
}

function useFiftyFifty() {
  if (!state.lifelines.fifty) {
    return;
  }
  const buttons = [...el.answerGrid.children];
  const wrongButtons = buttons.filter((button) => {
    const answer = currentQuestion().answers.find((item) => item.id === button.dataset.answerId);
    return !answer.correct;
  });
  seededShuffle(wrongButtons, `${state.currentQuizId}-${state.currentIndex}-fifty`)
    .slice(0, 2)
    .forEach((button) => button.classList.add("is-hidden"));
  state.lifelines.fifty = false;
  updateLifelineButtons();
}

function useAudiencePoll() {
  if (!state.lifelines.audience) {
    return;
  }
  const question = currentQuestion();
  const poll = question.answers
    .map((answer, index) => ({
      label: String.fromCharCode(65 + index),
      score: answer.correct ? 62 : 12 + index * 5
    }))
    .sort((a, b) => b.score - a.score)
    .map((entry) => `${entry.label}: ${entry.score}%`)
    .join(" • ");

  el.feedbackCard.classList.remove("hidden");
  el.feedbackStatus.textContent = "Ask the Market";
  el.feedbackExplanation.textContent = `The crowd leans this way: ${poll}`;
  el.paperLink.href = currentQuestion().sourceUrl;
  el.jstorLink.href = currentQuestion().jstorUrl || "#";
  el.jstorLink.classList.toggle("hidden", !currentQuestion().jstorUrl);
  state.lifelines.audience = false;
  updateLifelineButtons();
}

function useSwitchQuestion() {
  if (!state.lifelines.switch) {
    return;
  }
  const currentId = currentQuestion().id;
  const alternatives = state.allQuestions.filter(
    (question) =>
      state.enabledPaperIds.has(question.paperId) &&
      !state.quizQuestions.some((existing) => existing.id === question.id) &&
      question.id !== currentId
  );
  const replacement = seededShuffle(alternatives, `${state.currentQuizId}-${state.currentIndex}-switch`)[0];
  if (!replacement) {
    return;
  }
  state.quizQuestions[state.currentIndex] = replacement;
  state.lifelines.switch = false;
  updateLifelineButtons();
  renderQuestion();
}

function useSecondChance() {
  if (!state.lifelines.second) {
    return;
  }
  state.secondChanceActive = true;
  el.feedbackCard.classList.remove("hidden");
  el.feedbackStatus.textContent = "Second Chance armed";
  el.feedbackExplanation.textContent =
    "Your first wrong tap on this question will not lock the answer. Choose carefully.";
  el.paperLink.href = currentQuestion().sourceUrl;
  el.jstorLink.href = currentQuestion().jstorUrl || "#";
  el.jstorLink.classList.toggle("hidden", !currentQuestion().jstorUrl);
}

function flagCurrentQuestion() {
  const question = currentQuestion();
  if (!question) {
    return;
  }
  const flags = JSON.parse(localStorage.getItem(STORAGE_KEYS.flags) || "[]");
  flags.push({
    flaggedAt: new Date().toISOString(),
    questionId: question.id,
    prompt: question.prompt
  });
  localStorage.setItem(STORAGE_KEYS.flags, JSON.stringify(flags));

  const issueUrl = new URL("https://github.com/moretownsend/quiz/issues/new");
  issueUrl.searchParams.set("title", `Question flag: ${question.id}`);
  issueUrl.searchParams.set(
    "body",
    [
      `Question ID: ${question.id}`,
      `Prompt: ${question.prompt}`,
      `Paper: ${question.paperTitle}`,
      `Issue noticed: `,
      "",
      `Source URL: ${question.sourceUrl}`
    ].join("\n")
  );
  window.open(issueUrl.toString(), "_blank", "noopener");
}

function currentQuestion() {
  return state.quizQuestions[state.currentIndex];
}

function getAttempts() {
  return JSON.parse(localStorage.getItem(STORAGE_KEYS.attempts) || "[]");
}

function saveAttempt(attempt) {
  const attempts = getAttempts().filter((item) => item.quizId !== attempt.quizId);
  attempts.push(attempt);
  localStorage.setItem(STORAGE_KEYS.attempts, JSON.stringify(attempts));
}

function exportHistory() {
  const blob = new Blob([JSON.stringify(getAttempts(), null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = "econ-millionaire-attempt-history.json";
  anchor.click();
  URL.revokeObjectURL(url);
}

async function registerPwa() {
  if ("serviceWorker" in navigator) {
    await navigator.serviceWorker.register("./sw.js");
  }
}

function hashCode(input) {
  let hash = 0;
  for (let index = 0; index < input.length; index += 1) {
    hash = (hash << 5) - hash + input.charCodeAt(index);
    hash |= 0;
  }
  return hash >>> 0;
}

function mulberry32(seed) {
  return function next() {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function escapeHtml(input) {
  return String(input)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
