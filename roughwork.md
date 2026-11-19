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


======
SA-1119 is mostly done. Two terraform PRs merged on 16–17 Nov: pinning NatCen to Terraform 1.11.0, and the moved blocks for the renamed network. Two PRs are still open in survey-assist-cicd.

- **Terraform pipeline for NatCen** (the main part of the ticket): ready for review, all checks green, mergeable. Nobody has reviewed it yet. We still need to confirm the CI/CD service account has the access it needs on the NatCen project.
- **NatCen app deploy triggers** (the draft one): you moved it back to draft on 16 Nov. The triggers build a separate NatCen image, which goes against build-once, and the NatCen bucket is missing the data files the builds need. It's waiting on Dan to say whether NatCen should use the promote pipeline instead.

Both should stay unmerged until NatCen testing finishes next week. To move it on now, ask Dan to review the pipeline PR and answer the promote question.

> Hi Dan, when you get a minute, could you review the NatCen Terraform pipeline PR? It's green and ready. Also, for the NatCen app deploys, should they use the promote pipeline, so the same image as preprod with no rebuild, rather than separate triggers? I'll hold both until NatCen testing is done.
