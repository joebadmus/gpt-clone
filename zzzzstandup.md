grep "^Plan:" natcen.txt
grep -c "will be destroyed" natcen.txt
grep -E "google_container_cluster|node_pool" natcen.txt
grep -B3 "forces replacement" natcen.txt | grep -E "^\s+#|forces" | head -40



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


gcloud projects get-iam-policy survey-assist-sandbox-external --flatten=bindings --filter="bindings.members:ons-cicd-surveyassist@" --format="value(bindings.role)"
gcloud storage buckets get-iam-policy gs://survey-assist-natcen-sandbox-external-terraform-remote-backend | grep -B2 ons-cicd-surveyassist


What happens after his answer

Hi Dan, quick one on NatCen app deploys. I set them up to build on merge to main, but that builds a separate NatCen image, and the NatCen bucket doesn't have the data files the build needs. We already have a NatCen promote pipeline for the API that deploys the same release image preprod is running, no rebuild and no data needed. Are you happy for NatCen to use that instead? Also, how were the current NatCen images built?

Written for: Dan, on Teams.

> Hi Dan, quick one on NatCen app deploys. I set them up to build on merge to main, but that builds a separate NatCen image, and the NatCen bucket doesn't have the data files the build needs. I've put that PR back to draft for now.
>
> We already have a NatCen promote pipeline for the API that deploys the same release image preprod is running, so no rebuild and no data needed. Are you happy for NatCen to use that instead? Also, how were the current NatCen images built?

If he picks promote, I'll switch the API trigger over and give NatCen's Cloud Run read access to the API release registry.


=====
Hi Dan, I ran a plan on NatCen from main and got 6 to add, 32 to change, 16 to destroy. It looks like what's deployed came from your original branch: GKE on and the natcen-external-sandbox domain. Main has GKE commented out and the domain renamed to sandbox-external. Was that intended, or should main match what's running? I haven't applied anything. Worth sorting before NatCen goes on apply on merge.
