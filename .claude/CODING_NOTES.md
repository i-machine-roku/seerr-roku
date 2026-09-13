# Coding Best Practices & Reminders

> **Style rule:** Notes must be clear and concise — 300 characters or less each. Group by topic, not by date. Whenever a PR review (CodeRabbit or human) catches a mistake, add or amend a note here right away so it isn't repeated.

## Credentials & Secrets

- **Never hardcode a real server URL, username, or password as a UI default or fallback value.** The pre-fork version of this app shipped `admin`/a real password pre-filled on the login screen, plus the same real server URL hardcoded as a fallback in 8 files. Defaults must be empty strings; screens should just skip the request if nothing is configured yet.
- The `pre_commit_sp_check.py` hook now flags any added line assigning a literal string to a field whose name contains "password". CI's `security` job runs gitleaks on every PR for the same reason.

## BrightScript / Roku Task Patterns

- **Never reference an `m.` field in a Task/Screen that was never assigned in `init()`.** BrightScript returns `invalid` for an unset `m.` member instead of erroring at parse time, so `m.someField.visible = false` crashes at runtime, not at review time. Grep for the field name back to its `init()` assignment before trusting it exists.
- `getServerUrl()`/registry-read logic is duplicated near-identically across `LoginScreen.brs`, `SearchScreen.brs`, `DetailsScreen.brs`, `DashboardScreen.brs`, `DashboardTask.brs`, `DetailsTask.brs`, `RequestItem.brs`, `UserItem.brs`. Worth extracting into a shared library (`source/Constants.brs` or similar) next time it needs to change — duplication is exactly how the hardcoded-URL leak spread to 8 files instead of 1.

## Easter Eggs

- `components/AppScene.brs::onKeyEvent` — press the remote's "rewind" key 5 times within 2 seconds of each other, from any screen (it bubbles up to the Scene only when no focused child handles it). Shows a small thank-you dialog. Not mentioned anywhere user-facing.

## General Style Notes

- Keep lines under 120 characters where practical.
- This project has no automated test framework for BrightScript — Rule 3's "run tests" step means manually sideloading the build and exercising the changed screen before pushing.
