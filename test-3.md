I've rewritten the follow-up diagram (section 5.2) in [app-demo-summary.md](app-demo-summary.md) using what's in the UI code, and added the login service to the overview diagram (5.1).

**What the UI shows:**

1. **No final code is ever produced after a follow-up.** Neither the UI nor the API reclassifies the answer. The UI keeps it in the session and sends everything once, in `POST /result` at the end of the survey. The final code must be assigned later, most likely by analysts working from the stored data.

2. **A lookup happens before classify.** The UI first calls `GET /sic-lookup` with the organisation description. If that finds an exact match (the README's example is "pubs"), **classify is skipped entirely** and Gemini isn't called. You haven't tested `/sic-lookup` on sandbox yet:
   ```bash
   curl -s -H "Authorization: Bearer $TOKEN" "https://$API_GATEWAY/v1/survey-assist/sic-lookup?description=pubs&similarity=true" | python3 -m json.tool
   ```

3. **When classify can't decide, the user gets two follow-up questions:**
   - **First, an open question:** the text Gemini wrote, answered in a free-text box.
   - **Second, a closed question the UI builds itself:** "Which of these best describes your organisation's activities?", with the candidate descriptions plus "None of the above".

   This is the open-versus-closed trial mentioned in the meeting. It's switched on by `FOLLOW_UP_TYPE = "both"` in `utils/survey_assist_utils.py`.

4. **These are all the endpoints the old UI calls,** which is the list you were promised:
   - `/sic-lookup`
   - `/classify`
   - `/result`
   - `/feedback`

   NatSen needs `/sic-lookup` and `/classify`, plus `/result` if they decide to send results back.

5. **The token audience is the gateway host without `https://`.** The UI strips the scheme before generating the token, so the README was right.

6. **Logging in uses a separate service.** The access code is checked by an OTP verification service on Cloud Run with its own Firestore, called with a Google ID token rather than the gateway JWT. That's one more microservice the meeting didn't mention.

7. **The "login decorator" from the meeting is `require_access()`** in `utils/access_utils.py`. It runs before every page. Making it `return None` bypasses login, but only do that locally.

8. **`scripts/run_api.py` is the "better instructions" from the meeting.** It covers `config`, `lookup`, `classify`, `both`, and the OTP verify calls:
   ```bash
   poetry run python scripts/run_api.py --type sic --action both
   ```

9. **The UI doesn't send `options`,** so the API's default `rephrased=true` applies. Your curl tests with the same settings match what the UI does.

**For the team chat:** the open question is now more specific. Ask: "After a follow-up, nothing in the API or UI computes a final code. The answers are only stored via `/result`. Is the final code assigned in analysis? And what should NatSen do with the follow-up answer, since the meeting suggested they'd send it back to get a code?"