# Monitoring: SAYT UI dashboard from the logs (latency per page and survey progress)

**Status:** draft, not raised. Check with Dan and Ethan first. They said at the 16 Nov infra sync that they'd raise the dashboard tickets.
**Suggested labels:** SAYT public test, monitoring
**Assignee:** Ethan and Geoff (agreed on 16 Nov). Geoff moves to other work in early December, so confirm who picks it up.
**Depends on:** SAYT UI logging (Steph) for the survey progress part. Latency per page doesn't depend on it.
**Related:** SA-1275 (load testing dashboard, which set up the `dashboards/` folder), SA-1280 (final pre-prod load test)

## Description

At the 16 Nov infra sync we agreed to keep dashboards as code, and to start with a dashboard for the SAYT UI. It should show two things that standard metrics can't:

- **Latency per page.** How long each page of the survey takes, from the load balancer logs.
- **Survey progress.** How many people reach each stage of the survey, counted by user ID from the UI logs.

Last year had both, but they were built by hand in sandbox, used the old service names, and never reached pre-prod.

SA-1275 already added a metrics-only load testing dashboard and a `dashboards/` folder in the Terraform repo, with templated JSON and notes on avoiding drift. This ticket adds the log-based dashboard using the same approach, with the SQL queries kept next to the JSON.

## Approach

1. Check with Dan and Ethan that this hasn't been raised already.
2. **Latency per page.** Write a log analytics SQL query on the SAYT log bucket. It already includes the load balancer logs. Group requests by page path, with query strings stripped, and show p50, p95 and p99 latency and the request count.
3. **Survey progress.** Once the UI logs the user ID and a marker for each stage, write a query that counts distinct users reaching each stage. Use last year's participation dashboard as a guide. It's the "Survey Assist Participation" custom dashboard in sandbox.
4. Build both charts in the sandbox console, in a new dashboard.
5. Export the JSON, template the project ID and the log bucket name, and add it to `dashboards/` with the SQL in its own files. Follow the drift notes in `dashboards/README.md`.
6. Apply to sandbox, then dev. Plan it for pre-prod so it's ready for the public test.

## Things to be aware of

- Don't show individual user IDs on the dashboard, only counts.
- Use targeted applies in sandbox until the WAF and other branch changes are merged. A full apply from main can undo them.
- The CI/CD service account needs a role that can manage dashboards before pre-prod can apply it through the pipeline. This is already noted for SA-1279.
- If the logging work isn't ready, deliver latency per page first and add survey progress in a follow-up.

## Definition of done

- [ ] Confirmed with Dan and Ethan that it's not a duplicate
- [ ] Latency per page shows real data in sandbox
- [ ] Survey progress shows real data in sandbox (or split into a follow-up if the UI logging isn't ready)
- [ ] Dashboard JSON and SQL in `dashboards/`, templated per environment
- [ ] Applied to sandbox and dev, with a plan after the apply showing no changes
- [ ] Planned for pre-prod
- [ ] Short note in `dashboards/README.md` on the SQL files and how to update them



====
Hi Ethan, Dan, two things on dashboards.

First, I've built a load testing dashboard for SAYT, and the PR is up for review. It's already applied to sandbox. It's metrics only: load balancer, Cloud Run, the GKE vector store, Redis and Cloud Armor. It also sets up the dashboards-as-code bits we talked about at the 16 Nov infra sync. There's a dashboards folder in the Terraform repo with templated JSON, and a short README on changing a dashboard without causing drift. Could one of you have a look when you get a chance? Link below.

Second, the SAYT UI dashboard from that meeting, the one with latency per page and the survey progress funnel. Is anyone working on it, and where has it got to? It's needed before the load tests, and Geoff moves to other work in early December. If nobody has picked it up, I'm happy to start on latency per page, since sandbox already has what that needs. Survey progress depends on Steph's UI logging, so that would come after. I've got a draft ticket ready if it hasn't been raised yet.
