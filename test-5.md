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