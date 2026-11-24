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
