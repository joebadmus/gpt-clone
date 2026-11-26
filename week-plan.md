**Before 4pm (about 3:40)**

Terminal 1 is for Terraform. Get the branch ready, but don't apply:

```bash
cd <your survey-assist-terraform folder>
git fetch origin && git switch feat/sa-1278-api-scaling && git pull
cd survey-assist-sandbox
terraform plan -target='module.survey-assist-api.google_cloud_run_v2_service.api-cloud-run-service'
```

The plan should still say 1 to change. Leave this terminal open.

Terminal 2 is for the scripts:

```bash
gcloud container clusters get-credentials survey-assist-sandbox-cluster \
  --region=europe-west2 --project=survey-assist-sandbox --dns-endpoint
cd ~/loadtest && ./lt-before.sh
```

The API line should show concurrency 80, and the vector store should be at 1 pod with 0 restarts.

In the browser, open the "SAYT load testing (sandbox)" dashboard, set to the last 30 minutes, with auto-refresh on.

**At 4pm: the baseline run**

1. Post the heads-up in the dev channel.
2. In terminal 2, run `./lt-watch.sh`.
3. Tell Geoff to start: 25 users for 5 minutes. Write down the start time.
4. Watch the live line and the dashboard. Note when 504s appear.
5. When Geoff stops, write down the end time. Leave `lt-watch.sh` running for a few more minutes, then press Ctrl+C.
6. Run `./lt-summary.sh 16:00 16:05`, using your actual times. That's your baseline.

**Then apply (about 4:15)**

7. In terminal 1:
   ```bash
   terraform apply -target='module.survey-assist-api.google_cloud_run_v2_service.api-cloud-run-service'
   ```
   Type `yes` when it asks.
8. Check it took:
   - Run the same targeted plan again. It should say "No changes".
   - In terminal 2, run `./lt-before.sh`. The API line should now show concurrency 5.
   - On the dashboard, "Instances, by service and state" should show 5 API instances within a couple of minutes.

**The second run (about 4:20)**

9. Run `./lt-watch.sh`, and tell Geoff to run exactly the same test. Write down the times.
10. Afterwards, run `./lt-summary.sh` for that window.

**After both runs**

11. Compare the two summaries. Look at the 504s, suggestions p95 at the load balancer and at the API, and vector store CPU. Ethan wants to see the vector store CPU rise.
12. Send me both summaries. I'll fill in the SA-1277 tables, write the update for Ethan, and add the results to the draft PR.

Geoff owns the codes and the CSV, so you don't need to do anything there. Just check he has enough for two runs.


##====
Here's the table with the internal load balancer command added after each run:

| When | What to run | Terminal |
|---|---|---|
| Before the baseline | `./lt-before.sh` (finishes by itself) | 2 |
| Straight after | `./lt-watch.sh`, left running | 3 |
| During the baseline | Write down the start time and each 2-minute step | — |
| Baseline ends | `./lt-summary.sh <start> <end>` | 2 |
| Straight after | The internal LB command below, with the same start and end | 2 |
| Apply | `terraform apply -target='module.survey-assist-api.google_cloud_run_v2_service.api-cloud-run-service'` | 1 |
| After the apply | `./lt-before.sh` again (check concurrency 5), and the dashboard shows 5 API instances | 2 |
| During run 2 | Write down the start time and each 2-minute step | — |
| Run 2 ends | `./lt-summary.sh <start> <end>` | 2 |
| Straight after | The internal LB command, with run 2's start and end | 2 |
| All done | Ctrl+C on `lt-watch.sh` | 3 |

**The internal LB command.** Change the two times. They're in UTC, which is the same as UK time today:

```bash
gcloud logging read 'resource.type="internal_http_lb_rule" AND timestamp>="2026-11-26T16:00:00Z" AND timestamp<="2026-11-26T16:08:00Z"' \
  --project=survey-assist-sandbox --limit=20000 --format='value(httpRequest.latency)' \
  | sed 's/s$//' | sort -n \
  | awk '{a[NR]=$1} END{if(!NR){print "no requests"; exit} printf "vector store via internal LB: count=%d p50=%.3fs p95=%.3fs max=%.3fs\n", NR, a[int(NR*0.5)+1], a[int(NR*0.95)+1>NR?NR:int(NR*0.95)+1], a[NR]}'
```

Compare its p95 with "Suggestions latency at the API" in the summary. If the vector store is around 0.1 seconds and the API is in seconds, the API is the bottleneck.
