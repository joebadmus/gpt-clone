# NatCen Smoke Test: Meeting Summary

**Date:** Tuesday 27 Oct 2026
**Attendees:** Joe (you), Dan (infra/deployment), team lead (name not captured in transcript)
**Mentioned:** Rupert (PR reviewer, away since Friday), Ethan (Cloud Armor / georestriction), Matthew (mentioned once, role unclear), data science team, NatCen (external customer)
**Deadline:** **Thursday 29 Oct 2026**, NatCen onboarding / access handover

> Transcript is auto-generated and noisy. "Natsen" = NatCen, "Juro" = Jira, "conference" = Confluence, "cloud ammo" = Cloud Armor, "Cisco" = ONS Cisco web filter (likely Umbrella), "Talos" = Cisco Talos reputation lookup. Some details (e.g. the exact Gemini version quoted, "3.8") may be mis-transcribed. Confirm before quoting them.

---

## 1. TL;DR

1. **Classify endpoints in the NatCen env are broken (422)** because the Survey Assist API **hard-codes Gemini 2.5 Flash**, which Google **deprecated on 20 Oct 2026** and blocks for new projects/service accounts. Fixing it is **not just an infra fix**. The LLM was evaluated on 2.5, so any model change needs **data science sign-off / re-evaluation**. The lead called it a **"massive problem"**.
2. **Since this morning, every NatCen call returns 403.** Leading suspect: the **ONS Cisco web filter blocking the API Gateway hostname** (uncategorised / "security threat" per Talos). Cloud Armor / IP allow-listing still has to be ruled out. **You're testing from GCP Cloud Shell to bypass the ONS network.**
3. **Sandbox is fine.** All endpoints pass there, including classify.
4. **Thursday prep continues regardless.** Dan is creating an external-facing service account for NatCen. Preferred route: NatCen gives us Google identities rather than us sharing an SA key.
5. Housekeeping: your smoke test Jira ticket isn't on the board. Dan's adding it to the sprint and labels. Manual-steps / pain points are going onto a Confluence page, and you'll attach your Postman collection there.

---

## 2. Smoke Test Results (your testing, 26 Oct)

| Endpoint group | Sandbox | NatCen env (26 Oct) | NatCen env (27 Oct) |
|---|---|---|---|
| SIC lookup: exact match | Pass | Pass | 403 |
| SIC lookup: similarity | Pass | Pass | 403 |
| SIC lookup: empty description (expected 400) | Pass | Pass | 403 |
| Classify (all variants) | Pass | **422** | 403 |
| Store result | Pass | Pass | 403 |
| Get result | Pass | Pass | 403 |

API only. **No UI testing has been done yet.**

---

## 3. Issue Deep-Dives

### 3.1 Gemini 2.5 Flash deprecation (root cause of 422)

