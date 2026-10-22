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