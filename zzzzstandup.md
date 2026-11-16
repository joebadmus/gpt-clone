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
You have 7 open PRs, newest first:

| PR | Ticket | What it does | Status |
|---|---|---|---|
| [cicd 128](https://github.com/ONSdigital/survey-assist-cicd/pull/128) | SA-1119 | NatCen app deploy triggers: API and SAYT UI deploy on merge to main, vector stores are run by hand | Needs review. Check the project number and lookup CSVs first |
| [terraform 194](https://github.com/ONSdigital/survey-assist-terraform/pull/194) | SA-1119 | Pins NatCen and sandbox to Terraform 1.11.0, like dev and preprod | Rupert's change is done. Needs approval |
| [cicd 127](https://github.com/ONSdigital/survey-assist-cicd/pull/127) | SA-1119 | Adds NatCen to the Terraform pipeline: plan on PR, apply after merge | Needs review |
| [terraform 192](https://github.com/ONSdigital/survey-assist-terraform/pull/192) | SA-1166 | Sets the NatCen Gemini model (3.5 Flash) in Terraform so an apply doesn't remove it | Draft, waiting on 189. Changelog added |
| [terraform 190](https://github.com/ONSdigital/survey-assist-terraform/pull/190) | SA-1165 | Optional Vertex AI region setting for the API | Stacked on 189 |
| [api 82](https://github.com/ONSdigital/survey-assist-api/pull/82) | SA-1165 | API reads the Vertex AI region from an env var, defaulting to europe-west2 | Needs review |
| [terraform 189](https://github.com/ONSdigital/survey-assist-terraform/pull/189) | SA-1166 | Optional Gemini model setting for the API | Dan is planning it on dev, then approving |

PR 189 is the one to get merged first, because 190 and 192 both depend on it.
