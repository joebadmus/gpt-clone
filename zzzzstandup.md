Written for: today's stand-up.

> **Yesterday**
> - Started SA-1119, getting NatCen into the Terraform pipeline. I raised two small PRs: one adds NatCen to the Terraform triggers, and one pins NatCen's Terraform version to match dev and preprod.
> - Answered Dan's review comments on the Vertex AI region PR and added a test against the real libraries.
> - Raised a draft PR to set the NatCen Gemini model in Terraform.
>
> **Today**
> - Dan has looked over my open PRs. He's running a dev plan on the Gemini model PR, then approving it. Once it's in, I'll move the region and NatCen model PRs on.
> - Keep going on SA-1119: get the two pipeline PRs reviewed, then test with a small no-op NatCen PR.
>
> **Blockers**
> - None. Just reviews.

From this morning's catch-up with Dan, a few things change my earlier notes:
- **NatCen app deploys:** Dan said to keep them on merge to main for now, not promoting from preprod. When we do the vector store and SAYT UI pipelines, they should deploy on merge. I'll update the diagrams doc to match.
- **Service account access:** Dan confirmed the CI/CD service account has the same permission level on NatCen as on the other environments. So step 2 of SA-1119 may already be done, and the first pipeline run will confirm it.
- **Secrets:** Dan says you have the role to create secrets. That unblocks SA-1127, the separate Themes keys.



NOTE:

Hi , Matt agreed at refinement on 28 Oct to use the newer Gemini Flash model in NatCen only, as a temporary fix after 2.5 Flash was deprecated. It hasn't been evaluated yet, so it stays in NatCen until data science have looked at it. 3.5 Flash is what Dan set on NatCen already, so this just moves it into Terraform so an apply doesn't remove it. Nothing changes on what's deployed.
