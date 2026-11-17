# Tickets from 16 Nov (infra sync and Dan catch-up)
---

## Ticket 1: Build once, promote many for all app pipelines, including NatCen

| | |
|---|---|
| **Type** | Tech debt |
| **Priority** | Medium (next sprint) |
| **Epic** | Survey Assist Infrastructure Improvements |
| **Links** | Follows on from SA-1117 (build once, deploy many). Relates to SA-1119 (NatCen into CI/CD). |

**User story**
As a DevOps engineer, I want every environment to deploy the same image that was built and tested in dev, so that what reaches preprod and NatCen is exactly what we tested, and environments don't need their own copies of the build data.

**Description**
Today the dev and sandbox pipelines build a new image for each environment and copy that environment's data files into it. NatCen is being onboarded the same way for now (agreed with Dan on 16 Nov), but that means NatCen needs its own copy of the API CSVs and vector store data, and its image isn't the one we tested.

The API already has a NatCen promote pipeline (`cicd/cloudbuild_promote_natcen.yaml`) that deploys the release image preprod is running, by digest, with no rebuild. It isn't wired up to a trigger yet. This ticket extends that approach to all apps and environments.

**Scope**
- API, SAYT UI and vector stores
- Preprod, NatCen, and later prod

**Definition of done**
- [ ] Dev is the only pipeline that builds each app image
- [ ] Preprod and NatCen deploy the release image by digest. NatCen keeps its `GEMINI_MODEL_NAME` check.
- [ ] NatCen's Cloud Run service agent can read the `-releases` registries in the CI/CD project
- [ ] NatCen's per-environment build triggers are replaced by promote triggers
- [ ] The NatCen bucket no longer needs build data
- [ ] Tested in every environment, with no change except where the image comes from
- [ ] READMEs and pipeline header comments updated

---

## Ticket 2: Alert when a Gemini model is retired or not found

| | |
|---|---|
| **Type** | Tech debt |
| **Priority** | Low (backlog) |
| **Epic** | Survey Assist Infrastructure Improvements |
| **Links** | Relates to the model deprecation spike agreed with Dan on 28 Oct, and the NatCen token alert ticket (can reuse its alerting module) |

**User story**
As a DevOps engineer, I want an alert when the API gets a "model not found" or retirement error from Vertex AI, so that a deprecated Gemini model is caught straight away instead of silently breaking classify.

**Description**
In October, Gemini 2.5 Flash was deprecated and blocked for new projects. NatCen's classify calls started failing and we only found out through smoke testing. A log-based alert on the error would have caught it immediately.

**Definition of done**
- [ ] A log-based metric and alert policy for Vertex AI "model not found" or retirement errors from the API, in each environment
- [ ] Tested in sandbox by sending a request with a bad model name
- [ ] Alerts go to email, and to Slack once that's set up
- [ ] A short runbook: what to do when it fires

---

## All tickets to create, by priority

**Who raises what:** Ethan (or Dan) said in the meeting they'd raise the dashboard and JWT alert tickets, so check with Dan before raising L1 to L5. Joe raises the two tech debt tickets and the NatCen apply ticket.

| Priority | Ticket | Why now | Raised by | Blocked by |
|---|---|---|---|---|
| **High** | NatCen JWT service account token alert (reusable alerting module) | First alert agreed in the meeting, and confirmed with Dan | Check with Dan | Which log source to use (key or IAM Credentials API) |
| **High** | SAYT UI dashboard as code (sets the pattern) | First dashboard. Needed before the load tests for a baseline. | Check with Dan | SAYT UI logging for the funnel part |
| **High** | API usage dashboard | One of the three agreed dashboards | Check with Dan | SAYT UI dashboard pattern |
| **Medium** | Apply NatCen Terraform after NatCen testing | Main and NatCen are out of sync (8 add, 32 change, 18 destroy, or 16 with the moved blocks). Covers the rename, test config version and GKE clean-up, plus checking the API losing its VPC connection. | Joe | NatCen finishing testing |
| **Medium** | Build once, promote many (Ticket 1) | Agreed with Dan as next sprint's tech debt | Joe | - |
| **Medium** | Security dashboard | One of the three agreed dashboards | Check with Dan | Dashboard pattern, token alert |
| **Medium** | Service reliability dashboard | One of the three agreed dashboards | Check with Dan | Dashboard pattern |
| **Medium** | Slack alerts channel and webhook request | Needed before alerts can go to Slack | Ethan | Platform engineering |
| **Medium** | Route alerts to Slack (log sink, Pub/Sub, Cloud Run function) | Turns email alerts into Slack alerts | TBC | Slack webhook |
| **Medium** | NatCen log analytics bucket | NatCen has no logging setup. The token alert and dashboards need its logs. | Joe (ask first) | NatCen apply, if it needs one |
| **Medium** | SAYT UI application logging | Feeds the survey progress funnel | Check first, may be the existing "logging the user journey" ticket | - |
| **Low** | Gemini model deprecation alert (Ticket 2) | Agreed with Dan as backlog tech debt | Joe | Token alert module (to reuse) |
| **Low** | Saved log analytics queries | Port last year's queries into the repo | TBC | Dashboard pattern |
| **Low** | Spike: correlation IDs and OpenTelemetry | Later, once basic monitoring is in | TBC | Basics done |
| **Low** | Upgrade Terraform across environments | Rupert's suggestion (we're on 1.11, latest is 1.17) | Joe (optional) | - |



Here are the titles, in priority order. The full details are saved in `ons_ws/tickets/1611-tickets.md`.

**High**
1. Alert on NatCen JWT service account token usage
2. SAYT UI dashboard as code
3. API usage dashboard

**Medium**
4. Apply NatCen Terraform after NatCen testing
5. Build once, promote many for all app pipelines, including NatCen
6. Security dashboard
7. Service reliability dashboard
8. Request a Survey Assist alerts Slack channel and webhook
9. Route alerts to Slack
10. NatCen log analytics bucket
11. SAYT UI application logging

**Low**
12. Alert when a Gemini model is retired or not found
13. Saved log analytics queries
14. Spike: correlation IDs and OpenTelemetry
15. Upgrade Terraform across environments

You raise 4, 5 and 12. Check with Dan before raising 1, 2, 3, 6 and 7, and check whether 11 already exists as "logging the user journey".
