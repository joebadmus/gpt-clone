Context: I'm working in the survey-assist-terraform repo (in my target-repo folder). There's an
open draft PR on branch feat/sa-1275-load-test-dashboard that adds a Cloud Monitoring load testing
dashboard for the SAYT UI and its backends. The template is dashboards/load-testing.json.tftpl,
sandbox applies it in survey-assist-sandbox/dashboards.tf, and dashboards/README.md explains the
template variables.

Task: compare our dashboard with last year's hand-built dashboards in survey-assist-sandbox,
add anything useful we're missing, and push the change to the same PR.

1. git fetch origin && git switch feat/sa-1275-load-test-dashboard && git pull
2. Export last year's custom dashboards:
   gcloud monitoring dashboards list --project=survey-assist-sandbox --format=json > /tmp/old-dashboards.json
   Focus on "Survey Assist UI microservice", "Survey Assist API microservice" and
   "Firestore OTP API microservice". Look at "Survey Assist Participation" too, but don't copy
   its log-based funnel panels (that's a separate ticket, L2). Ignore the SIC vector store,
   OTP CLI and Vertex AI dashboards.
3. List each panel in those dashboards (title, metric, aggregation) and compare it with
   dashboards/load-testing.json.tftpl. Write the comparison in a table: panel, in ours (yes/no),
   add it (yes/no), and why.
4. Add the missing panels that help during a load test. Keep the existing layout style
   (mosaicLayout, 48 columns, 16x16 charts, 3 per row, a text header per section).
   Use the template variables (${ui_service}, ${api_service}, ${otp_service} and so on) and
   never hard-code project IDs or service names. Old dashboards use old service names, so map them
   to the current ones: sayt-ui, survey-assist-api, firestore-otp-api. Don't add log-based or
   SQL panels.
5. Check the template still renders to valid JSON. Use terraform console or a small scratch .tf
   file outside the repo, calling templatefile() with the sandbox values from dashboards/README.md
   and jsondecode().
6. In survey-assist-sandbox, run terraform init and then a targeted plan ONLY:
   terraform plan -target=google_monitoring_dashboard.sayt-load-testing
   Never do a full plan or apply. Sandbox has WAF changes from another branch that a full apply
   would remove. Don't apply anything, and never use -lock=false.
7. Update dashboards/README.md if anything changes (for example the "Not covered yet" list).
8. Stage the changes but DON'T commit. Commits must be GPG signed, and the passphrase prompt only
   works in my own terminal. Give me the exact git commit command to run, with a message like
   "feat: sa-1275 - add panels from last year's dashboards". Don't add any Co-Authored-By line
   or any mention of AI. Don't stage the exported old dashboards.
9. Show me the comparison table, the targeted plan summary and the git diff --stat. Then stop.
   I'll commit and push myself.
