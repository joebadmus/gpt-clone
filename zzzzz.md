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