The API code shows the follow-up flow works differently from how it was described in the meeting:

- **There is no endpoint that takes the follow-up answer and returns a final code.** Classify does two steps internally: the vector store builds a shortlist, then Gemini either returns a code or writes a follow-up question.
- **The follow-up answer is stored** through `POST /v1/survey-assist/result`, which saves to Firestore. It is not reclassified.

So the sequence is: classify, read `followup`, save the question and answer with `/result`, then read it back.

Sources: `api/models/classify.py`, `api/models/result.py`, `api/routes/v1/result.py`, and `SIC_SOC_ENDPOINT_CALLS_MASTER.md` in `survey-assist-api`.

---

### Step 0. Setup (same terminal)
```bash
cd /Users/joebadmus/my_ons.nosync/survey-assist-utils && source .venv/bin/activate
export API_GATEWAY=$(gcloud api-gateway gateways list --project=survey-assist-sandbox --format="value(defaultHostname)" --limit=1)
TOKEN=$(make generate-api-token | tail -1)
mkdir -p ~/sa-test && cd ~/sa-test
```

### Step 1. Classify with vague input and save the response
The repo's runbook notes that clear-cut jobs often return `classified: true`. A genuinely vague job forces a follow-up:
```bash
curl -s -X POST "https://$API_GATEWAY/v1/survey-assist/classify" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"llm":"gemini","type":"sic","job_title":"Worker","job_description":"I do various tasks depending on what is needed each day","org_description":"Small business","options":{"sic":{"rephrased":"true"},"soc":{"rephrased":"false"}}}' \
  > classify_ambiguous.json
python3 -m json.tool classify_ambiguous.json
```

### Step 2. What to look for in the response
Everything is under `results[0]`:

| Field | If a code was found | If a follow-up is needed |
|---|---|---|
| `classified` | `true` | **`false`** |
| `code` / `description` | the SIC code and its description | `null` |
| `followup` | `null` | **the question text** (this is what you extract) |
| `candidates[]` | `code`, `descriptive`, `likelihood` | the shortlist Gemini considered |
| `reasoning` | why Gemini chose the code | why it couldn't decide |
| `meta` (top level) | the options that were applied | same |

Pull out the key parts:
```bash
python3 -c '
import json; r=json.load(open("classify_ambiguous.json"))["results"][0]
print("classified:", r["classified"]); print("code:", r["code"])
print("followup:", r["followup"])
for c in r["candidates"]: print(c["code"], c["likelihood"], c["descriptive"])'
```
If `classified` is `true`, make the input vaguer and repeat step 1.

### Step 3. Answer the follow-up and save it with `/result`
Change `ANSWER` to a sensible reply to the question you got. This script builds the `/result` payload from your classify response, including the follow-up question and your answer:
```bash
ANSWER="Mostly repairing and servicing customers' cars" python3 - <<'EOF' > result.json
import json, os, datetime
r = json.load(open("classify_ambiguous.json"))["results"][0]
now = datetime.datetime.now(datetime.timezone.utc).isoformat()
print(json.dumps({
  "survey_id": "joe-test-survey", "case_id": "joe-test-case-001", "wave_id": "joe-test-wave",
  "user": "joe.test", "time_start": now, "time_end": now,
  "responses": [{
    "person_id": "joe-test-person-1", "time_start": now, "time_end": now,
    "survey_assist_interactions": [{
      "type": "classify", "flavour": "sic", "time_start": now, "time_end": now,
      "input": [
        {"field": "job_title", "value": "Worker"},
        {"field": "job_description", "value": "I do various tasks depending on what is needed each day"},
        {"field": "org_description", "value": "Small business"}],
      "response": {
        "classified": r["classified"], "code": r["code"], "description": r["description"],
        "reasoning": r["reasoning"],
        "candidates": [{"code": c["code"], "description": c["descriptive"], "likelihood": c["likelihood"]}
                       for c in r["candidates"]],
        "follow_up": {"questions": [{
          "id": "f1.1", "text": r["followup"], "type": "text",
          "response": os.environ["ANSWER"]}]}}}]}]}))
EOF

curl -s -X POST "https://$API_GATEWAY/v1/survey-assist/result" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d @result.json | tee result_response.json
```
You should get back `{"message": "Result stored successfully", "result_id": "..."}`. Copy the `result_id`.

### Step 4. Read it back to confirm it was stored
```bash
RID=$(python3 -c 'import json;print(json.load(open("result_response.json"))["result_id"])')
curl -s -H "Authorization: Bearer $TOKEN" "https://$API_GATEWAY/v1/survey-assist/result?result_id=$RID" | python3 -m json.tool
```
Check that `follow_up.questions[0].response` contains your answer.

### If something fails

| Result | Meaning |
|---|---|
| 404 on `/result` | The gateway config doesn't expose that path. Check the decoded route list from earlier |
| 503 on `/result` | Firestore isn't configured in sandbox (`FIRESTORE_DB_ID`), so it's a backend issue |
| 422 | The payload doesn't match the expected shape. The error message names the field |

Note: step 3 writes a test record to the sandbox Firestore. The IDs are clearly marked as test data (`joe-test-...`), but mention it when you post your update.

---

**Question to raise with the team:** in the meeting they said the platform sends the follow-up answer back "to turn it into a code". The current API only stores that answer; it doesn't return a code. Ask whether the final code is assigned later (offline or by analysts), or whether the UI calls classify again with the answer appended. The UI repo would answer this, and I don't have it locally.

Should I correct the sequence diagram in section 5.2 of the summary to match the actual code?