# Econ Millionaire

`Econ Millionaire` is a mobile-first quiz PWA inspired by *Who Wants to Be a Millionaire?* It serves 15-question weekly economics quizzes sourced from a configurable catalogue of foundational economics papers and theory texts.

## What is included

- Millionaire-style visual treatment with four answers per question
- One attempt per weekly quiz per browser
- Lifelines: `50:50`, `Ask the Market`, `Switch Paper`, `Second Chance`
- Source reveal after each answer, including a direct paper link and optional JSTOR link
- Browser-local attempt history with timestamp, score, and question log
- Source catalogue settings so you can enable or disable individual papers
- PWA shell for iPhone home-screen installation
- A generated starter bank of `1000` questions

## Data model

- [`data/papers.json`](/Users/morgan/Desktop/Codex/quiz/data/papers.json) is the editable source catalogue.
- [`data/questions.json`](/Users/morgan/Desktop/Codex/quiz/data/questions.json) is generated from the catalogue.
- Attempt history is stored in browser `localStorage`, which keeps each user's data private to their own device/browser.

## Refresh flow

1. Update [`data/papers.json`](/Users/morgan/Desktop/Codex/quiz/data/papers.json) with enabled papers and source URLs.
2. Run [`scripts/generate_questions.rb`](/Users/morgan/Desktop/Codex/quiz/scripts/generate_questions.rb) to rebuild the question bank.
3. Use the included GitHub Actions workflow to regenerate questions weekly.

## Hosting

This app is designed to work well on GitHub Pages because it does not require a runtime backend. If you later want shared user accounts or centralized attempt storage, you would add a hosted backend.
