plan for the week.

> **Joe: focus for this week**
>
> **Main goal: get NatCen into the CI/CD pipeline**
> This is my main piece of work this week. The NatCen environment is now on main, so the work is ready to start. The aim is for NatCen to get releases automatically, by promoting the same image preprod is running.
> - Agree the deploy approach with Dan (promote from preprod), and check which Cloud Build triggers already exist.
> - Add NatCen deploy pipelines for the vector stores (SIC, SOC and SAYT) and the SAYT UI, copying the API one that's already in place.
> - Sort out the permissions NatCen needs to pull release images from the CI/CD project.
> - Add NatCen to the infra tests.
> - Stretch: first NatCen deploy through the pipeline by the end of the week.
>
> **Get the open PRs merged**
> I have four small PRs waiting for review. Two make the Gemini model and region configurable per environment, one is the API side of the region change, and one sets the NatCen model in Terraform. All have clean plans and passing checks. Merging them also protects NatCen, because an apply would currently remove its Gemini model setting.
>
> **If there's time: SA-1127, separate Themes key per environment**
> All environments share one Themes Flask key. The fix is small: a new secret per environment and a one-line change in each. It needs someone with Secret Manager admin in the CI/CD project to create the secrets.
>
> **Where I need help**
> - **Reviews.** My PRs have been waiting about a week. Could Ethan or Rupert pick some up, or could we use the self-review approach we agreed, with Dan or Ethan doing a final check?
> - **Decisions.** I need Dan's quick yes on the NatCen deploy approach, and someone to create the Themes secrets.

Today, I'd chase the reviews first. Then get Dan's answer on the deploy approach and run the trigger list command, so the CI/CD work can actually start.



=====
Hi all, I have a few small PRs waiting for review if anyone has a moment. They're all low risk, plans are clean and checks pass.

Configurable Vertex AI region (API): lets us choose the Gemini region per environment through an env var. Nothing changes if it isn't set. https://github.com/ONSdigital/survey-assist-api/pull/82
Gemini model setting (Terraform): lets each environment set its Gemini model in code instead of by hand. https://github.com/ONSdigital/survey-assist-terraform/pull/189
Vertex AI region setting (Terraform): the same idea for the region. It goes in after the model one. https://github.com/ONSdigital/survey-assist-terraform/pull/190
NatCen Gemini model (Terraform): sets NatCen's model in code, so an apply doesn't remove it and break its deploy pipeline. It's a draft until the model PR is in. https://github.com/ONSdigital/survey-assist-terraform/pull/192
Thanks!
