Hi Ethan, Dan, quick one on the dashboards we talked about at the 16 Nov infra sync. I've built a load testing dashboard for SAYT (SA-1275), and the PR is up for review [link]. It's applied to sandbox already.

It's metrics only: load balancer, Cloud Run, the GKE vector store, Redis and Cloud Armor. So it's not the SAYT UI dashboard we said we'd start with. The latency per page and survey progress funnel still need the log analytics queries.

It does set up the dashboards-as-code bits we discussed, though. There's a dashboards folder in the Terraform repo with templated JSON, and a short README on how to change a dashboard without causing drift. So the SAYT UI dashboard and the others could build on it rather than start from scratch.

Has a ticket been raised for the SAYT UI dashboard yet? If so, I'll link it to mine.


**Dashboard (SA-1275):**
- It's live in sandbox and showing data. The PR is up for review, and the link is on Confluence.

**GKE exclusion (SA-1244):**
- It's applied to sandbox and waiting for a review.

**Load testing (SA-1274, SA-1276, SA-1277):**
- I've added the infra bits to Geoff's page, and the smoke run passed.
- Next, I'm getting more access codes, and we need Geoff's feedback PR merged before Test 1.

**Reviews:**
- I've looked at Rupert's vector store pipeline PR. I'll comment once he's finished his changes.

**Asks:**
- Could someone review the dashboard and GKE exclusion PRs, please?
