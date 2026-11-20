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
