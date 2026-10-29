**SIC** isn't an endpoint. It's the industry code the app is trying to find. For example, `43210` means "electrical installation". The three endpoints are three steps towards that code.

**The happy path**, using the API directly with no UI:

```
Person describes their job and what their company does
   │
   ▼
1. LOOKUP     GET /sic-lookup     "Is this an exact match in the SIC list?"
   │            yes → returns the SIC code → go to step 3
   │            no  ↓
   ▼
2. CLASSIFY   POST /classify      "AI, which SIC code fits best?"
   │            sure     → returns the SIC code
   │            not sure → returns a follow-up question + a shortlist of codes
   │                        (person answers or picks one from the list)
   ▼
3. RESULT     POST /result        "Save everything the person said and got back"
```

**Like you're 10:** it's like asking a librarian where a book goes.
- **Lookup:** they check the index. If the title is there exactly, done.
- **Classify:** if it's not in the index, they think it over and suggest the best shelf. If they're unsure, they ask you one more question.
- **Result:** they write down everything in a notebook so someone can check it later.

The "type, see a list, pick one" journey you described is the new search-as-you-type UI. In the API flow above, picking from a list only happens at the follow-up stage.



====
Written for: the dev channel (Steve and the wider Survey Assist team).

> Hi all, here's a summary of today's infra sync with Ethan, Matt, Dan and me, following on from the NatCen environment deployment.
>
> **The NatCen environment (`sandbox-ext`) is up**, and we went through the issues Dan and I found while deploying it. Nothing blocks NatCen, and all fixes will go in as small, separate PRs.
>
> **Next up:**
> 1. Add the NatCen project to the CI/CD repo, so Terraform is planned on each PR and applied on merge.
> 2. Move the test proxy from the sandbox into the CI/CD project, to support the Locust and Playwright work.
> 3. Build each image once and deploy it everywhere through the CI/CD registries.
>
> Also in there: making the Flask secret project-specific (rolled out to all environments), the longer-term move to GKE, and the open decision on the gateway and auth approach.
>
> @Steve, a couple of these touch things you set up originally (the Flask secret and `users.json`), so it'd be good to get your view.
>
> The full summary is below. It includes tickets and infrastructure diagrams. Comments and corrections welcome 👇

If you want something shorter:

> Hi all, here's the outcome of today's infra sync on the NatCen environment: what we agreed, the prioritised tickets, and infrastructure diagrams. Top of the list: adding the NatCen project to the CI/CD repo, moving the test proxy into CI/CD, and building each image once and deploying it everywhere. Thoughts and corrections welcome, especially from @Steve on the Flask secret and the move to GKE 👇

If you paste the whole summary into the channel, its first section (the summary for Matt) is the best part to post.


Update
===========
=========
No, don't ask for review yet. The approach is right (deploying by digest, and checking that the promoted image matches the one tested), but two bugs mean both pipelines would fail on their first run. Both are quick to fix.

## Blockers

**1. Bash variables need `$$` in Cloud Build YAML**
- Files: [cloudbuild_dev_and_sandbox.yaml:31-38](../survey-assist-api/cicd/cloudbuild_dev_and_sandbox.yaml#L31-L38) and [cloudbuild_promote_preprod.yaml:9-38](../survey-assist-api/cicd/cloudbuild_promote_preprod.yaml#L9-L38).
- **Problem:** Cloud Build treats every `$name` as one of its own substitutions. `$image_digest`, `$source_image`, `$source_digest`, `$release_image`, `$release_digest` and `${source_digest#*@}` aren't Cloud Build variables, so it rejects the build with `key in the template "image_digest" is not a valid built-in substitution`.
- **Proof:** the existing file already escapes its own bash variable: `$$SURVEY_ASSIST_API_URL` on line 43 of the promote file.
- **Fix:** use `$$` for your own variables (`$$image_digest`, `$${source_digest#*@}` and so on). Leave Cloud Build's (`$_GAR_IMAGE`, `$SHORT_SHA`, `$LOCATION`) as they are.

**2. `docker push --quiet` doesn't return the digest**
- **Problem:** it prints the image reference (e.g. `…/survey-assist-api:abc1234`), not `sha256:…`. The regex check would then fail on every run.
- **Fix:** ask Artifact Registry for the digest after pushing:

```bash
        docker push $_GAR_IMAGE:latest
        docker push $_GAR_IMAGE:$SHORT_SHA
        image_digest=$(gcloud artifacts docker images describe "$_GAR_IMAGE:$SHORT_SHA" --format='value(image_summary.digest)')

        if [[ ! "$$image_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
          echo "ERROR: could not resolve image digest: $$image_digest" >&2
          exit 1
        fi

        gcloud run deploy survey-assist-api --image="$_GAR_IMAGE@$$image_digest" --region $LOCATION --project $_TARGET_PROJECT_ID
```

  In the promote file, do the same for both digests: use `gcloud artifacts docker images describe` on `"$$source_image:$SHORT_SHA"` and on `"$$release_image:$TAG_NAME"`. That also replaces the `docker image inspect` line.

## Worth checking

**3. The digest check may fail on a real promotion.**
- **Why:** `docker pull`, `tag` and `push` into a different repo doesn't always keep the same digest. Docker can recompress layers, or push only one platform's manifest when the original was a multi-platform index.
- **Your check would catch this, which is good, but the promotion would then fail.**
- **What to do:** run the promotion once to see. If the digests don't match, use `crane copy` or `gcrane cp` from source digest to release tag, which copies byte for byte. The ticket's risk table (section 8) already suggests this.

**4. Scope against the ticket.**
- **What this PR does:** it's the "deploy by digest / promote without rebuild" piece.
- **What it doesn't do:** dev and sandbox still run this YAML separately, so the image is still built once per environment. It also doesn't touch the CI/CD registry, the Terraform change, or the NatCen trigger.
- **That's fine for a small PR,** but say so in the PR description so reviewers don't expect the full ticket.

**5. Docs wording.** [gcp_deployment.md](../survey-assist-api/docs/gcp_deployment.md) says "Docker pushes the same local manifest". Update it once you know whether you're keeping docker push or switching to crane.

## Before asking for review

1. Fix points 1 and 2.
2. Run the dev pipeline once from your branch against sandbox. Check the deploy log shows `@sha256:…` and the smoke tests pass.
3. Run the promote pipeline once with a test tag. Check that the two digests match, or switch to crane if they don't.
4. Update the PR description: what it does, what it doesn't (point 4), and a link to a successful build log.

I can make the fixes for points 1 and 2 on the branch if you want; I haven't changed anything yet. I also can't see the PR itself (`gh` isn't installed), so this review is based on the branch diff against `main`.
