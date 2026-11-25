# Load test first go in sandbox, 25 Nov

**Who:** Geoff runs Locust. Joe watches the infrastructure and notes the times.
**Goal:** prove the process works end to end, not get final numbers. That means Locust runs, codes get used, the dashboard shows the traffic, and we can read the results.
**Setup:** sandbox exactly as it is (agreed with Matt). No scaling or config changes before or during the run.

## Plan for the afternoon

| Step | What | Settings | Codes (rough) | Why |
|---|---|---|---|---|
| 0 | Pre-flight checks | See the checklist below | none | Don't waste codes on a broken setup |
| 1 | Dry run | 5 users, spawn 1 a second, think time 0 to 3 s, 5 minutes | 30 to 50 | Proves the whole process at low load |
| 2 | Test 1, if step 1 is clean | 25 users, spawn 5 a second, think time 0 to 3 s, 10 minutes | 250 to 400 | First real number at about the target load. Still a stress test. |
| 3 | Cool down and save | Wait 5 minutes, then save the reports and screenshots | none | Lets the vector store scale back down and gives a clean end time |

Only do step 2 if step 1 has no unexplained errors and there are enough codes. If codes run out, Locust stops cleanly, so it isn't a disaster, just a shorter run.

## Pre-flight checklist

- [ ] **Codes:** ask Geoff how many are in his CSV. Need about 50 for the dry run and 300 or more for Test 1.
- [ ] **Tell Dan** the time window. He's changing the WAF in sandbox right now. A change mid-run would spoil the results, and any 403s are useful false positive data for him.
- [ ] **Tell Rupert** not to push or merge the vector store during the window. His PR's push trigger restarts the sandbox vector store.
- [ ] **Post in the team channel** that sandbox will be under load from [start] to [end].
- [ ] **VPN on.** Geoff ran from his laptop on the VPN on 22 Nov with no Cloud Armor problems.
- [ ] **kubectl works** (commands below).
- [ ] **Dashboard open:** Cloud Monitoring, "SAYT load testing (sandbox)". Set the time range to the last 30 minutes, with auto-refresh on.
- [ ] **Starting point noted:** vector store at 1 pod and Running, no recent restarts.
- [ ] **Image versions recorded** (commands below). Sandbox uses `:latest`, so this is the only way to compare runs later.

## Commands

**Connect to GKE** (DNS endpoint, because of the Cisco cert issue):

```bash
gcloud container clusters get-credentials survey-assist-sandbox-cluster \
  --region=europe-west2 --project=survey-assist-sandbox --dns-endpoint
```

**Watch the vector store during the run** (one terminal each):

```bash
kubectl get pods -n vector-store -w                 # pods starting, crashing, restarting
kubectl get hpa -n vector-store -w                  # CPU % against the 50% target, and replicas
watch -n 10 kubectl top pods -n vector-store        # live CPU and memory per pod
kubectl get nodes -w                                # a new node appearing when it scales
```

**Events, if a pod goes Pending or restarts:**

```bash
kubectl get events -n vector-store --sort-by=.lastTimestamp | tail -20
kubectl describe pod -n vector-store <pod-name>     # why it's Pending, or why it restarted
```

**Record image versions before the run:**

```bash
for s in sayt-ui survey-assist-api firestore-otp-api; do
  rev=$(gcloud run services describe $s --region=europe-west2 --project=survey-assist-sandbox \
        --format='value(status.latestReadyRevisionName)')
  echo "$s $rev $(gcloud run revisions describe $rev --region=europe-west2 \
        --project=survey-assist-sandbox --format='value(status.imageDigest)')"
done
kubectl get pods -n vector-store -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].imageID}{"\n"}{end}'
```

**Errors after the run** (set `--freshness` to cover the run):

```bash
# Cloud Run errors for the UI, API and OTP service
gcloud logging read 'resource.type="cloud_run_revision" AND severity>=ERROR AND
  resource.labels.service_name=("sayt-ui" OR "survey-assist-api" OR "firestore-otp-api")' \
  --project=survey-assist-sandbox --freshness=30m --limit=50 \
  --format='table(timestamp, resource.labels.service_name, textPayload)'

# Requests Cloud Armor blocked, with the rule that blocked them
gcloud logging read 'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.outcome="DENY"' \
  --project=survey-assist-sandbox --freshness=30m --limit=50 \
  --format='table(timestamp, httpRequest.requestUrl, jsonPayload.enforcedSecurityPolicy.preconfiguredExprIds, jsonPayload.enforcedSecurityPolicy.priority)'
```

## Scaling: don't, for today

- **Cloud Run (UI, API, OTP):** don't scale by hand with `gcloud run services update`. It drifts from Terraform, so the next apply reverts it, and the run would no longer be "sandbox as it is". Pilot-level settings are a Terraform change for the tuning ticket (SA-1278), after the Ethan call.
- **Vector store:** let the HPA do its thing. Watching whether it gets a second pod in time is one of the things we want to learn. If you ever need two pods from the start (Infra 3, or a later run), this is the command, and you have to undo it afterwards:

