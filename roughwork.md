**Yesterday**
- Raised the SA-1127 PR. Terraform now creates a separate Themes Flask key for each environment. The plans for sandbox, dev and preprod are clean, and it's waiting for Dan's review.
- Found that the old Themes key was a single secret shared across all environments, so this fix was needed.
- Looked into SA-1126, the API Gateway two-stage setup. The cause is the gateway hostname, not the backend URL. I've written up the options on the ticket and sent them to Dan.
- Raised the Terraform 1.17.2 upgrade as a draft PR. It's blocked because the 1.17.2 binary isn't in the CI binaries bucket yet. I've asked Dan who looks after it.
- Merged the NatCen moved blocks PR.
- Dropped "add NatCen to infra tests" from my list, because Dan already did it under SA-1162.

**Today**
- Get the SA-1127 and NatCen pipeline PRs reviewed.
- Check the pipeline service account has the access it needs on NatCen.
- Rerun the 1.17.2 checks once the binary is added.
- Raise the tech debt tickets from Monday's meetings.

**Blockers**
- The Terraform 1.17.2 binary needs adding to the CI bucket.
- NatCen applies are on hold until their testing finishes next week.




Thank Ethan, email Platform Engineering, and check what's already in the bucket so you have a fallback. The upgrade isn't urgent, so there's no need to drop to an older version unless it drags on.

**Reply to Ethan:**

> Thanks Ethan, that's really helpful. I'll email Platform Engineering and ask when 1.17.2 is likely to be mirrored. It's not a blocker yet, so I'll hold the PR for now. If it takes a while, I'll move to the latest version that's already in the bucket.

**Email to platform.engineering@ons.gov.uk:**

> Subject: Terraform 1.17.2 in ons-ci-binaries
>
> Hi team,
>
> I'm on Survey Assist and we're upgrading our pipelines to Terraform 1.17.2. Our Cloud Build plan checks pull the binary from the `ons-ci-binaries` bucket, but 1.17.2 isn't there yet, so the builds fail.
>
> Could you let me know if 1.17.2 is on your list to scan and mirror, and roughly when? If there's a request form or process I should use instead, please point me to it.
>
> Thanks,
> Joe

**To find your fallback**, run this on the Jamf machine:

```sh
gcloud storage ls gs://ons-ci-binaries/ | grep -i terraform
```

Send me the list and I'll tell you which version to use if we do fall back.
