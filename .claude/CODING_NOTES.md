# Coding Best Practices & Reminders

> **Style rule:** Notes must be clear and concise — 300 characters or less each. Group by topic, not by date. Whenever a PR review (CodeRabbit or human) catches a mistake, add or amend a note here right away so it isn't repeated.

## Credentials & Secrets

- **Never hardcode a real server URL, username, or password as a UI default or fallback value.** The pre-fork version of this app shipped `admin`/a real password pre-filled on the login screen, plus the same real server URL hardcoded as a fallback in 8 files. Defaults must be empty strings; screens should just skip the request if nothing is configured yet.
- The `pre_commit_sp_check.py` hook flags any added line assigning a literal string (single- or double-quoted, including `m.x.y.password = "..."` member-access chains) to a field whose name contains "password". CI's `security` job runs gitleaks on every PR for the same reason.
- Prefer HTTPS by default: `LoginScreen.brs` shows an explicit interstitial warning (cleartext credentials, CWE-319) before logging in over `http://`, requiring the user to confirm rather than silently proceeding.
- **Don't write `curl -u user:PLACEHOLDER_PASSWORD` in docs, even as an obvious placeholder** — gitleaks' `curl-auth-user` rule matches the syntax pattern itself, not whether the value is real, and fails CI on it. Use `curl -u username` alone instead (curl prompts interactively for the password); it's also better practice, not just a CI workaround.

## BrightScript / Roku Task Patterns

- **Never reference an `m.` field in a Task/Screen that was never assigned in `init()`.** BrightScript returns `invalid` for an unset `m.` member instead of erroring at parse time, so `m.someField.visible = false` crashes at runtime, not at review time. Grep for the field name back to its `init()` assignment before trusting it exists.
- `getServerUrl()`/registry-read logic is duplicated near-identically across `LoginScreen.brs`, `SearchScreen.brs`, `DetailsScreen.brs`, `DashboardScreen.brs`, `DashboardTask.brs`, `DetailsTask.brs`, `RequestItem.brs`, `UserItem.brs`. Worth extracting into a shared library (`source/Constants.brs` or similar) next time it needs to change — duplication is exactly how the hardcoded-URL leak spread to 8 files instead of 1.
- `AppScene`'s login/dashboard routing checks `SeerrAuth.serverUrl` existing, not just `connectSid` — a registry with a session cookie but no server URL (partial/corrupted state) must route to login, not into a dashboard that would issue relative `/api/v1/...` requests.
- On any API failure branch, show `resp.body` (truncated), not just `resp.code` — a bare status code gave no way to diagnose a Seerr-side 500 that only happened for this app's requests, not browser logins. `SearchScreen.brs` already did this; `LoginScreen.brs` didn't, until it needed to.
- Don't call `setFocus(true)` on a screen's wrapper node right after `appendChild` if that screen's own `init()` already focused one of its children — the second call re-targets the plain `Group`, which isn't visually focusable, so the first arrow-key press gets eaten by Roku's default focus-recovery instead of your screen's own navigation logic. Found via real "have to scroll before anything selects" feedback on `LoginScreen` (`AppScene.brs::showLogin`).
- A legacy `Dialog` node's `buttons` press only sets `buttonSelected` — it does **not** dismiss the dialog. Always `observeField("buttonSelected", ...)` and explicitly set `dialog.close = true` in the handler, or the dialog stays stuck until Back.

## CI / GitHub Actions

- **Never interpolate a GitHub Actions expression directly into a `run:` shell block** (e.g. `"${{ github.ref_name }}"` inside `bash`) — ref/branch/tag names can contain shell metacharacters (`$()`, backticks) and this is a documented script-injection vector (CWE-78). Pass it through `env:` and reference the env var instead.
- A job using `softprops/action-gh-release` (or anything writing releases/PRs) needs an explicit `permissions: contents: write` block — don't rely on the repo/org default, which can be read-only.
- `release.yml`'s tag-push trigger accepts a tag on any commit, not just one that's actually merged to `main`. It fetches `origin/main` and runs `git merge-base --is-ancestor "$GITHUB_SHA" origin/main` before packaging, failing the job otherwise, so a tag can't bypass the Rule 4 "only tag from main" gate.

## Easter Eggs

- `components/AppScene.brs::onKeyEvent` — press the remote's "rewind" key 5 times within 2 seconds of each other, from any screen (it bubbles up to the Scene only when no focused child handles it). Shows a small thank-you dialog. Not mentioned anywhere user-facing.

## General Style Notes

- Keep lines under 120 characters where practical.
- This project has no automated test framework for BrightScript — Rule 3's "run tests" step means manually sideloading the build and exercising the changed screen before pushing.
