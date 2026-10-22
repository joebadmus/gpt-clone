Here are the curl commands to run against the sandbox gateway, assuming `API_GATEWAY` is still exported in your terminal:

**Token into a variable** (run from the `survey-assist-utils` folder):
```bash
TOKEN=$(make generate-api-token | tail -1)
```

**Auth check** (expect 200):
```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $TOKEN" "https://$API_GATEWAY/docs"
```

**List the endpoints:**
```bash
curl -s -H "Authorization: Bearer $TOKEN" "https://$API_GATEWAY/openapi.json" | python3 -m json.tool | grep '"/v1'
```

**Classify, clear input:**
```bash
curl -s -X POST "https://$API_GATEWAY/v1/survey-assist/classify" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"llm":"gemini","type":"sic","job_title":"Primary school teacher","job_description":"Teaching children aged 5 to 11","org_description":"State primary school","options":{"sic":{"rephrased":"true"},"soc":{"rephrased":"false"}}}' \
  | python3 -m json.tool
```

**Classify, ambiguous input** (should return a follow-up question):
```bash
curl -s -X POST "https://$API_GATEWAY/v1/survey-assist/classify" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"llm":"gemini","type":"sic","job_title":"Farm worker","job_description":"Caring for sheep","org_description":"Farm","options":{"sic":{"rephrased":"true"},"soc":{"rephrased":"false"}}}' \
  | python3 -m json.tool
```

If you open a new terminal, set the gateway again before getting the token:
```bash
export API_GATEWAY=$(gcloud api-gateway gateways list --project=survey-assist-sandbox --format="value(defaultHostname)" --limit=1)
```


The 404 is expected and doesn't mean the token is wrong. API Gateway only forwards paths that are listed in its own config. `/docs` isn't listed, so the gateway rejects it before the token is even checked. Your token is probably fine; this request just doesn't test it.

**1. See which paths the gateway exposes:**
```bash
CONFIG=$(gcloud api-gateway gateways list --project=survey-assist-sandbox --format="value(apiConfig)" --limit=1)
gcloud api-gateway api-configs describe "$CONFIG" --view=FULL \
  --format="value(openapiDocuments[0].document.contents)" | base64 --decode | grep -E '^\s+/'
```
This lists every route the gateway accepts. If docs are exposed, they'll appear under something like `/v1/survey-assist/docs`.

**2. Run classify, which is the real test:**
```bash
curl -s -w "\n%{http_code}\n" -X POST "https://$API_GATEWAY/v1/survey-assist/classify" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"llm":"gemini","type":"sic","job_title":"Primary school teacher","job_description":"Teaching children aged 5 to 11","org_description":"State primary school","options":{"sic":{"rephrased":"true"},"soc":{"rephrased":"false"}}}'
```

| Code | Meaning |
|---|---|
| 200 | Auth and the backend both work |
| 401 | Token problem. Check the error message (audience, issuer or expiry) |
| 404 | The path differs from `volume_test.py`. Use the real one from step 1 |
| 5xx | Auth passed, but the backend failed |

If the docs aren't exposed through the gateway, your local `/docs` shows the same API spec. Use that to find the endpoints and payloads.