```bash
kubectl patch hpa sayt-vector-store-hpa -n vector-store -p '{"spec":{"minReplicas":2}}'   # pin at 2
kubectl patch hpa sayt-vector-store-hpa -n vector-store -p '{"spec":{"minReplicas":1}}'   # undo
```

  The quota caps it at 2 pods (3 during a rolling update), so asking for more just leaves pods Pending. The next Helm deploy also resets it.

## What to watch, and what it means

The dashboard runs top to bottom in the same order as a request: load balancer, Cloud Run, vector store, Redis and Cloud Armor. Gemini should stay flat.

| What you see | Likely cause | Where to check | What to do |
|---|---|---|---|
| 401s on login | Used or expired access codes | Locust failures tab | Stop and get fresh codes. Not an infra problem. |
| 429s or 503s on login, mostly at the start | OTP service (1 instance, concurrency 3) swamped by the ramp-up | Cloud Run section, OTP requests and instances | Lower the spawn rate. Note it as a finding for tuning. |
| 403s | Cloud Armor or WAF (Dan's rules) | Cloud Armor panel, then the blocked requests command | Note the URL and rule ID and send them to Dan. That's false positive data he wants. |
| Suggestions slow, API CPU high, vector store CPU low | The single API instance (1 CPU) is the bottleneck | Cloud Run section, API CPU, latency and concurrency | Expected. A finding for tuning (API instances or CPU). |
| Suggestions slow, vector store CPU over 50% | The vector store pod is saturated | `kubectl get hpa` and `top pods` | Watch whether the HPA adds a pod. Note how long it takes. |
| Second pod stuck in Pending | Waiting for a new 8-CPU node, or the quota | `kubectl describe pod` and events | Note the time from Pending to Running. Fine if it gets there. |
| Pod restarts or CrashLoopBackOff | Out of memory or a failed probe | Events, and memory in `top pods` | Stop the run if it keeps happening. |
| UI 5xx or slow pages while the API looks fine | The UI instance, or the Redis connection pool (32 per container) | Cloud Run UI CPU and concurrency, Redis connected clients, UI error logs | Note it. That's the Redis risk on Geoff's page. |
| Locust latency high, server-side latency low | The VPN or the laptop | Compare Locust's p95 with the load balancer's p95 | Report both. The server-side number is the real one. |
| Latency keeps rising at a steady user count | Requests queueing somewhere | Latency trend and the concurrency panels | Note which service rises first. |
| Locust warns about high CPU on the laptop | Load generator limit, not the system | Locust console | Don't trust numbers past that point. Use fewer users. |

**Stop the run if:** errors stay above about 5%, pods crash-loop, Cloud Armor starts blocking most traffic, or someone else using sandbox is affected.

## What to record for each run

- Start and end time (to the minute) and the Locust settings
- Image versions from the commands above
- Locust HTML report (Geoff's export) and CSVs
- Dashboard screenshots with the time range set to the run window: load balancer latency and errors, Cloud Run latency, instances and CPU, vector store CPU and pods, Cloud Armor
- Did the HPA scale? When did it decide, and when was the new pod Ready?
- Codes used
- Which component slowed down first, and any errors

Geoff has added a results table to the Confluence page, so this goes there.

## Questions to settle with Geoff before starting

1. How many codes are in his CSV?
2. Are the Test 1 settings now 25 users, spawn 5 a second, 0 to 3 s think time, 10 minutes? Or did he keep 1 minute?
3. Is the feedback PR (5 to 10 searches) merged, or is it still 1 to 5 from main?
4. Does he want the dry run first, or straight into Test 1?




============
You're ready for this afternoon. I've put a run sheet in [2511-dry-run-plan.md](meeting/2511-dry-run-plan.md) to keep open during the run.

**The plan:** start small, then do Test 1 only if the small run is clean. Geoff runs Locust, and you watch the infrastructure.

| Step | Settings | Codes (rough) |
|---|---|---|
| Dry run | 5 users, spawn 1 a second, 0 to 3 s think time, 5 minutes | 30 to 50 |
| Test 1, if clean | 25 users, spawn 5 a second, 0 to 3 s think time, 10 minutes | 250 to 400 |

**Before you start:**
- Check Geoff has enough codes.
- Tell Dan the time window, since he's changing the WAF in sandbox today. Any 403s are false positives he'll want to see.
- Ask Rupert not to push the vector store while you're running, because his PR restarts it.
- Connect kubectl with `--dns-endpoint`.
- Note the image versions.
- Open the "SAYT load testing (sandbox)" dashboard.

**Don't scale anything today.** Matt agreed you'd test sandbox as it is. Scaling Cloud Run with gcloud also drifts from Terraform. Whether the vector store adds a second pod in time is one of the things you want to see. The sheet has the `kubectl patch hpa` command for later runs, and how to undo it.

The sheet also has:
- the kubectl watch commands, and log queries for errors and Cloud Armor blocks
- a table of what you might see, what it probably means, and what to do
- when to stop the run
- what to record for Geoff's results table

**Reply to Geoff** (fill in the time):

> Hi Geoff, sounds good, I'm ready on my side. How about [time]? I'd suggest a quick dry run first, 5 users for 5 minutes, to check everything works end to end, then Test 1 if that's clean. You drive Locust and I'll watch the infra side (Cloud Run, the vector store pods and Cloud Armor) and note the times. Couple of quick ones: how many access codes have you got in the CSV, and what settings did you land on for Test 1? I'll let Dan know the window, as he's making WAF changes in sandbox today.



======
3:45 works, and Geoff's plan matches yours. His laptop check now does the job of the dry run, so you can go straight into Test 1 at 3:45.

Two things to raise with him before he makes the codes:

- **Making 1,000 codes wipes the existing sandbox set.** That's the only way the OTP job works. Geoff said some user acceptance testing happens in sandbox, so check nobody's using sandbox codes this afternoon. It's quickest to ask in the dev channel message.
- **Spawn rate.** He didn't mention one. Ask for about 5 a second, not 25. The OTP service is one instance at concurrency 3, so logging everyone in at once would give you login errors from the burst rather than from real load.

His code maths is fine. 13 seconds per journey is on the fast side, so 490 is close to the most you'd need, and 1,000 leaves plenty spare.

**Reply to Geoff:**

> Sounds good, 10 minutes at 0 to 3 seconds and 1,000 codes works for me. 3:45 is fine. Could we use a spawn rate of about 5 a second? The OTP service is one instance at concurrency 3, so 25 at once might give us login errors that are just from the burst. One thing on the codes: making a new set wipes the existing sandbox ones, so I'll check in the dev channel that nobody's using them for testing today. I'll let Dan know too.

**Dev channel:**

> Heads up, Geoff and I are running a load test against sandbox from 3:45 to about 4:15 today. The SAYT UI and the API might be a bit slow during that time. We're also making a new set of sandbox access codes just before, which will wipe the current ones. Shout if you're using sandbox codes for testing this afternoon.

**Dan:**

> Hi Dan, we're starting the first load test in sandbox at 3:45, for about 10 minutes plus cool down. Could you hold off on WAF changes in sandbox until about 4:15? If anything gets blocked, I'll send you the URLs and rule IDs.

Before 3:45, connect kubectl with `--dns-endpoint`, run the image version commands, and open the dashboard. They're all in [2511-dry-run-plan.md](meeting/2511-dry-run-plan.md).



====
The 504s are almost certainly the external load balancer cutting the request off at 30 seconds. That's the shortest timeout in the chain:

| Hop | Timeout |
|---|---|
| Load balancer to SAYT UI | **30 s** |
| SAYT UI (Cloud Run) | 60 s |
| API Gateway to the API | 60 s |
| Survey Assist API (Cloud Run) | 60 s |

So the suggestions calls were queueing for over 30 seconds somewhere behind the UI. That's the path we expected to break first: UI, then API (one instance, 1 CPU), then the vector store (one pod). Page loads and saves were fine, which fits.

This isn't bad news. It's what the test is for. What you need now is which hop is slow. His run was around 15:2x, and the data is already in the logs and on the dashboard. Run these on the Jamf machine:

**1. Confirm it's the load balancer timing out**

```bash
gcloud logging read 'resource.type="http_load_balancer" AND httpRequest.status=504' \
  --project=survey-assist-sandbox --freshness=1h --limit=20 \
  --format='table(timestamp, httpRequest.requestUrl, httpRequest.latency, jsonPayload.statusDetails)'
```

- If you see `backend_timeout` with latency around 30 s, the load balancer gave up waiting for the UI.
- If you see `response_sent_by_backend`, the 504 came from further back, either the UI or API Gateway.

**2. See whether the API was slow too**

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="survey-assist-api" AND httpRequest.requestUrl:"suggestions"' \
  --project=survey-assist-sandbox --freshness=1h --limit=30 \
  --format='table(timestamp, httpRequest.status, httpRequest.latency)'
```

**3. Check whether the vector store tried to scale**

```bash
kubectl describe hpa sayt-vector-store-hpa -n vector-store | tail -15
kubectl get events -n vector-store --sort-by=.lastTimestamp | tail -20
```

**4. Look at the dashboard** with the time range set to 15:15 to 15:40. Compare API CPU in the Cloud Run section with vector store CPU in the GKE section.

**How to read it:**
- **API latency high and vector store CPU pinned:** the single vector store pod is the bottleneck. Check whether the HPA tried for a second pod.
- **API CPU pinned and vector store CPU low:** the single 1-CPU API instance is the bottleneck.
- **API latency low but the UI still timed out:** the UI itself is the problem, either its workers or the Redis connections.

I'd still do the 16:00 run. It's the "sandbox as it is" baseline Matt asked for, and this time you'll be watching it live. Just spend 10 minutes on the data above first, so you know what to watch.

**Reply to Geoff:**

> Thanks, that's actually useful. Suggestions was the one we expected to struggle. The load balancer times out at 30 seconds, so those requests were stuck behind the UI for at least that long. I'll check the dashboard and logs for your run now to see whether it's the API or the vector store. Can you share the start time and the spawn rate you used? Still happy to go at 4.

Send me the output and I'll help you read it.
