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
