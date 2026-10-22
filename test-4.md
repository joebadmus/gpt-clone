Written for: your team chat. These are short updates and questions, ready to paste.

I created two Postman files in [postman/](postman/) for you to share:
- [survey-assist-api.postman_collection.json](postman/survey-assist-api.postman_collection.json)
- [survey-assist-sandbox.postman_environment.json](postman/survey-assist-sandbox.postman_environment.json)

The collection is grouped as **1. Lookup**, then **2. Classify** (clear input, then vague input that should get a follow-up), then **3. Result** (store, then read back). Each request has tests, and the description explains setup.

What I checked and what I couldn't:
- **Checked:** every script in the collection is valid JavaScript (node syntax check, 9 of 9 pass).
- **Not run:** I haven't sent it to sandbox, because I don't have your gateway host or token.
- **No secrets in the files:** before running, put your gateway host in `gatewayHost` and paste the token into `token`.
- **One side effect:** the store-result step writes a test record to the sandbox Firestore, with IDs prefixed `postman-test-`.

To run it from the terminal instead of the Postman app:
```bash
postman collection run survey-assist-api.postman_collection.json \
  -e survey-assist-sandbox.postman_environment.json \
  --env-var gatewayHost=<host> --env-var token=<jwt>
```

---

**Update message:**

> Quick update on the Survey Assist testing:
> - Got the API running locally (Swagger at `/docs`).
> - Generated a JWT with `survey-assist-utils` and connected to the **sandbox API through the gateway**.
> - Tested end to end: `classify` with clear input (code returned), `classify` with vague input (follow-up question returned), then `result` store and read back. All working.
> - Went through the API and UI code to map the full flow. Write-up with diagrams to follow.
> - Made a **Postman collection** for the sandbox calls (attached). To test NatSen, just change the environment.
>
> Note: I wrote one test record to the sandbox Firestore (IDs start with `postman-test-`).

**Questions:**

> 1. After a follow-up question, nothing in the API or UI works out a final code. The answers are only saved via `/result`. Is the final code assigned later in analysis?
> 2. In the demo it sounded like NatSen would send the follow-up answer back to get a code. Is that a new endpoint we need to build, or will NatSen just store it via `/result`?
> 3. Will NatSen use `/sic-lookup` before `/classify`, like our UI does?
> 4. When is the NatSen environment due, so I can rerun the collection against it?

**Minor docs note, if you want to include it:**

> In `survey-assist-utils`, the README says `unset GOODLE_APPLICATION_CREDENTIALS`, which should be `GOOGLE_`. Happy to raise a small PR.