- Survey Assist API has the model **hard-coded** (it can't be passed as a parameter).
- Google deprecated Gemini 2.5 Flash on **20 Oct 2026**. Existing users/projects keep access for now. **New** projects/service accounts get a "not found" error even though the model technically still exists. The team "missed it by a week".
- Sandbox works because it's an older project that still has access. In the sandbox UI, selecting 2.5 silently switches the selection to a newer model.
- **Why it matters:** all LLM quality analysis/testing was done on 2.5. A new model can change classification output quality, so data science must decide what re-testing is needed.
- **Longer-term risk:** even the replacement model's guaranteed availability (quoted as "until Sept next year", i.e. Sept 2027) reportedly **ends before the main "big test"**. Model lifecycle will keep biting this project.
- **Agreed approach:**
  - Dan posts in the **general Survey Assist stand-up chat** (not the dev chat) so everyone, including data scientists, sees it.
  - Lead follows up proposing a **temporary model switch for NatCen only, to prove connectivity**.
  - Data science owns the decision on the permanent model and the evaluation needed.

### 3.2 403 Forbidden on NatCen endpoints (new today)

Hypotheses discussed:

| Hypothesis | Status | Owner |
|---|---|---|
| ONS Cisco web filter blocking the API Gateway hostname (random-looking, uncategorised) | **Likely.** Talos lookup showed "site is blocked due to a security threat" | Lead raises Cisco exception request |
| Cloud Armor / IP allow-list on API Gateway | Unconfirmed. Cloud Armor is definitely on the UIs. Dan checking whether it fronts the API Gateway | Dan |
| Georestriction | Not enabled currently. Dan to speak to Ethan about enabling it | Dan / Ethan |
| Something changed in the env since yesterday | Unknown | You + Dan |

Key constraint the lead raised: **NatCen is external.** We can't control their IPs (VPNs, home broadband), so access **must not depend on fixed IP allow-lists**.

### 3.3 Other known infra issues

- A **job fails on fresh environment deploys when there's no existing data**. It should warn instead of failing. Dan will create a subtask with error messages, and **you may pick up the fix**.
- Dan has a local list of **manual steps and pain points** from the deployment (including Terraform gaps). He'll publish it to Confluence, then the team decides which become tickets.
- Small cherry-picked fix PRs (e.g. bucket name length, networking fixes) need preparing for **Rupert** to review.
- Infra sync later today covers these with Dan.

### 3.4 NatCen access for Thursday

- Dan is creating a **manually managed service account** for the external customer and granting **token creation** (Service Account Token Creator) against the backend SA, so tokens can be minted to call the API.
- Terraform builds a backend SA, but not one fit to share externally.
- **Preferred:** NatCen provides **Google identities**, which we add directly, so no key gets shared.
- **Fallback:** share an SA key if they have no Google accounts (possible if they're a Microsoft/GitHub shop).
- **Ask NatCen at the meeting** whether they have Google accounts.

---

## 4. Action Items

### You (Joe)
| # | Action | When |
|---|---|---|
| 1 | **Run the smoke tests from GCP Cloud Shell** (outside the ONS network) to confirm whether the 403 is the ONS Cisco filter or a GCP-side restriction | Today, priority |
| 2 | **Send Dan the exact 403 error**: full response body and headers, plus the domain | Today |
| 3 | Dig deeper into what changed since yesterday | Today |
| 4 | **Share the Postman smoke test collection** with Dan and upload it to Dan's Confluence page once he sends the link | When link arrives |
| 5 | Pick up parallel work: the failing-job fix (warn instead of fail) and/or preparing the small PRs for Rupert | After the test is unblocked |
| 6 | Fix up your Jira ticket using Dan's template ticket (labels, sprint). Review the story vs task definitions on the Confluence page Dan/lead sent | Today |
| 7 | Flag **anything** that could put Thursday at risk (explicit ask from the lead) | Ongoing |
| 8 | Attend the infra sync with Dan later today | Today |

### Dan
- Post the Gemini 2.5 deprecation message in the **general stand-up chat**. He said "I'll do that now".
- Check whether Cloud Armor fronts the **API Gateway** (not only the UIs).
- Speak to Ethan about georestriction.
- Create the NatCen external service account and grant token creation.
- Publish manual steps / pain points to Confluence and send you the link.
- Add your smoke test ticket to the sprint with correct labels, and send you a template ticket.
- Create a subtask for the failing job with error messages.
- Log in to Talos and check the domain categorisation.

### Lead
- Raise a **Cisco exception request** to unblock the API Gateway domain on the ONS network.
- Follow up on Dan's chat message with the temporary-model proposal for NatCen.
- Send the Confluence link for Jira issue-type definitions (may already be sent).
- Available for another chat today or tomorrow if needed.

### Data science
- Decide on the replacement Gemini model and the re-evaluation needed.

---

## 5. What You Should Be Waiting On

- [ ] Dan's Gemini message posted in the stand-up chat. **Check it went out today.** The lead was explicit that it must be flagged today.
- [ ] Confluence page link (manual steps + smoke test section)
- [ ] Template Jira ticket, and your ticket appearing on the board
- [ ] Subtask for the failing job, with error messages
- [ ] Dan's answer on whether Cloud Armor is on the API Gateway
- [ ] Cisco exception outcome (lead)
- [ ] Decision on the temporary model for NatCen
- [ ] NatCen service account readiness

---

## 6. Things I'd Flag (my analysis, not said in the meeting)

### 6.1 Thursday is at real risk on classify. Say so early.
- Because the model is **hard-coded**, even a "temporary" switch needs a **code change, PR, review and redeploy**, not a config flip. With Rupert away and two working days left, **nobody was explicitly assigned this code change**. Ask who owns it today.
- If NatCen gets a temporary model, **tell them explicitly** that classify output comes from an unvalidated model and results aren't representative. Otherwise early feedback from them could be misleading.
- Agree a fallback for Thursday: demo SIC lookup and store/get results (which work), and treat classify as "pending model upgrade".

### 6.2 Make the model configurable
- Suggest a ticket to move the model name to an env var / config parameter. Given the Sept 2027 availability window and future deprecations, this will come up again. Treat it as tech debt now.
- **The sandbox will probably break too** once Google withdraws 2.5 for existing projects. Its passing classify results are on borrowed time. Monitor it.

### 6.3 422 is a misleading status code
- An upstream "model not found" surfaced as **422 Unprocessable Entity** suggests the client sent bad input. It should be a 5xx (e.g. 502/503). Worth raising as a bug, because NatCen developers will waste time debugging their payloads.

### 6.4 Triage the 403 quickly
Before or alongside Cloud Shell:
1. **Regenerate your token first.** Yesterday's JWT/ID token has almost certainly expired (usually 1 hour). An expired or wrong-audience token can show up as 401/403, so rule this out first.
2. **Look at the response body/headers.** They usually identify the blocker:
   - Cisco block page: HTML that mentions Cisco/Umbrella, often a redirect.
   - Cloud Armor: Google-style 403 HTML.
   - API Gateway auth failure: JSON body (e.g. `"Jwt is expired"`, `"Audiences in Jwt are not allowed"`).
3. From Cloud Shell, `curl -v` with a fresh token is the quickest check. To reuse the collection, export it and the environment and run it with `newman` (npm), or the Postman CLI if installed there.
4. If Cloud Shell also gets 403, it's GCP-side. Ask Dan to check the **audit logs / deploy history since yesterday**. Someone may have applied Cloud Armor or another policy.

### 6.5 Service account key security
- The lead mentioned possibly **emailing** NatCen a service account. **Push back on emailing an SA key.** Long-lived keys are a significant credential-leak risk. If a key has to be shared:
  - use a secure channel (not plain email or Teams), with an agreed expiry and rotation
  - give it least privilege (token-creation / invoke only on this API, nothing else)
  - keep one key per external org, and know how to revoke it fast
- Check whether the GCP org policy even allows SA key creation (`iam.disableServiceAccountKeyCreation`). If it's blocked, the fallback fails on Thursday. **Check before Thursday, not on the day.**
- Consider whether Workload Identity Federation (e.g. with their Microsoft Entra ID) could avoid keys if they lack Google accounts.
- **Who asks NatCen about Google accounts, and when?** If the answer only arrives at Thursday's meeting, access can't be ready the same day. Try to get it beforehand.

### 6.6 Postman collection hygiene
- Before sharing or uploading the collection to Confluence, **strip tokens and secrets** from the collection and environment (current values, auth headers, pre-request scripts). Share the environment template separately.

### 6.7 The access model has to work for external users
- The lead was clear that IP allow-listing can't work for NatCen. If Dan finds Cloud Armor IP rules on the API Gateway, that needs resolving **before Thursday**. Note that georestriction (UK-only?) could also block NatCen developers on VPNs.
- Similarly, the Cisco exception only fixes it for **ONS staff**. That's fine, but it confirms the hostname looks suspicious to corporate filters. **NatCen's own corporate proxy may block it too.** A custom, properly categorised domain would help. Worth raising.

### 6.8 Coverage gaps
- **The UIs haven't been tested at all**, only the API. Clarify whether NatCen will use the UI on Thursday. If so, it needs a smoke test too.
- Add the auth/token path for the **NatCen service account itself** to your smoke tests once it exists. Test it the way NatCen will use it, not with your internal credentials.

### 6.9 Jira
- Your smoke test ticket is a **story**. By the team definition (story = value visible to a user outside the team), it's probably a **task**. Only "NatCen user can log in and use the API" is a story. Low stakes, since the lead said people "aren't too precious", but worth aligning while you're new.

---

## 7. Open Questions to Raise

1. Who owns the code change to swap or parameterise the Gemini model, and can it land before Thursday?
2. What exactly are we showing/handing NatCen on Thursday if classify isn't fixed?
3. Is SA key creation permitted by org policy? Who asks NatCen about Google identities, and when?
4. Is Cloud Armor on the API Gateway, and what changed between 26 and 27 Oct?
5. Will NatCen use the UI, API only, or both?
6. Which of the three tickets (provisioning the isolated environment, smoke test, and a third not clear from the transcript) are expected done by Thursday?
