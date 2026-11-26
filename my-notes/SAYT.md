I need three read-only shell scripts for supporting a load test against our GCP sandbox. Please create them exactly as below, check them, and run the first one once. Don't change anything in GCP or Kubernetes. Every command in these scripts only reads.

1. Run this whole block in Terminal. It creates ~/loadtest with three scripts:

```bash
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

2. Check the syntax of each script with `bash -n` and tell me if any fail.

3. Make sure kubectl points at the sandbox cluster. Use the DNS endpoint, because the normal endpoint fails with a certificate error on this machine:
   gcloud container clusters get-credentials survey-assist-sandbox-cluster --region=europe-west2 --project=survey-assist-sandbox --dns-endpoint

4. Run `cd ~/loadtest && ./lt-before.sh` once and show me the output.

5. Test the summary script on a short recent window, for example the last 10 minutes in UTC (`./lt-summary.sh HH:MM HH:MM`). It may show very few requests, which is fine. I only want to know the queries run without errors.

6. Run `./lt-watch.sh` for about 30 seconds (2 lines), then stop it with Ctrl+C, and show me the lines.

If any command errors, tell me the exact error and the line it came from, and suggest a fix. Don't change the scripts without telling me what you changed and why.
