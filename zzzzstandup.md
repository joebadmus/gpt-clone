I got that wrong. The load balancer didn't time out. The output shows two things:

- **`response_sent_by_backend`:** the SAYT UI itself sent back the 504. The load balancer just passed it on.
- **Latency of 10 to 13 seconds**, not 30. So the UI waits about 10 seconds for the suggestions call behind it, then gives up and returns a 504. The extra 2 to 3 seconds on some requests is probably them queueing in the UI first.

The 10-second limit is most likely the UI's own timeout on its call to the API. It isn't in Terraform, so it's in the app code.

There's also a bonus finding in the URLs: `q=sof`, `soft`, `softw`, `softwa`... Locust is calling suggestions on every keystroke, like the real UI. That answers one of the open points on the Confluence page.

The next question is whether the API was slow, or the vector store behind it. Run these two:

**API latency for suggestions during the run:**

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="survey-assist-api" AND httpRequest.requestUrl:"suggestions"' \
  --project=survey-assist-sandbox --freshness=1h --limit=30 \
  --format='table(timestamp, httpRequest.status, httpRequest.latency)'
```

**What the UI logged when it gave up:**

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="sayt-ui" AND severity>=WARNING' \
  --project=survey-assist-sandbox --freshness=1h --limit=20 \
  --format='table(timestamp, severity, textPayload, jsonPayload.message)'
```

**How to read it:**
- **API latency also around 10 seconds or more:** the slowness is the API or the vector store. Then check vector store CPU on the dashboard for 15:20 to 15:30, and `kubectl describe hpa sayt-vector-store-hpa -n vector-store`.
- **API latency low:** the time is lost between the UI and the API, either in API Gateway or in the UI itself.

Send me the output and I'll help you read it.
===============
The slowness is at the API or behind it, not in the UI. And the vector store never tried to scale. Here's what each output shows:

API (first output): every suggestions call returned 200, but they took 9 to 17 seconds at the peak, 15:24:36 to 15:24:48. The UI gives up at about 10 seconds, so those became 504s. By 15:24:52 it was back to 0.5 seconds, which is when the load stopped. So the API did answer, just too slowly.
HPA (third output): no scaling events, and it's still at 1 pod. Vector store CPU never reached 50% of its 8 CPUs, so the HPA never asked for a second pod.
UI errors (second output): the message didn't show, because the UI logs it in a different field. Not a problem, as the API output already tells us what we need.
My best guess: it's a throughput limit, not a lack of CPU. Both the API and the vector store run uvicorn as a single process, with no --workers set. I checked the API Dockerfile and the Helm template. One process can't use 8 CPUs, so the vector store queues requests while CPU stays low. That would also explain why the HPA never triggers. The API is a single 1-CPU instance too, so it could be either one, or both.

To settle it, open the dashboard for 15:20 to 15:30 and compare two numbers:

Vector store CPU in the GKE section. If it flattened around 12% (one core of eight), the single process is the limit.
API CPU in the Cloud Run section. If that was pinned near 100%, the API is the limit.
I'd still run at 4. Have watch -n 5 kubectl top pods -n vector-store open during it. If the vector store sits at about 1000m (one core) while the API latency climbs, you've proven it live.

Update for Geoff:

Had a look. The UI gives up after about 10 seconds and returns the 504, and the API was taking 9 to 17 seconds to answer suggestions during your run. The vector store never scaled, because its CPU didn't get near the 50% trigger. So it looks like a throughput limit behind the API, rather than lack of CPU. I'll watch the API and vector store live during the 4 o'clock run to pin down which one it is.

Once you know which one it is, the fix for tuning (SA-1278) is likely more workers or instances, not bigger machines. That's a conversation for Ethan and Dan, not something to change before today's run.
