# Feedback and idea loop (all min apps)

People send bugs and ideas from **Account → Ideas & bugs** (or Settings → Ideas on spin min). There is no lightbulb on every page — only this Ideas section.

Min Cloud stores the full report, opens a **redacted** GitHub issue on `carambula/myrepo` (no name or email), and pings Cursor so an agent can propose options. You approve or iterate on the issue. When the PR merges, Min Cloud marks the idea shipped and closes the issue.

```
User → POST /v1/feedback → GitHub issue + @mention comment + Cursor webhook
     → triage agent POSTs options → Min Cloud comments them → you pick or iterate
     → reply `small` / `3` / `Go 3` on the issue (longer notes iterate)
     → GitHub Action → Min Cloud → Cloud Agents API → PR
     → merge → POST /internal/feedback/{id}/shipped → issue closed + shipped label
```

This is the same loop as Cadence (`CyclingData/docs/FEEDBACK.md`), adapted for the min apps monorepo.

---

## What you already have in the code

| Piece | Where |
|---|---|
| API + DB + GitHub/Cursor logic | `services/min-cloud` (`src/lib/feedback.ts`, `src/routes/feedback.ts`, migration `008_feedback.sql`) |
| Shared iOS UI | MinAppKit → **Ideas & bugs** (`IdeasSettingsLink`) |
| Wired in apps | Account / Settings on mov, pod, vid, cyc, spin, fit |
| GitHub Actions | `.github/workflows/feedback-comment.yml`, `feedback-shipped.yml` |

You still need to configure **secrets**, **GitHub labels**, and **Cursor automations** (below). Until those are set, submissions still save in the database; GitHub/Cursor steps are skipped or retried later.

---

## Plain-English overview (read this once)

1. Someone taps **Ideas & bugs** in the app, writes a title, and sends it.
2. The phone calls Min Cloud (`https://min-cloud-production.up.railway.app` by default).
3. Min Cloud saves the report (including who sent it, if they have a Min Cloud account).
4. Min Cloud opens a GitHub issue that **does not** include their email — only a summary and a private fetch URL for agents.
5. Min Cloud pings a **Cursor Triage** automation. That agent reads the full report and posts 2–3 options back through Min Cloud (which comments on the issue).
6. You reply on the GitHub issue with something short like `small` or `2`. A GitHub Action forwards that comment to Min Cloud.
7. Min Cloud starts a **Cursor cloud agent** that implements only that option and opens a PR. The PR body must contain `Feedback-Id: <uuid>`.
8. When you merge the PR, another Action tells Min Cloud “shipped,” which closes the issue.

If something is missing (token, webhook, API key), the idea is not lost — it stays in Postgres and Min Cloud retries on a timer.

---

## Step 1 — Create GitHub labels

