stand-up and defend if asked.

**Stand-up**

> **Yesterday:** Got the Gemini model override, the Vertex AI region and the NatCen Gemini model merged, plus the Terraform version pin, so every environment is on the same version now. This morning the API side of the Vertex AI region change went in too, so that ticket's done.
>
> **Today:** Starting the Terraform version ticket. I've got a small tidy-up ready, and I'm waiting on Dan to confirm which version we move to before I raise it, so it all goes in one PR.
>
> **NatCen CI/CD ticket:** It's nearly there, but it can't be finished until NatCen finish testing, which is next week. I'll explain below if anyone asks.

**If someone asks why SA-1119 is still open**

> The code's basically done. The pipeline change is raised and in review, and the version pin it needed is merged. What's holding it is that NatCen are testing right now, and we agreed with Dan not to apply anything to their environment until they finish, so we don't disrupt them. Proving the pipeline properly needs a real plan and apply, so we can't close the ticket until after their testing. That's next week.
>
> There's also some catching up to do. The NatCen code in main was renamed after NatCen had already started testing, so main and what's deployed don't match yet. One apply after testing sorts that out, and I've got a small PR in review to make that apply safer.
>
> So it's not stuck, it's waiting on NatCen's testing window. I'd expect to close it the week after.

**Things that could come up**
- **"Can't you just apply it?"** "We could, but Dan and I agreed not to risk disrupting NatCen during testing. The plan removes some network resources, and there could be a dependency we haven't spotted."
- **"What about the app deployments?"** "The NatCen app triggers PR is in draft. It needs that same apply first, plus the data in the NatCen bucket, which Dan's checking."
- **"Anything blocking you?"** "Only the NatCen testing window. I'm also checking the CI/CD service account has enough access to NatCen for plans to run in the pipeline."


==============
==============
That confirms the gap. The pipeline service account is **Owner on dev, but not on NatCen**. The other five roles match. Owner is what lets Terraform read and change everything, so without it NatCen plans in the pipeline would fail. Dan's "same permission level" isn't quite true for NatCen.

There's one more check we can do ourselves first. That comparison only shows roles granted directly on each project. Owner could still be inherited from a folder above NatCen. This shows inherited roles too:

```bash
gcloud projects get-ancestors-iam-policy survey-assist-sandbox-external --flatten=policy.bindings --filter="policy.bindings.members:ons-cicd-surveyassist@" --format="table(id,type,policy.bindings.role)"
```

- **If Owner appears** against a folder or organisation, NatCen is fine and nothing's needed.
- **If it doesn't**, it's a real gap. Granting Owner is sensitive, so it's one for Dan:

> Hi Dan, I compared the CI/CD service account's roles on dev and NatCen. On dev it's Owner, but on NatCen it only has the deploy roles, and it doesn't inherit Owner from a folder either. Without it, NatCen plans in the Terraform pipeline will fail. Could it get the same Owner role on NatCen, or would you prefer narrower roles there?



=======
=======
Yes, it's in the pipeline run, and there are two places to see it.

**1. On the PR, the easiest.** Open https://github.com/ONSdigital/survey-assist-terraform/pull/196, scroll down to the checks, and click **Details** next to `ons-survey-assist-dev-terraform-pr`. The build log there shows the error near the bottom. That's where I read it from.

**2. In Cloud Build, on the Jamf machine.** These are the two failed runs, in the `ons-cicd-surveyassist` project:
- **Dev:** https://console.cloud.google.com/cloud-build/builds;region=europe-west2/e460629e-759d-4b44-8c68-a7969b4ed2f6?project=113332539420
- **Preprod:** https://console.cloud.google.com/cloud-build/builds;region=europe-west2/456af1b2-191f-4fab-81be-e73560d463be?project=113332539420

Open one, click the first step (`gcr.io/cloud-builders/gcloud`), and you'll see:

```
CommandException: No URLs matched: gs://ons-ci-binaries/terraform-1.17.2
```

You could include the dev link in your message to Dan, so he can see it himself.


=====
=====
Written for: Dan, on Teams.

> Hi Dan, I've raised the Terraform 1.17.2 PR as a draft. The dev and preprod plan checks fail straight away because terraform-1.17.2 isn't in the ons-ci-binaries bucket ("No URLs matched"). Here's the dev run: https://console.cloud.google.com/cloud-build/builds;region=europe-west2/e460629e-759d-4b44-8c68-a7969b4ed2f6?project=113332539420
>
> Could that version be added, or do you know who looks after the bucket? Once it's there I'll rerun the checks.
