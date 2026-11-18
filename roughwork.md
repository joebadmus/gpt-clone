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
