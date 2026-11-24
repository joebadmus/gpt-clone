The merged PR is SA-1141, the employee journey without feedback. Steve approved it, and it merged yesterday at 16:14. SA-1142, which adds the feedback questions, is still open. Charlie has tested it locally and Geoff has run it against sandbox, but nobody has formally approved it yet.

**What the merged journey does:**
- It logs in and answers questions Q1 to Q6b, then the guidance pages G1 and G2. It stops there, so there's no feedback yet.
- There's one search-as-you-type question (business activity). It makes 1 to 5 searches, each a longer part of the full answer, the way someone types.
- Think time is 12 to 30 seconds per answer, with 0 to 3 seconds between searches.
- It's a shorter journey than the 15 pages I assumed in the summary, so each one takes about 2 to 3 minutes.

**What I'd do next, in order:**

1. **Run it yourself on main today, with 1 or 2 users against sandbox.** You don't need to wait for SA-1142, because the journey without feedback is enough to check the infra side.
   ```sh
   git clone https://github.com/ONSdigital/survey-assist-load.git
   cd survey-assist-load/locust_tests
   make install
   cp suites/sayt/data/credentials.csv.example suites/sayt/data/credentials.csv
   cp sayt.conf.example sayt.conf
   ```
   In `sayt.conf`, set `host = https://sayt.sandbox.survey-assist.gcp.onsdigital.uk`, `users = 1`, `spawn-rate = 1` and `run-time = 5m`. Then run `make run-sayt` and open `http://localhost:8089`.
2. **Ask Geoff for a few sandbox access codes.** Don't generate a new set, because that wipes the existing codes. Each journey uses one code, so 10 to 20 is plenty for a few short runs.
3. **While it runs, watch the vector store pods** with kubectl through the DNS endpoint, and check Cloud Run in the console. That tells you what the dashboard (SA-1275) needs to show.
4. **Help get SA-1142 merged.** Once your run works, you could run the SA-1142 branch the same way and leave a short approval or comment. That's the last blocker before the full baseline run with Geoff.

**For stand-up:**

> Geoff's first load test PR is merged. I'm setting the suite up locally today and doing a small run against sandbox to check the infra side, while the feedback PR gets reviewed.


====
Hi Geoff, I've had a read of the page and it's really helpful. The targets look good to me. A few thoughts on Test 1:

Could we run it for 10 minutes instead of 1, so things settle and the vector store has time to scale?
A spawn rate of 1 to 5 a second might be better than 25, as logging everyone in at once could swamp the OTP service in sandbox.
With no think time, it's really a stress test, so maybe add a realistic run with think time at 25 and then 50 users.
We'll need more codes for it, as no-think-time journeys use them quickly.
Also, I meant I'm happy to run and review your feedback PR, not raise one. 🙂 I'll add the infra bits to the page later today


=====
No, not yet. Most of the learning part is done, but the "agree the approach" part isn't, and that's what the ticket is for.

**Done**
- You've been through last year's material with Geoff.
- You know where Locust runs from: a laptop on the VPN for sandbox.
- No Gemini calls are involved, so there's no LLM cost.
- If you ran this morning's test yourself, you can tick "Joe can run the suite on his own" too.

**Still open**
- The realistic and stress scenarios aren't agreed yet, including user counts and think times.
- Pass/fail limits haven't been agreed with Matt and Steve.
- Geoff's parameters page on Confluence isn't finished or linked from SA-962.

The last three depend on the parameters call this week with Steve, Matt, Ethan and Dan. Close SA-1274 straight after that call, once Geoff's Confluence page has the agreed numbers. That should be before the first proper sandbox run on Wednesday or Thursday.

For stand-up, you could say: "SA-1274 is nearly done. I'll close it once we've agreed the parameters this week."

If the team would rather close it now, move the scenarios and limits into SA-1277 so they don't get lost. Keeping it open is cleaner, though.



=======
I couldn't confirm which PR merged or what the run showed, because `gh` isn't installed here and there are no notes from this morning yet. I've assumed SA-1141 (the main journey) merged and SA-1142 (feedback) is still in review. I've left a gap for the results, so fill that in.

**Yesterday**
- Had the load testing handover with Geoff (SA-1274) and went through how the new Locust suite works and what last year's run found.
- Raised the load testing tickets SA-1275 to SA-1280: the dashboard, preparing the environments, the sandbox practice runs, sizing pre-prod, and the final pre-prod run.
- Moved the sandbox maintenance exclusion dates on SA-1244 to 25 Nov to 9 Dec. The PR is still waiting for review.
- Went to the IAM handover session.

**This morning**
- SA-1141 is merged, so I met Geoff and we ran the first small baseline load test against sandbox. [Add: number of users, how it went, anything that stood out]
- SA-1142 is still in review, so the feedback part of the journey isn't in the run yet.

**Today**
- Raise the GKE control plane cert issue with the managed Mac team, from the retro action. It's also blocking Dan's RBAC testing. We're using the DNS endpoint as a stopgap.
- Set up the load test dashboard and finish the sandbox prep before the first proper run on Wednesday or Thursday. That includes the Redis connection limit Geoff flagged.
- Chase a review on SA-1244 so the exclusion is in place before the load tests.

**Blockers**
- SA-1142 needs merging before we can run the full journey with feedback.
- No load testing in pre-prod this week, because functional testing starts there.

If I've got the wrong PR, or you send me the results from this morning, I'll update it.
