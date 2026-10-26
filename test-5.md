I've added a NatCen environment file, [survey-assist-natcen.postman_environment.json](postman/survey-assist-natcen.postman_environment.json). You'll run the same collection as last week and compare the results against sandbox.

## What to watch for

NatCen is a newly built environment. Last week's tech meeting mentioned new resource names and an IP allow-list, so most problems are likely to be setup gaps rather than code bugs. Check things in this order:

| # | Check | What a problem looks like | Likely cause |
|---|---|---|---|
| 1 | **Token generation** | `403 ... signJwt` | You don't have Token Creator on the NatCen service account |
| 2 | **Gateway auth** | `401 Jwt issuer is not configured` or `401 Audiences ... not allowed` | Wrong service account, or wrong gateway host. Each environment has its own |
| 3 | **Network access** | An HTML `403 Forbidden` page instead of JSON | Cloud Armor or an IP allow-list is blocking your machine |
| 4 | **Lookup** (`electrical installation`) | No `43210` back | The SIC lookup data isn't loaded |
| 5 | **Classify, clear input** | Empty `candidates` list, or a 5xx | The vector store is empty or unreachable (index not built, or the API can't authenticate to it) |
| 6 | **Classify, vague input** | 500 `Error during classification` | Gemini (Vertex AI) isn't enabled, or the API's service account lacks permission to call it |
| 7 | **Store result** | 503 | Firestore isn't configured in NatCen |
| 8 | **Compare with sandbox** | Different codes for the clear input, or a big latency gap | NatCen is running a different version |

**How to compare with sandbox:** use the same inputs in both and compare the response shape, the codes for the clear input, and whether the vague input gets a follow-up. Gemini's wording varies between runs, so expect the reasoning and follow-up text to differ even when everything works.

**To check for a version difference:** try `GET /v1/survey-assist/config` on both environments and compare. The gateway may not expose it; if not, ask which image version or commit is deployed.

## Steps

1. Run `gcloud auth application-default set-quota-project <NATCEN-PROJECT-ID>`.
2. Set `SA_EMAIL` and `API_GATEWAY` to the NatCen values, then run `make generate-api-token`.
3. Run the collection with the NatCen environment:
   ```bash
   postman collection run survey-assist-api.postman_collection.json \
     -e survey-assist-natcen.postman_environment.json \
     --env-var gatewayHost=<natcen-host> --env-var token=<jwt>
   ```
4. Run the same collection with the sandbox environment, then compare the two.

If you already have access to the NatCen project, you can find the gateway host and service account yourself with the same `gcloud` commands as last week. You'd then only need to ask questions 3–6 below.

---

Written for: your team chat. These are short questions, ready to paste.

> I'm repeating last week's sandbox API tests on the NatCen environment. A few quick questions:
> 1. What's the NatCen GCP project ID, and can I have viewer access to it?
> 2. Can I have Token Creator access on the NatCen API service account? (Or let me know which service account it is.)
> 3. Is everything deployed in NatCen (API, gateway, vector store), and is it the same version as sandbox?
> 4. Is the NatCen gateway behind an IP allow-list or Cloud Armor? If so, how should I call it from my machine?
> 5. Is the SIC data loaded into the NatCen vector store yet?
> 6. Is it OK to write a test record to the NatCen Firestore via `/result`, or should I skip that step?


<!-- Response -->
Good progress. Since both lookups work, these parts of NatCen are fine:

- **Token:** your service account and audience are correct.
- **Gateway:** it accepts your JWT, and the network let you through.
- **API:** the container is running and its SIC lookup data is loaded.

Lookup only uses data built into the API container. Classify is the first call that reaches **outside** the API: first to the **SIC vector store**, then to **Gemini**. So the failure is in one of those two, or in the API's permission to call them.

## Step 1: Check the vector store directly

The API has a status endpoint for this, `GET /embeddings`. It may not be exposed through the gateway; if it returns 404, skip to step 2.
```bash
curl -s -w "\n%{http_code}\n" -H "Authorization: Bearer $TOKEN" "https://$API_GATEWAY/v1/survey-assist/embeddings"
```

| Result | Meaning |
|---|---|
| 200 with `"status": "ready"` and `index_size` around 16618 | Vector store is fine, so the problem is Gemini. Go to the table below |
| 503 `Unable to authenticate to ...` | The API can't authenticate to the vector store. Its service account is probably missing `roles/run.invoker` on the vector store's Cloud Run service |
| 503 `Failed to check ... status` | The API can't reach the vector store. Either the URL setting is wrong or missing, or the vector store isn't deployed |
| 200 but status isn't `ready` | The vector store is still building its index. Wait a few minutes and retry |

## Step 2: Match the classify error

Send the **status code and response body** from the clear-input classify call. Then match it here:

| Error | Meaning | Fix (for the infra team) |
|---|---|---|
| **503** `Failed to search SIC vector store: ... connection refused / localhost` | `SIC_VECTOR_STORE` isn't set on the NatCen API, so it's pointing at localhost | Set the environment variable to the vector store's URL |
| **503** `Unable to authenticate to SIC vector store` | The API can't get a token for the vector store | Give the API's service account `run.invoker` on the vector store |
| **422** `The LLM could not generate a valid classification` with `Unambiguous classification failed: 403 / PermissionDenied` | The API can't call Gemini | Enable Vertex AI in the project, and give the API's service account `roles/aiplatform.user` |
| **422** with `404 ... model not found` or a location error | Wrong Gemini model or region for this project | Check the model and region settings, or whether Gemini is available in that region |
| **500** `Error during classification: ...` | Something unexpected. The text after the colon says what | It depends on the message |
| **504** or a timeout | The vector store is cold-starting or overloaded | Retry once. If it keeps happening, report it |

## Step 3: Check the API's logs (if you have NatCen project access)

```bash
gcloud logging read 'resource.type="cloud_run_revision" AND severity>=WARNING' \
  --project=<NATCEN-PROJECT-ID> --freshness=1h --limit=30 \
  --format="value(timestamp,resource.labels.service_name,jsonPayload.message,textPayload)"
```

Then compare the API's settings with sandbox:
```bash
gcloud run services list --project=<NATCEN-PROJECT-ID>
gcloud run services describe <api-service-name> --project=<NATCEN-PROJECT-ID> --region=<region> \
  --format="yaml(spec.template.spec.containers[0].env)"
```
Look for `SIC_VECTOR_STORE` (missing, or set to localhost?), `SIC_VECTOR_STORE_AUTH_ENABLED`, and `GCP_PROJECT_ID`. Run the same `describe` against sandbox and compare.

My guess is the vector store, either its URL setting or the API's permission to call it. It's a separate deploy, and NatCen is a new environment, so it's the most likely piece to be missing. Paste the error body and I'll tell you which one it is.