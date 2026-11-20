I've put the full summary, actions, draft tickets and questions in [2011-Matt.md](meeting/2011-Matt.md).

**What Matt wants from you:** you own the infrastructure side of load testing, working with Jeff. That means a dashboard, getting the environment ready, running the tests with Jeff, and making Terraform fixes (like Cloud Run concurrency or scaling) if the results show problems. Jeff moves to other work around the start of December, so it needs to be ready to run before then. The Teams message asks you to raise tickets for this under SA-962.

**The plan Matt set:** first a run in sandbox exactly as it is now, to prove the test and dashboard work. Then tune and run again. Then a final run in pre-prod with production settings before going public. Jeff suggested two kinds of run: a realistic one with about 50 users and pauses between steps, and a stress test with no pauses. Steve's minimum benchmark is 25 users at once.

**Seven tickets, at a high level:**
1. Review last time's load testing setup with Jeff and agree the approach.
2. A load testing dashboard for the SAYT UI and the services behind it.
3. Get the environment ready: Cloud Armor allow-list, a separate batch of access codes, and Gemini quota and cost.
4. Practice runs in sandbox.
5. Tune the infrastructure from the results (only if needed).
6. Size pre-prod like the public test.
7. Final pre-prod run and a write-up.

**Things you might have missed:**
- **The dashboard may already be ticketed.** The 16 Nov logging plan has L2 (SAYT UI dashboard, Ethan/Jeff) and L5 (golden signals). Check with Dan before raising ticket 2, so you link to those instead of duplicating them.
- **Access codes could clash.** Locust uses up a code on every journey. Generating more codes wipes the whole set, which would also wipe the testers' codes in pre-prod. Ask for a separate batch for Locust.
- **Two items have no clear owner and might land on you:**
  - Steph or Charlie offered to show "Dan or Joe" how to generate the codes.
  - Someone offered to run Playwright on pre-prod by Monday or Tuesday.
- **Cloud Armor:** testers' IPs need adding, and the Locust machine's IP will need it too. Any rate-limiting rules could throttle the load test.

**Questions to ask first:**
- When does manual testing in pre-prod end? That sets when the final run can happen.
- What counts as a pass? For example, a p95 latency limit and an error rate at 25 and 50 users.
- What production settings should pre-prod use, and who approves the cost?
- Jeff: which PRs need merging, where does Locust run from, and does each journey call Gemini?

The file has the full list of 14 questions. A few names in the transcript, like "Jerry" and "Jeff", might be misheard, so check them against the invite. Send over anything else you have and we can turn these into full tickets.
