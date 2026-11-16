Written for: Matt, as your updated plan for the week.

> **This week**
> - **NatCen into the Terraform pipeline (SA-1119):** NatCen infra changes go through PR, plan, review and apply, like dev and preprod. The two PRs are raised. Next is a test run.
> - **NatCen app deploys:** add NatCen triggers so the API, vector stores and SAYT UI deploy to NatCen automatically on merge to main. Most of this is one change in the CI/CD repo, because the existing pipelines already support choosing the target project.
> - **NatCen infra tests:** add NatCen to the infra test setup.
> - **Aim:** first automatic NatCen deploy by the end of the week.
>
> **Also**
> - Get my 6 open PRs reviewed and merged. Dan is already working through them, and all checks pass.
>
> **If time allows**
> - **SA-1127:** give each environment its own Themes key. I have the access to create the secrets.
>
> **Help needed**
> - Reviews on the open PRs.

What changed from your draft:
- "Dan's approval on the NatCen deploy approach" is gone, because he decided this morning: on merge to main.
- "Someone with Secret Manager Admin" is gone, because Dan says you have it.
- "Set up NatCen permissions" is gone, because Dan says the service account already has them. The test run will confirm it.
- The PR count went from 4 to 6, adding the two SA-1119 PRs.
- The deploy pipelines line is reworded: it's mostly one change in the CI/CD repo, not separate pipelines per repo.