On [github.com/carambula/myrepo](https://github.com/carambula/myrepo) → **Issues** → **Labels** → create:

| Label | Meaning |
|---|---|
| `feedback` | Intake from Min Cloud |
| `bug` / `idea` | Kind |
| `app:mov` / `app:pod` / `app:vid` / `app:cyc` / `app:spin` / `app:fit` | Which min app (optional but useful) |
| `triage-in-progress` | Agent is drafting options |
| `needs-approval` | Proposal is ready for you |
| `approved-for-build` | You picked an option |
| `in-progress` | Implementation PR is open |
| `shipped` / `declined` | Terminal. Min Cloud applies `shipped` and closes the issue when the PR merges. |

If labels are missing when an issue is created, Min Cloud retries without labels so the issue still opens.

---

## Step 2 — Create a GitHub Personal Access Token (PAT)

This token lets Min Cloud open issues, comment, and apply labels. Cursor’s GitHub App often **cannot** comment on issues — Min Cloud must do it with this PAT.

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens**.
2. Prefer a **fine-grained** token for `carambula/myrepo` with:
   - **Issues:** Read and write
   - **Pull requests:** Read (optional; useful for debugging)
3. Or a classic token with `repo` scope (broader).
4. Copy the token somewhere safe. You will paste it into Railway as `FEEDBACK_GITHUB_TOKEN`.

---

## Step 3 — Railway (Min Cloud) environment variables

Open your Min Cloud service on [Railway](https://railway.app) → **Variables**.

Set these (same values you will reuse in GitHub Actions and Cursor):

| Variable | What it is | How to get it |
|---|---|---|
| `PUBLIC_URL` | Already set ideally — production API origin, **no trailing slash** | e.g. `https://min-cloud-production.up.railway.app` |
| `FEEDBACK_CRON_TOKEN` | Long random secret shared by GitHub Actions and agents | Generate one: `openssl rand -hex 32`. You may reuse `CRON_SECRET` if you already have one; the code falls back to `CRON_SECRET` when `FEEDBACK_CRON_TOKEN` is empty. |
| `FEEDBACK_GITHUB_TOKEN` | The PAT from Step 2 | Paste the token |
| `FEEDBACK_GITHUB_REPO` | Which repo gets issues | `carambula/myrepo` |
| `FEEDBACK_GITHUB_NOTIFY_USER` | Who gets @mentioned and assigned | `carambula` |
| `FEEDBACK_CURSOR_WEBHOOK_URL` | Triage automation webhook URL | From Cursor Automations (Step 5) |
| `FEEDBACK_CURSOR_WEBHOOK_SECRET` | Triage automation API key (`crsr_…`) | From that automation’s “Generate auth header” |
| `FEEDBACK_CURSOR_API_KEY` | **Preferred for Build** | [cursor.com/dashboard → API Keys](https://cursor.com/dashboard?tab=api) |
| `FEEDBACK_CURSOR_ITERATE_WEBHOOK_URL` | Iterate automation webhook | Step 5 |
| `FEEDBACK_CURSOR_ITERATE_WEBHOOK_SECRET` | Iterate key (if different from triage) | Optional if same as triage |
| `FEEDBACK_CURSOR_BUILD_WEBHOOK_URL` | Fallback only | Skip if `FEEDBACK_CURSOR_API_KEY` is set |
| `FEEDBACK_CURSOR_BUILD_WEBHOOK_SECRET` | Build webhook key | Only if using the fallback |
| `FEEDBACK_DAILY_LIMIT` | Max reports per user/device per day | Default `20` |
| `FEEDBACK_UNLIMITED_EMAILS` | Comma-separated emails that bypass the limit | Optional (your email) |

### Deploy the migration

After shipping this code to Railway, Min Cloud runs migrations on boot (`008_feedback.sql` creates the `feedback` table). Redeploy (or restart) once after merge so the table exists.

### Sanity check

```bash
curl -s https://min-cloud-production.up.railway.app/health
```

You should see `"ok": true`. Submitting from an app before Cursor is configured still creates a DB row; GitHub/Cursor parts wait for tokens.

---

## Step 4 — GitHub Actions secrets (this repo)

On [github.com/carambula/myrepo/settings/secrets/actions](https://github.com/carambula/myrepo/settings/secrets/actions) add:

| Secret | Value |
|---|---|
| `MIN_CLOUD_PUBLIC_URL` | Same as Railway `PUBLIC_URL` (no trailing slash) |
| `FEEDBACK_CRON_TOKEN` | **Exact same string** as Railway `FEEDBACK_CRON_TOKEN` (or `CRON_SECRET`) |

These power:

- `feedback-comment.yml` — when you comment on an issue/PR, forward it to Min Cloud
- `feedback-shipped.yml` — when a PR with `Feedback-Id: …` merges, mark shipped

Until both secrets exist, the workflows exit quietly (they do not fail CI for unrelated PRs).

---

## Step 5 — Cursor Automations

Create these at [cursor.com/automations](https://cursor.com/automations). MCP cannot create them for you.

Min Cloud posts every GitHub comment with `FEEDBACK_GITHUB_TOKEN`. The Cursor GitHub App does **not** need Issues write for comments to appear.

Webhook payloads include a per-idea `agent_token` and a ready-to-run `prompt`. The triage agent should use that token as `X-Cron-Token` (or `Authorization: Bearer`). It only unlocks `/internal/feedback/{id}` and `/proposal` for that row — not `/pending` or other cron routes.

The optional daily sweep needs the **global** `FEEDBACK_CRON_TOKEN` as a Cursor **environment secret** (same value as Railway). Real-time triage does not.

### 5a. Triage (real-time) — required

**Triggers:** Cursor webhook (paste the URL into Railway `FEEDBACK_CURSOR_WEBHOOK_URL`) **and** optionally GitHub issue opened / labeled `feedback`.

**Prompt:**

```
A min apps user sent a bug or idea. Use the webhook JSON: feedback_id,
issue_url, min_cloud_url (or cadence_url), agent_token, and prompt.

1. Follow the payload prompt. GET {min_cloud_url}/internal/feedback/{id}
   with header X-Cron-Token: {agent_token} (or Authorization: Bearer).
   Do not copy the submitter's name or email onto GitHub.
2. Draft 2–3 concrete options (small / medium / full).
3. POST {min_cloud_url}/internal/feedback/{id}/proposal
   { "options": [ { "id": "small", "title": "...", "summary": "...", "risk": "low" }, ... ],
     "github_issue_number": <n> }
   with the same token. Min Cloud comments the options (mentions @carambula)
   and labels needs-approval.
4. Do not use gh to comment or label. Do not open a PR.

Do not implement anything.
```

Also paste the automation’s auth key into `FEEDBACK_CURSOR_WEBHOOK_SECRET`.

### 5b. Iterate (`You talked back`) — recommended

**Trigger:** Cursor webhook only. Paste into `FEEDBACK_CURSOR_ITERATE_WEBHOOK_URL`.

Do **not** also trigger this automation on GitHub issue comments — Min Cloud’s “drafting options” note would start a second agent on every new idea.

**Prompt:**

```
The maintainer commented on a Min Cloud feedback issue. Use the webhook JSON:
feedback_id, comment, agent_token, min_cloud_url (or cadence_url), prompt.

Revise the options from their comment. Do not start a PR.
GET /internal/feedback/{id} and POST /proposal with X-Cron-Token: {agent_token}.
Min Cloud comments the revised options.
```

### 5c. Build — prefer API key (skip webhook automation)

**Preferred:** skip a Build automation. Set `FEEDBACK_CURSOR_API_KEY` instead.

Min Cloud calls `POST https://api.cursor.com/v1/agents` with the approved-option prompt and `autoCreatePR: true`.

**Fallback:** Cursor webhook only → `FEEDBACK_CURSOR_BUILD_WEBHOOK_URL` + `FEEDBACK_CURSOR_BUILD_WEBHOOK_SECRET`.

GitHub comment automations and `approved-for-build` labels do **not** start a Cursor agent by themselves. Min Cloud receives your reply via `feedback-comment.yml` and kicks Build.

If you still make a Build automation, use this prompt:

```
The maintainer approved a Min Cloud idea. Use the webhook JSON: feedback_id,
chosen_option, agent_token, min_cloud_url, prompt.

1. GET {min_cloud_url}/internal/feedback/{id} with X-Cron-Token: {agent_token}.
2. POST {min_cloud_url}/internal/feedback/{id}/status
   { "status": "building", "chosen_option": "<from payload>" }.
3. Implement only that option. Open a PR whose body includes:

   Feedback-Id: {id}

   on its own line.
4. Do not use gh to comment. Do not merge the PR.
```

### 5d. Sweep (optional)

Min Cloud already re-pings triage for untriaged rows every few hours. A Cursor daily cron is optional:

**Trigger:** daily cron.

**Prompt:**

```
GET {PUBLIC_URL}/internal/feedback/pending with X-Cron-Token: {FEEDBACK_CRON_TOKEN}.
For each item still in received or triaging, run the Triage prompt.
Skip rows that already have a proposal.
```

Store `FEEDBACK_CRON_TOKEN` as a Cursor environment secret for this automation only.

---

## Step 6 — How you use it day to day

1. Someone submits from any min app → Account → **Ideas & bugs**.
2. You get a GitHub issue (and an @mention).
3. Wait for the options comment (`needs-approval`).
4. Reply with one of:
   - `small` / `medium` / `full`
   - `2` or `Go 2`
   - Or a longer note (“make option 2 but without the settings toggle”) → Iterate revises options
5. A PR appears. Review and merge.
6. Issue closes as shipped. The submitter sees **Shipped** under Ideas & bugs after refresh.

### Fix a stuck PR

Comment on the **PR** (Conversation tab), not only the issue:

1. PR body must include `Feedback-Id: <uuid>` (Build agents already write this).
2. Write what is wrong: `rebase onto main`, `fix the CI`, etc.
3. Min Cloud starts a **fix** cloud agent on that PR’s branch (`autoCreatePR: false`). It pushes to the same branch.

Do **not** reply `3` / `small` on the PR — those mean “approve this option again” and re-kick a new Build from `main`.

`FEEDBACK_CURSOR_API_KEY` must be set for fixes.

---

## Agent API cheat sheet

| Call | Auth | When |
|---|---|---|
| `POST /v1/feedback` | Optional Bearer session; `device_id` + `app` required if unsigned | App submit |
| `GET /v1/feedback?app=&device_id=` | Optional Bearer | App list |
| `GET /internal/feedback/pending` | Global cron token | Untriaged rows |
| `GET /internal/feedback/{id}` | Cron **or** per-idea `agent_token` | Full report |
| `POST /internal/feedback/{id}/proposal` | Cron or agent | Store options |
| `POST /internal/feedback/{id}/status` | Cron or agent | `triaging` / `approved` / `building` / `declined` |
| `POST /internal/feedback/github-comment` | Global cron | Relay from Actions |
| `POST /internal/feedback/{id}/shipped` | Global cron | After merge |
| `POST /internal/feedback/tick` | Global cron | Manual sweep + drip |

Send the token as `X-Cron-Token`, `X-Agent-Token`, or `Authorization: Bearer …`.

---

## App UI notes

- Entry point is **only** Account / More / Settings → **Ideas & bugs** (shared `IdeasSettingsLink` in MinAppKit).
- No per-page lightbulb (by design, for now).
- mov / pod: if the user is signed into Min Cloud, the report is tied to their account; otherwise a local `device_id` is used.
- Other apps: always use a local `device_id` (still rate-limited).
- Client default base URL: `https://min-cloud-production.up.railway.app` (overridable via UserDefaults `mincloud.baseURL`, same as mov/pod).

---

## Checklist (print / tick off)

- [ ] Labels created on `carambula/myrepo`
- [ ] GitHub PAT created → Railway `FEEDBACK_GITHUB_TOKEN`
- [ ] Railway: `FEEDBACK_GITHUB_REPO=carambula/myrepo`, `FEEDBACK_CRON_TOKEN`, `PUBLIC_URL`
- [ ] Railway redeployed so `008_feedback.sql` ran
- [ ] GitHub Actions secrets: `MIN_CLOUD_PUBLIC_URL`, `FEEDBACK_CRON_TOKEN`
- [ ] Cursor Triage automation + webhook URL/secret on Railway
- [ ] Cursor Iterate automation (webhook only) + URL on Railway
- [ ] Cursor dashboard API key → `FEEDBACK_CURSOR_API_KEY`
- [ ] Test: submit from one app → issue appears → options comment → reply `small` → PR → merge → issue closes

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| Idea saves in app but no GitHub issue | `FEEDBACK_GITHUB_TOKEN` / `FEEDBACK_GITHUB_REPO` missing or PAT lacks Issues write |
| Issue opens but no options | Triage webhook URL/secret wrong; check Railway logs for `Cursor webhook failed` |
| You reply `small` and nothing happens | GitHub secrets missing, or Action skipped own-comment markers — check Actions tab for “Relay feedback comments” |
| Options approved but no PR | Set `FEEDBACK_CURSOR_API_KEY`; re-comment the same option |
| PR merged but issue still open | `Feedback-Id:` missing from PR body, or shipped Action secrets unset |
| 401 on Build webhook | Prefer dashboard API key; do not reuse the triage `crsr_…` for Build |

Build kickoff prefers `FEEDBACK_CURSOR_API_KEY` because Cursor automation webhooks have been returning 401 even with a fresh `crsr_…` token (same lesson as Cadence).
