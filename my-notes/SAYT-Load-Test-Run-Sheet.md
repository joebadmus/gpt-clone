Survey Assist · sandbox · infra support for load tests

# SAYT load test run sheet

What to do before, during and after each run, in order, and how to read what you see. Three scripts do the checking, so you watch one line instead of juggling commands. For the architecture and the checks for each hop, use the [SAYT load test map](https://claude.ai/artifact/XpjhtBGgkzWTR95ABwVzDV).

## What you're watching for

**Latency**

How long requests take. p50 is a typical request. p95 is the slowest 1 in 20. Target: p95 1 s or less, p99 3 s or less.

**Errors**

Anything that isn't a 2xx or 3xx. Target: no unexpected errors. Over 5% means the run has failed.

**Saturation**

Something full: CPU, instances, connections. When something fills up, requests queue. Latency climbs first, then timeouts turn into errors.

**The knee**

The user count where latency suddenly climbs. Below it things are fine, above it they fall over. Finding it is the point of the test.

## Who does what

### Geoff

- Runs Locust and calls start and stop
- Watches Locust's failures and response times
- Exports the HTML report

### You

- Runs the scripts and watches the live line
- Keeps the dashboard open
- Notes the start and end times, and when anything odd happens
- Says which part of the infra is struggling

### Stop the run if

- errors stay above 5% for more than a minute
- vector store pods keep restarting (the restart count keeps going up)
- Cloud Armor blocks most of the traffic
- someone else using sandbox says it's affecting them

## One-time setup on the Jamf machine

Paste this into Terminal once. It makes a `~/loadtest` folder with three scripts. Every file they write is saved in that folder, named with the time.

```
mkdir -p ~/loadtest && cd ~/loadtest
cat > lt-before.sh <<'SCRIPT'
#!/bin/bash
# Before a run: record versions and check sandbox is at its starting point.
P=survey-assist-sandbox; R=europe-west2; NS=vector-store
OUT="before-$(date -u +%Y%m%dT%H%MZ).txt"
{
  echo "== Taken at $(date -u +%H:%M:%S) UTC =="
  echo "== Cloud Run: revision, image digest, concurrency =="
  for s in sayt-ui survey-assist-api firestore-otp-api; do
    rev=$(gcloud run services describe "$s" --region=$R --project=$P --format='value(status.latestReadyRevisionName)')
    gcloud run revisions describe "$rev" --region=$R --project=$P \
      --format='value(metadata.name, status.imageDigest, spec.containerConcurrency)'
  done
  echo "== Vector store pods (want 1 Running, 0 restarts) =="
  kubectl get pods -n $NS -o wide
  echo "== Vector store image =="
  kubectl get pods -n $NS -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].imageID}{"\n"}{end}'
  echo "== HPA (want 1 replica and low CPU) =="
  kubectl get hpa -n $NS
  echo "== Idle CPU and memory (your baseline) =="
  kubectl top pods -n $NS
} 2>&1 | tee "$OUT"
echo "Saved to $OUT"
SCRIPT
cat > lt-watch.sh <<'SCRIPT'
#!/bin/bash
# Live view during a run: one line every 15 seconds, also saved to a file. Ctrl+C to stop.
P=survey-assist-sandbox; NS=vector-store
LOG="watch-$(date -u +%Y%m%dT%H%MZ).log"
echo "Saving to $LOG. Ctrl+C to stop."
echo "time UTC | vector store cpu mem | HPA cpu% replicas | pods (restarts) | LB 5xx last 2 min" | tee -a "$LOG"
while true; do
  t=$(date -u +%H:%M:%S)
  top=$(kubectl top pods -n $NS --no-headers 2>/dev/null | awk '{printf "%s %s ", $2, $3}')
  hpa=$(kubectl get hpa sayt-vector-store-hpa -n $NS \
    -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}% {.status.currentReplicas}/{.status.desiredReplicas}' 2>/dev/null)
  pods=$(kubectl get pods -n $NS \
    -o jsonpath='{range .items[*]}{.status.phase}(r{.status.containerStatuses[0].restartCount}) {end}' 2>/dev/null)
  e5=$(gcloud logging read 'resource.type="http_load_balancer" AND httpRequest.requestUrl:"sayt.sandbox" AND httpRequest.status>=500' \
    --project=$P --freshness=2m --limit=500 --format='value(httpRequest.status)' 2>/dev/null | wc -l | tr -d ' ')
  echo "$t | $top| $hpa | $pods| $e5" | tee -a "$LOG"
  sleep 15
done
SCRIPT
cat > lt-summary.sh <<'SCRIPT'
#!/bin/bash
# After a run: status codes, latency and errors for a time window.
# Usage: ./lt-summary.sh 15:24 15:40   (UK time, which is UTC in winter. Uses today's date.)
if [ $# -ne 2 ]; then echo "Usage: $0 START END   e.g. $0 15:24 15:40"; exit 1; fi
P=survey-assist-sandbox
D=$(date -u +%Y-%m-%d)
W="timestamp>=\"${D}T$1:00Z\" AND timestamp<=\"${D}T$2:00Z\""
LB='resource.type="http_load_balancer" AND httpRequest.requestUrl:"sayt.sandbox"'
OUT="summary-${D}-${1/:/}-${2/:/}.txt"
pct() { sort -n | awk 'function pc(q, i){i=int(q*n+0.999999); if(i<1)i=1; return a[i]}
  {a[NR]=$1+0} END{n=NR; if(!n){print "  no requests"; exit}
  printf "  count=%d  p50=%.2fs  p95=%.2fs  p99=%.2fs  max=%.2fs\n", n, pc(.5), pc(.95), pc(.99), a[n]}'; }
codes() { gcloud logging read "$1 AND $W" --project=$P --limit=20000 --format='value(httpRequest.status)' | sort | uniq -c | sort -rn; }
lat() { gcloud logging read "$1 AND $W" --project=$P --limit=20000 --format='value(httpRequest.latency)' | sed 's/s$//' | pct; }
{
  echo "== Window $D $1 to $2 UTC (takes a minute or two) =="
  echo; echo "== Status codes at the load balancer (what users got) =="; codes "$LB"
  for s in sayt-ui survey-assist-api firestore-otp-api; do
    echo; echo "== Status codes at $s =="
    codes "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"$s\" AND httpRequest.status>0"
  done
  echo; echo "== Load balancer 5xx by cause =="
  gcloud logging read "$LB AND httpRequest.status>=500 AND $W" --project=$P --limit=5000 \
    --format='value(httpRequest.status, jsonPayload.statusDetails)' | sort | uniq -c | sort -rn
  echo; echo "== Cloud Armor blocks by rule priority =="
  gcloud logging read "resource.type=\"http_load_balancer\" AND jsonPayload.enforcedSecurityPolicy.outcome=\"DENY\" AND $W" \
    --project=$P --limit=1000 --format='value(jsonPayload.enforcedSecurityPolicy.priority)' | sort | uniq -c
  echo; echo "== Suggestions latency at the load balancer (what users waited) =="
  lat "$LB AND httpRequest.requestUrl:\"business-activity-suggestions\""
  echo; echo "== Suggestions latency at the API =="
  lat "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"survey-assist-api\" AND httpRequest.requestUrl:\"suggestions\""
  echo; echo "== Page and save latency at the load balancer (everything except suggestions) =="
  lat "$LB AND NOT httpRequest.requestUrl:\"suggestions\""
  echo; echo "== API warnings, most common first (look for ReadTimeout or PoolTimeout) =="
  gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"survey-assist-api\" AND severity>=WARNING AND $W" \
    --project=$P --limit=500 --format='value(textPayload, jsonPayload.message)' | cut -c1-160 | sort | uniq -c | sort -rn | head -10
} 2>&1 | tee "$OUT"
echo "Saved to $OUT"
SCRIPT
chmod +x lt-*.sh && ls -l ~/loadtest
```

**lt-before.sh** records versions and the idle state. **lt-watch.sh** prints one line every 15 seconds during the run. **lt-summary.sh** adds up codes, latency and errors for the run window afterwards.

## On the day

T−30

### Get set up

1. [ ]

   **Connect kubectl**

   ```
   gcloud container clusters get-credentials survey-assist-sandbox-cluster \
     --region=europe-west2 --project=survey-assist-sandbox --dns-endpoint
   kubectl get pods -n vector-store
   ```

   **Good:** one `sayt-vector-store-…` pod, `1/1 Running`. **If you get a certificate error,** you've left off `--dns-endpoint`.
2. [ ]

   **Record the starting point**

   ```
   cd ~/loadtest && ./lt-before.sh
   ```

   **Good:** 1 pod Running with 0 restarts, the HPA at 1 replica, and low CPU (tens of millicores). The idle CPU is your baseline. If a pod is restarting before you start, sort that out first.
3. [ ]

   **Open the dashboard**

   Cloud Monitoring → Dashboards → **SAYT load testing (sandbox)**. Set the time range to the last 30 minutes with auto-refresh on. Watch three panels: load balancer latency, Cloud Run latency and CPU for the API, and vector store CPU.
4. [ ]

   **Tell people and agree the settings**

   Post the window in the dev channel. Ask Dan to hold WAF changes. Confirm with Geoff the users, spawn rate, think time, duration and how many codes he has.

T−0

### Start

1. [ ]

   **Start the live line, then tell Geoff to go**

   ```
   cd ~/loadtest && ./lt-watch.sh
   ```

   Write down the start time to the minute, in UK time (the same as UTC in winter).

During

### Every minute or two, check in this order

1. [ ]

   **Locust (on Geoff's screen)**

   Are there failures? Which endpoint, and which code? Locust shows problems first, because the logs lag 30 to 60 seconds.
2. [ ]

   **The live line**

   Vector store CPU, HPA, pods and the load balancer 5xx count. How to read it is below.
3. [ ]

   **The dashboard**

   Is the API's latency climbing? Is its CPU near 100%? Is the UI's CPU high? Write down the time of anything odd. "15:26 API p95 jumps to 8 s" is all you need.

End

### Stop and cool down

1. [ ]

   **Write down the end time, and leave the live line running for 5 minutes**

   Watch the system recover. CPU should drop back to the baseline, and a second pod should go after about a minute. If it doesn't recover, that's a finding. Then press Ctrl+C.

After

### Within 15 minutes

1. [ ]

   **Run the summary for the run window**

   ```
   cd ~/loadtest && ./lt-summary.sh 16:00 16:12
   ```

   Use your start and end times. It takes a minute or two. How to read it is below.
2. [ ]

   **Take dashboard screenshots**

   Set a custom time range on the dashboard to the run window, then screenshot each section.
3. [ ]

   **Fill in the notes, and send them to Geoff for the results table**

   Template at the bottom of this page.

## Reading the live line

These are example lines to show the patterns. They aren't real readings.

```
time UTC | vector store cpu mem | HPA cpu% replicas | pods (restarts) | LB 5xx last 2 min
16:00:05 | 30m 9120Mi    | 0% 1/1   | Running(r0)            | 0      idle
16:02:20 | 640m 9180Mi   | 8% 1/1   | Running(r0)            | 0      busy, coping
16:04:35 | 1010m 9200Mi  | 12% 1/1  | Running(r0)            | 0      stuck at one core
16:05:20 | 1015m 9210Mi  | 12% 1/1  | Running(r0)            | 37     errors, CPU still flat
16:07:10 | 4300m 9800Mi  | 53% 1/2  | Running(r0) Pending()  | 0      HPA asked for pod 2
```

| Column | What it is | Fine | Worry |
| --- | --- | --- | --- |
| cpu | Vector store CPU in millicores. 1000m is one core, and the pod has 8000m. | rises and falls with the load | flat at about 1000m one process is the limit, and the HPA will never trigger |
| mem | Vector store memory | steady | keeps climbing a leak, which could end in OOMKilled |
| HPA cpu% | CPU as a percentage of 8 cores. 12% is about one core. It scales at 50%. | under 50% | over 50% pod 2 should be on its way |
| replicas | Current and desired pods | 1/1 or 2/2 | 1/2 scaling in progress. Time how long until it's 2/2. |
| pods | Status, with the restart count in brackets | Running(r0) | Pending waiting for a node. r goes up crashing, so run the events command on the map. |
| LB 5xx | Load balancer errors in the last 2 minutes. Trails Locust by up to a minute. | 0 | rising ask Geoff which endpoint, and check the dashboard |

**The pattern from the 25 November run:** errors rising while the API's CPU stays low means the API is waiting on the vector store. If the vector store's CPU sits flat at about 1000m (12%) at the same time, its single process is the bottleneck. The live line can't show API CPU, so check that on the dashboard.

## Reading the summary

This example is shaped like the 25 November run. It isn't real output.

```
== Status codes at the load balancer (what users got) ==
   2410 200
     37 504
== Load balancer 5xx by cause ==
     37 504	response_sent_by_backend
== Suggestions latency at the load balancer (what users waited) ==
  count=600  p50=0.90s  p95=10.05s  p99=12.20s  max=13.00s
== Suggestions latency at the API ==
  count=600  p50=0.85s  p95=12.10s  p99=16.80s  max=17.30s
== Page and save latency at the load balancer (everything except suggestions) ==
  count=1847  p50=0.12s  p95=0.70s  p99=0.95s  max=1.40s
== API warnings, most common first (look for ReadTimeout or PoolTimeout) ==
  (nothing)
```

1. **Error rate** = errors divided by the total at the load balancer. In the example, 37 out of 2,447 is 1.5%. Any errors are a finding. Over 5% is a failed run.
2. **Who made the errors:** `response_sent_by_backend` means the UI returned them (at about 10 s it gave up on the API). `backend_timeout` means the UI took over 30 s. `failed_to_connect_to_backend` means no UI instance was available.
3. **Is it only search?** Pages and saves fine but suggestions slow means the problem is on the search path: UI → API Gateway → API → vector store.
4. **Where on the search path?** Compare suggestions p95 at the load balancer with p95 at the API. If they're close, the time is spent at the API or behind it. If the load balancer number is much bigger, the time is lost in the UI or API Gateway.
5. **API or vector store?** If the API warnings show `ReadTimeout` or `PoolTimeout`, the vector store is too slow. If the API's CPU is high, the API itself is the bottleneck. If its CPU is low while its latency is high, it's waiting on the vector store, even with no warnings, because slow responses that arrive within the timeouts don't log anything.
6. **Cloud Armor:** any blocks from rules 100 to 220 are WAF rules catching test traffic. Send the times and priorities to Dan.
7. **429s at the OTP service** mean the ramp-up was too fast for it (concurrency 3). Lower the spawn rate next time.

## Notes template

```
Run:            (e.g. Test 1: 25 users, spawn 5/s, think 0-3 s, 10 min)
Date, start, end (UK time):
Codes used:
Versions:       (from before-*.txt)

Locust:         total requests, failure %, p95 suggestions, p95 pages
Server side:    (from summary-*.txt)
  LB errors and cause:
  Suggestions p95 at LB / at API:
  Pages and saves p95:
Vector store:   peak CPU, did the HPA scale (asked at / ready at)
API (dashboard): peak CPU, peak latency
First thing to struggle, and when:
Cloud Armor blocks:
Anything else:
```

## Before the next run

1. **Step the load up, rather than repeating 25 users.** Short runs at 5, 10, 15 and 20 users, about 2 minutes each, show the knee: the user count where the API stops coping. That uses about the same number of codes as one 25-user run (about 500), but tells you much more. Suggest it to Geoff, and see S2 on the [scenarios page](https://claude.ai/artifact/Hg5Mf52LeS6ktDZecPaJ49).
2. **Don't change sandbox between runs** unless everyone agrees, or the runs can't be compared. Fixes for the API (more workers or instances) and the vector store go in the tuning ticket (SA-1278), with Ethan and Dan.
3. **Share the API finding with Ethan and Dan now.** The UI gives up after about 10 s. The API took 9 to 17 s at 25 users with its CPU low, so it was waiting, most likely on the vector store's single process. API memory also sits at about 94.5% of 1 GB. They'll know whether more uvicorn workers, more replicas or more memory is the right fix.
4. **Agree which numbers the targets apply to,** Locust's (from a laptop on the VPN) or the server side's. It's still an open point on Geoff's page.
5. **Find the UI's 10-second timeout** in the SAYT UI code. It decides when a slow search becomes an error. It isn't in Terraform, and the SAYT UI repo isn't one you have cloned.

The ticks on the steps are saved in this browser only. The scripts only read from sandbox: they don't change anything.