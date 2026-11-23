Here's your stand-up, ticket by ticket:

> **SA-1241 (VPN IPs on the GKE allow-list)**
> Added the ONS VPN IPs to the sandbox and preprod allow-lists and applied them. kubectl still fails because Cisco on our Macs inspects the traffic and swaps the certificate. I confirmed that with the certificate issuer. The DNS endpoint works as a workaround. I've raised a ServiceNow request to have the cluster IPs taken out of SSL inspection.
>
> **SA-1244 (maintenance exclusion)**
> Added an optional maintenance exclusion to the GKE module. Agreed with Ethan to test it for two weeks in sandbox first and leave preprod alone for now. This morning the sandbox plan showed the one expected change, preprod showed no changes, and the PR is ready for review. I raised SA-1266 to set the preprod dates once we know when the public test is.
>
> **SA-1163 (Terraform 1.17.2)**
> Still blocked. Ethan pointed me to Platform Engineering, who own the binaries bucket, and I've emailed them.
>
> **SA-1235 (NatCen log bucket)**
> Ticket written and ready to start. It reuses our existing log bucket module. I need Dan to agree the retention period.
>
> **SA-1127 (Themes Flask key)** and **SA-1119 (NatCen pipeline)**
> PRs still waiting on review.
>
> **Today**
> - Start SA-1235.
> - Apply the sandbox exclusion once SA-1244 is merged.
> - Chase the reviews.
> - Raise the NatCen plan drift with Dan.
>
> **Blockers**
> - The Terraform binary from Platform Engineering.
> - The Cisco SSL bypass.
> - Reviews on the open PRs.

The NatCen drift comes from your ticket notes this morning. Planning NatCen from main would destroy 16 resources, including the GKE cluster, because NatCen was deployed from Dan's original branch. Worth saying out loud at stand-up, so nobody applies NatCen from main.


====
That makes sense. Here are the seven titles, ready to paste into Jira under SA-962:

1. **Load testing: review last year's setup and agree the approach with Jeff**
2. **Load testing: build a dashboard for the SAYT UI and its backend services**
3. **Load testing: prepare sandbox and pre-prod (Cloud Armor, access codes, Gemini quota)**
4. **Load testing: practice runs in sandbox (baseline, realistic, stress)**
5. **Load testing: tune Cloud Run and GKE scaling from the sandbox results**
6. **Load testing: size pre-prod like the public test for the final run**
7. **Load testing: final run in pre-prod and write up the results**

Two things to do before you create them:
- **Check ticket 2 with Dan first.** It might overlap with L2 or L5 from the 16 Nov logging plan. If those already exist, link ticket 2 to them, or drop it.
- **Ticket 5 only applies if the results show problems.** You could create it now as a placeholder, or wait until the sandbox runs are done.

Send me the Jira numbers when you have them and I'll write up each ticket in full.


=====
Here's your stand-up update, ticket by ticket:

**SA-1274, load testing approach:** Call with Geoff at 3 today to go through last year's setup and how to run the Locust suite. I'll aim to leave able to run it myself, and with rough dates for the practice runs and the final pre-prod run.

**SA-1244, GKE maintenance exclusion:** The PR is ready for review. Dates are moved to 25 Nov to 9 Dec, and the plans are clean. Once it's merged, I'll apply sandbox, targeting just the cluster so Dan's WAF changes stay as they are.

**SA-1266, pre-prod exclusion:** I've widened it to cover the final load test as well as the public test. I'll raise the PR once SA-1244 is merged and the load test dates are known.

**SA-1127, Themes Flask key:** PR still waiting on review.

**SA-1163, Terraform 1.17.2:** Still blocked. The 1.17.2 binary isn't in the CI binaries bucket yet, so I need someone with access to upload it.

**SA-1119, NatCen pipeline:** Back in draft. We agreed not to turn on apply-on-merge or apply anything to NatCen until testing is finished.

**Possible new tickets:**
- The PR plan triggers only watch each environment's folder, so a change that only touches `modules/` never gets planned by the pipeline.
- Apply the NatCen Terraform after NatCen testing, if that isn't already ticketed.
