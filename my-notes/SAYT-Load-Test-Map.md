Survey Assist · sandbox · load testing

# SAYT load test map

How one Locust user travels through sandbox, where each request can fail, and the command to check each hop. Click a box in the diagram to jump to its checks. Settings are from the Terraform and Helm in the repo as of 25 November 2026. For what to do on the day, step by step, use the [SAYT load test run sheet](https://claude.ai/artifact/83kU7wvXc3MQ8yL4HYQmd4).

## The request path

Read it left to right. The numbers are the hops, in the order a search request passes through them. Timeouts are on the arrows. The shortest timeout on a path decides who gives up first.

Edge (Cloud Armor, load balancer) Cloud Run and API Gateway GKE vector store Data stores Where the 15:24 run broke

## What the 15:24 run showed (25 Nov, 25 users)

- **The UI sent the 504s, not the load balancer.** Load balancer logs show `response_sent_by_backend` at 10 to 13 seconds on `/api/business-activity-suggestions`. The UI waits about 10 seconds for the API, then gives up.
- **The API was slow but didn't fail.** Suggestions returned 200 but took 9 to 17 seconds between 15:24:36 and 15:24:48, then dropped back to about 0.55 seconds once the load stopped.
- **The vector store never scaled.** The HPA had no events and stayed at 1 pod. CPU never reached 50% of 8 CPUs.
- **The API was waiting, not working.** Geoff saw API CPU stay low during the run, so the API wasn't busy. It was most likely waiting on the vector store. Its client allows up to 5 seconds each for getting a connection, connecting and reading, so one call can wait well over 5 seconds and still return 200.
- **The vector store is the likely bottleneck.** It runs one process, so searches queue behind each other while its CPU stays at about one core out of eight (12%). The HPA never reaches 50%, so it never adds a pod. Checked on the dashboard: only a small CPU bump at 15:24, but the run was about a minute and the chart averages each minute, so it doesn't settle it. The next 10-minute run, with `lt-watch.sh` reading CPU every 15 seconds, will. Flat at about 1000m (12%) means this is it.
- **API memory sits at about 94.5% of 1 GB** all the time, before and after the run. It isn't causing the slowness, but it leaves very little headroom. Flag it for tuning.
- **Locust searches on every keystroke** (`q=sof`, `soft`, `softw`…), like the real UI. One search question is 5 to 10 calls.

## One Locust user's journey

Each Locust user runs the same journey: the paid employee route, with the longest feedback path. When it finishes, it starts again with a fresh access code until the run ends. Response times are from the 1-user smoke run on 24 November.

1. ### Log in with an access code

   hops 1 → 2 → 3 → 5 (OTP service → Firestore) · about 540 ms

   401code already used or expired. 429the OTP service is full (concurrency 3), usually during a fast ramp-up.
2. ### View a question page

   hops 1 → 2 → 3 → 4 (Redis session) · 50 to 80 ms

   Should stay fast. If pages slow down too, the UI or Redis is struggling, not the search path.
3. ### Save an answer

   hops 1 → 2 → 3 → 4 · 350 to 680 ms

   5xxon saves with fast suggestions points at the UI or Redis connections.
4. ### Search for a business activity, one call per keystroke

   hops 1 → 2 → 3 → 6 → 7 → 8 · 742 ms median at 1 user

   504after about 10 s means the UI gave up on the API. This is the call that broke at 25 users.
5. ### Finish the survey and the feedback questions, then start again

   steps 2 and 3 repeated · then back to step 1 with a new code

   Codes run out → Locust stops cleanly. That isn't an infrastructure failure.

## Checks at each hop

### Before you start

Connect kubectl through the DNS endpoint (the Cisco certificate issue blocks the normal endpoint). Log times are UTC, which is the same as UK time in November.

```
gcloud container clusters get-credentials survey-assist-sandbox-cluster \
  --region=europe-west2 --project=survey-assist-sandbox --dns-endpoint
```

HOP 1

### Locust on the laptop

Geoff's laptop · VPN · Cisco inspection in the path

Looks like

Locust latency much higher than the load balancer's. Or a high CPU warning in the Locust console.

Means

The VPN or the laptop is adding the time, not sandbox.

Do

Compare Locust's p95 with the load balancer p95 on the dashboard. Report both. If Locust warns about CPU, don't trust numbers after that point.

HOP 2

### Cloud Armor and the load balancer

sandbox-alb · backend service-backend-sayt-ui · timeout 30 s · WAF rules (100–220) run before the allow-list (1000)

Looks like

`403` from Cloud Armor, or `5xx` where the load balancer's status details say why.

Means

`backend_timeout`: the UI took over 30 s. `response_sent_by_backend`: the UI made the error itself. `failed_to_connect_to_backend`: no UI instance was available.

Requests Cloud Armor blocked, with the rule. Send these to Dan.

```
gcloud logging read 'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.outcome="DENY"' \
  --project=survey-assist-sandbox --freshness=30m --limit=20 \
  --format='table(timestamp, httpRequest.requestUrl, jsonPayload.enforcedSecurityPolicy.priority, jsonPayload.enforcedSecurityPolicy.preconfiguredExprIds)'
```

All 5xx at the load balancer, and who caused them.

```
gcloud logging read 'resource.type="http_load_balancer" AND httpRequest.status>=500' \
  --project=survey-assist-sandbox --freshness=30m --limit=20 \
  --format='table(timestamp, httpRequest.status, httpRequest.latency, jsonPayload.statusDetails, httpRequest.requestUrl)'
```

HOP 3

### SAYT UI (Cloud Run)

sayt-ui · min 1, max 1 · concurrency 40 · 6 CPU, 4 GB · request timeout 60 s · waits about 10 s for the API

Looks like

`504` at about 10 s on suggestions. `500` on pages or saves. `429` if more than 40 requests arrive at once.

Means

A 504 at 10 s is the UI giving up on hops 6 to 8, so look further right. 500s on pages point at the UI or Redis.

UI requests that failed.

```
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="sayt-ui" AND httpRequest.status>=500' \
  --project=survey-assist-sandbox --freshness=30m --limit=20 \
  --format='table(timestamp, httpRequest.status, httpRequest.latency, httpRequest.requestUrl)'
```

The full error the UI logged. The table format hides it, so this uses YAML.

```
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="sayt-ui" AND severity>=ERROR' \
  --project=survey-assist-sandbox --freshness=30m --limit=3 --format=yaml
```

HOP 4

### Redis (UI sessions)

survey-assist-sayt-redis · Basic tier · 1 GB · 32 connections per UI container

Looks like

Pages and saves slow down or fail, while suggestions look normal. The UI error logs mention Redis or connections.

Means

The UI's connection pool is full. That's the 32-connection risk on Geoff's page.

Do

Check "Redis connected clients" on the dashboard. If it sits flat at a ceiling during the run, this is it.

```
gcloud redis instances describe survey-assist-sayt-redis \
  --region=europe-west2 --project=survey-assist-sandbox \
  --format='table(state, tier, memorySizeGb)'
```

HOP 5

### OTP service and Firestore (login)

firestore-otp-api · 1 instance · concurrency 3 · called by the UI directly

Looks like

`401` on login, or `429` mostly at the start of a run.

Means

401: the code was used or has expired, so it's a Locust CSV problem. 429: more than 3 logins at once, which is the ramp-up being too fast.

Do

401s: get fresh codes. 429s: lower the spawn rate, and note it for tuning.

```
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="firestore-otp-api" AND httpRequest.status>=400' \
  --project=survey-assist-sandbox --freshness=30m --limit=20 \
  --format='table(timestamp, httpRequest.status, httpRequest.latency, httpRequest.requestUrl)'
```

HOP 6

### API Gateway

survey-assist-api-gw · deadline 60 s · the UI calls /v1/survey-assist/suggestions

Looks like

`401` or `403` if the UI's token fails. `504` only if the API takes over 60 s. `503` if the API is unreachable.

Means

If gateway latency matches API latency, the gateway isn't adding anything and the problem is further right.

```
gcloud logging read 'resource.type="api" AND httpRequest.requestUrl:"suggestions"' \
  --project=survey-assist-sandbox --freshness=30m --limit=20 \
  --format='table(timestamp, httpRequest.status, httpRequest.latency)'
```

HOP 7

### Survey Assist API (Cloud Run)

survey-assist-api · min 1, max 1 · concurrency 80 · 1 CPU, 1 GB · one uvicorn process · vector store client: 5 s timeout, 100 connections

Looks like

Suggestions return 200 but take many seconds.

Means

Check API CPU on the dashboard. Near 100%: requests are queueing in the API's single process. Low (as on 25 Nov): the API is waiting on the vector store (hop 8), even if the warnings are empty. `ReadTimeout` or `PoolTimeout` in the warnings also point at the vector store.

How long suggestions took at the API.

```
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="survey-assist-api" AND httpRequest.requestUrl:"suggestions"' \
  --project=survey-assist-sandbox --freshness=30m --limit=30 \
  --format='table(timestamp, httpRequest.status, httpRequest.latency)'
```

API warnings. Look for vector store timeouts.

```
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="survey-assist-api" AND severity>=WARNING' \
  --project=survey-assist-sandbox --freshness=30m --limit=5 --format=yaml
```

HOP 8

### SAYT vector store (GKE)

namespace vector-store · deployment sayt-vector-store · HPA 1 to 2 pods at 50% CPU · 8 CPU, 32 GB per pod · one uvicorn process · Autopilot on C4 nodes

Looks like

CPU flat at about 1000m (one core) while the API is slow. Or a second pod stuck in Pending. Or restarts.

Means

About 1000m flat means the single process is the limit, and the HPA will never trigger. 4000m or more means the HPA should add pod 2. Pending means it's waiting for a new node. `OOMKilled` means it ran out of memory.

Watch live during a run, one terminal each.

```
watch -n 5 kubectl top pods -n vector-store
kubectl get pods -n vector-store -w
kubectl get hpa -n vector-store -w
```

After a run, or when a pod misbehaves.

```
kubectl describe hpa sayt-vector-store-hpa -n vector-store | tail -15
kubectl get events -n vector-store --sort-by=.lastTimestamp | tail -20
kubectl logs -n vector-store deploy/sayt-vector-store --since=30m | tail -50
kubectl get nodes
```

## Tracing a 504 or slow search

Work left to right until the latency drops. The slow hop is the last one where the time is still high.

1. **Who sent the error? (hop 2)**

   `backend_timeout` at about 30 s: the load balancer gave up on the UI. Go to step 2.

   `response_sent_by_backend`: the UI returned it. At about 10 s it gave up on the API. Go to step 3.
2. **Is the UI itself struggling? (hops 3 and 4)**

   UI CPU high, or pages slow too: the UI instance or Redis.

   Only suggestions slow: the UI is waiting on hops 6 to 8. Go to step 3.
3. **Was the API slow? (hops 6 and 7)**

   API latency high and API CPU high: the API is the bottleneck.

   API latency high but API CPU low: it's waiting on the vector store, even if its warnings are empty. Go to step 4.
4. **What is the vector store doing? (hop 8)**

   CPU about 1000m and flat: one uvicorn process is the limit. Fix with more workers or replicas.

   CPU high and pod 2 Pending: scaling is too slow. Fix by starting at 2 pods (Infra 3).

## Status codes at a glance

| Code | Most likely from | Check first |
| --- | --- | --- |
| 401 | Access code used or expired (hop 5), or the UI's token at API Gateway (hop 6) | Locust failures tab. Fresh codes fix it. |
| 403 | Cloud Armor or WAF rule (hop 2) | Blocked requests command. Send the rule IDs to Dan. |
| 429 | A Cloud Run service at max instances and full concurrency. The OTP service (concurrency 3) is the usual one. | Which service in the 4xx logs. Lower the spawn rate. |
| 500 | An application error in the UI or the API | Error logs for that service, in YAML format. |
| 502 | The load balancer got a bad or no response, usually because the UI was restarting | Status details at hop 2, then the UI's instances. |
| 503 | Service not ready: a Cloud Run instance starting, or no ready vector store pod | `kubectl get pods`, and Cloud Run instances on the dashboard. |
| 504 | Somebody gave up waiting. On suggestions, the UI after about 10 s. | Tracing a 504, above. |

Sources: survey-assist-terraform (sandbox tfvars, ui-network module, Helm chart for the vector store), survey-assist-api (main.py, Dockerfile), the 24 November smoke run, and the logs from the 25 November 15:24 run. Not yet confirmed in code: the exact UI timeout to the API (seen as about 10 s in the logs), and whether answer saves call the API.