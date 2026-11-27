Here's a stand-up update you can read out or paste:

**Since yesterday**

- **SA-1277 / SA-1278 (load testing and tuning):** We ran the baseline and the rerun with Geoff and Ethan. Before the API change, searches failed from about 15 users. After it, there were no failures up to 25 users, and searches stayed under 3 seconds. Ethan approved the Terraform change and it's merged, so SA-1278 is done. Results are on Geoff's Confluence page.
- **SA-1244 (GKE maintenance exclusion):** Merged, applied to sandbox and showing on the cluster. Done.
- **SA-1241 (GKE access from ONS laptops):** The Cisco fix works for me, but it's per person: IT added me to a Cisco group. I've asked them to add the rest of the team. Until then, Ethan and others can keep using the DNS endpoint.
- **SA-1127 (Themes Flask key):** I answered Rupert's question on the PR. It still needs a review.

**Today**

- **SA-1279 (pre-prod sizing):** I've added the API recommendation from sandbox. Next is agreeing the public test settings and cost with Matt and Steve.
- **Vector store timing log:** the PR is waiting on Rupert's review. Once it's merged, I'll deploy it to sandbox.
- **Next load test:** I'm agreeing with Geoff and Ethan what we run next, probably a longer run at 25 users or a login burst.
- **Chasing reviews** on the load testing dashboard (SA-1275) and the Flask key.

**Blockers / asks**

- Dates for the final pre-prod load test and the public test. SA-1266 and SA-1279 both need them.
- IT adding the rest of the team to the Cisco group.


====
We changed the API from 1 instance handling up to 80 requests at once, to 5 to 10 instances handling 5 each. One instance can only really work on a handful of requests at a time, so with 80 allowed, searches queued up on that one instance until the UI gave up after 10 seconds. With concurrency at 5, Cloud Run spreads the searches across instances instead of queueing them, so nothing waits long enough to time out.

===
**Done**
- **SA-1277 / SA-1278:** The load test rerun after the API change had no failures up to 25 users. The change is merged, so SA-1278 is done.
- **SA-1244:** The GKE maintenance exclusion is merged and applied in sandbox. Done.
- **SA-1241:** The Cisco fix works for me. I've asked IT to add the rest of the team.

**Today**
- **SA-1279:** Agree the pre-prod settings and cost with Matt and Steve.
- **Timing log:** waiting on Rupert's review, then I'll deploy it to sandbox.
- **Next load test:** agree it with Geoff and Ethan.

**Need**
- Dates for the final load test and the public test.
