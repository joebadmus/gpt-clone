# Tech Meeting Summary – Platform / Infrastructure Sync

**Date:** 2026-10-22
**Source:** `tech-meeting.txt` (auto-transcript – speakers not labelled; some names/terms are transcription guesses)
**People referenced:** Joe, Dan (new joiners), Jeff, Ethan, Rupert (transcribed once as "Lupez"), plus the lead engineer proposing the changes and the delivery lead pushing back on timing.
**Client/environment referenced:** "NatSen" (new environment being stood up for a downstream consumer – likely NatCen; spelling uncertain)

---

## 1. What the meeting was about (TL;DR)

An engineering sync on a **GCP + Terraform platform** (Cloud Run, Cloud Armor, NAT gateway, Cloud Build, Cloud DNS, Artifact Registry, GCS state buckets) with environments **sandbox, dev, pre-prod (and prod)**.

Three threads ran through it:

1. **Status of the work-in-progress branch** that is standing up a new **NatSen environment**, and how to avoid it diverging from `main`.
2. **Architectural critique and proposals** – network design (VPC-per-service), project layout (too many single-purpose projects), and CI/CD security (Cloud Build default service account vs. GitHub Actions).
3. **Prioritisation** – the delivery lead agreed with the proposals in principle but ruled that **no large re-architecture happens before January**. Focus now is: finish NatSen, ship small safe PRs, unblock the existing team for January testing, and document manual steps.

---

## 2. Current setup and current issues

### 2.1 Environments and the "janky proxy" / static IP secret
- Sandbox deployment creates a **single CI/CD secret** (stored against the production environment) holding the **NAT gateway's public IP**.
- When dev and pre-prod deploy, they read that IP and **add it to the Cloud Armor allow-list**, so a **proxy endpoint running in sandbox** can reach dev and run tests.
- **Problem:** the secret name is static. Deploying a **second sandbox-type environment** (e.g. NatSen) collides with the existing secret.

### 2.2 Terraform naming limits
- GCS bucket names have a **63-character maximum**; the interpolated names for the new environment exceed it.
- **Fix already in place:** a new `name_override` style variable. If it is not set, the original interpolation is kept, so `terraform plan` against dev/pre-prod shows **no changes**. The new environment overrides it (e.g. shortening `external` to `x`).
- The same principle is being applied to all changes: **defaults unchanged, overrides only for the new environment**, so nothing existing is destroyed or recreated.

### 2.3 Unmanaged resources
- Some resources (notably **VPCs in sandbox**) **exist but are not in Terraform state**.
- Agreed approach: bring them under management with **`terraform import`**.

### 2.4 Network design – VPC per service
- Each service (e.g. a Cloud Run service, a separate API) has **its own VPC**.
- Concern raised: this **does not add meaningful security** and can **add attack surface**, because services that need to talk to each other must go via the internet or tunnels, and each needs its own ingress openings, instead of communicating privately on a shared VPC.
- Assessment in the meeting: "clunky", but accepted as-is for now.

### 2.5 Project sprawl and state bootstrapping
- There are separate projects for **CI/CD, DNS**, and per-environment **Artifact Registries**.
- Problems:
  - **Artifact Registry per project** forces images to be **rebuilt per environment**, which breaks **"build once, deploy many"** (what is tested is not exactly what is deployed).
  - **State bucket chicken-and-egg:** for each new project, someone must **manually create the state bucket**, then Terraform tries to create it, then it has to be **imported**.
  - DNS and other long-lived resources are mixed with short-lived application resources, despite having **different lifecycles**.

### 2.6 CI/CD security chain
- Security requirement (as interpreted): **do not use a GitHub service account** that can access environments directly.
- Current workaround: GitHub triggers a **Cloud Build / Cloud Run job** that runs as the **default Cloud Build service account**, which has **broad, cross-project permissions** (DNS, secrets, networks – everything Terraform needs).
- Point raised: this is a **vulnerability chain** – GitHub can't create resources directly, but it can ask something that can ("sudo, get me a cup of coffee"). The risk is **moved down a level, not reduced**. The Cloud Build YAML is essentially bash run as that powerful account.

### 2.7 Code quality
- Noted **duplication / copy-paste** across the Terraform codebase that should be cleaned up.

---

## 3. Proposed changes

| # | Proposal | Timing agreed |
|---|----------|---------------|
| P1 | **Single management ("hub") project** owning Terraform state buckets, shared Artifact Registry, Cloud DNS, CI/CD, static third-party secrets (referenced from env projects as Terraform data sources), the test proxy, and any future developer VPN. | Deferred – January / early next year |
| P2 | **Consolidate networking** – services share a VPC and talk internally instead of one VPC per service. | Deferred (raised as future idea) |
| P3 | **Move to GitHub Actions with a service-account impersonation chain** – a GitHub identity that can *only* impersonate a **per-project deployer service account**, which holds the actual permissions. One deployer per environment with scoped roles, instead of one broad cross-project account. | Deferred – January / early next year |
| P4 | **Override variables with backward-compatible defaults** (bucket names, IP secret naming, etc.) so changes are no-ops for existing environments. | Now – in progress |
| P5 | **`terraform import`** unmanaged VPCs and other existing resources. | Now |
| P6 | **Remove Terraform duplication.** | Opportunistically, in small PRs |

---

## 4. Viability assessment of the proposals

### P1 – Central management project: **Viable, and standard practice**
- Matches Google's own landing-zone patterns (e.g. `terraform-example-foundation` uses a dedicated *seed* project for state and a *cicd* project; Cloud Foundation Fabric is similar).
- **Shared Artifact Registry** with cross-project `roles/artifactregistry.reader` for each environment's runtime service account directly restores build-once-deploy-many. Promote by **image digest**, not by rebuild.
- Solves the **state bucket chicken-and-egg**: buckets are created once in the management project by a small bootstrap stack.
- **DNS:** keep the parent zone in management and **delegate a sub-zone per environment**, so envs can still manage their own records without touching shared DNS.
- **Caveats:** this project becomes the highest-value target. It needs tight IAM, few human admins, audit logging, and ideally VPC Service Controls. Keep its Terraform separate from application Terraform.

### P2 – Consolidated networking: **Viable; implement as Shared VPC, not one flat network**
- The critique is valid: per-service VPCs that talk over public endpoints are weaker than private connectivity.
- Recommended shape: a **Shared VPC host project per environment** (or per env tier), with **subnets per workload**, **firewall rules / network tags or secure tags** for segmentation, Cloud Run using **Direct VPC egress** and **internal ingress**, and **Private Service Connect / Private Google Access** for Google APIs.
- This keeps segmentation, which is the legitimate reason for separate VPCs, without forcing traffic out to the internet.
- **Caveat:** migrating live networks is the riskiest item on the list. It touches every service and needs careful sequencing. Deferring it until after January testing is sensible.

### P3 – GitHub Actions with an impersonation chain: **Viable, and an improvement over today if done properly**
- Use **Workload Identity Federation** (no long-lived keys). Lock the provider with an **attribute condition** on `repository`, `ref` and/or GitHub `environment`, so only specific repos/branches/environments can obtain tokens.
- The federated identity gets only `roles/iam.serviceAccountTokenCreator` on the **per-environment deployer service account**. The deployer holds the least-privilege roles for its own project only.
- Prod deploys can be gated by **GitHub Environments with required reviewers**.
- This is strictly better than the current shared default Cloud Build account: smaller blast radius, per-environment separation, auditable impersonation.
- **Caveats:**
  - It still needs **sign-off from whoever owns the security requirement**. Literally, it is "a GitHub service account", so get confirmation that WIF + impersonation satisfies the intent.
  - **The quick win can happen now, independent of the GitHub move:** replace the **default Cloud Build service account** with **dedicated, per-environment deployer service accounts** in Cloud Build. That removes most of the risk without changing the CI tool.

### P4 – Override variables with safe defaults: **Viable, low risk**
- Correct approach. Verify each PR by attaching a `terraform plan` showing **"No changes"** for dev/pre-prod.
- For the NAT IP secret, consider **parameterising the secret name per environment**, or reading the IP via a Terraform **remote state / data source** instead of a CI secret.

### P5 – `terraform import`: **Viable**
- Use Terraform 1.5+ **`import` blocks** so imports are code-reviewed and repeatable, not ad-hoc CLI commands. Confirm the plan is clean (no replace) after import.

### Additional risk flagged during review (not discussed in the meeting)
- For functional testing, the meeting proposed a **service account with a key** to call the Cloud Armor-protected API. **Service account keys are a security risk** and may be blocked by org policy (`iam.disableServiceAccountKeyCreation`). Prefer **impersonation to mint short-lived ID/access tokens** (`gcloud auth print-identity-token --impersonate-service-account=...`) where possible. If a key is unavoidable, scope it tightly, store it in Secret Manager, and rotate it.

**Overall verdict:** the proposed direction (management project, shared networking, impersonation-based CI/CD) is technically sound and aligned with GCP best practice. The delivery lead's call to **defer it until after January** is also reasonable. The two things worth pulling forward because they are low-effort and high-value are **dedicated deployer SAs instead of the default Cloud Build SA**, and **writing the target design down now** (e.g. an ADR) so January starts with an agreed plan.

---

## 5. Decisions made

1. **No large re-architecture before January** (management project, GitHub Actions, network redesign all deferred to early next year).
2. **Keep the NatSen branch** as a separate line of work for **at most 1–2 weeks** to avoid a "mega merge" of ~500 changes.
3. **Deprioritise the big review/merge** of the NatSen branch; instead **raise small, independent PRs against `main`** that are no-ops for existing environments.
4. **Rupert can review and approve** those small PRs (not only Ethan), provided he confirms the existing sandbox isn't broken.
5. Once NatSen works, **pivot to the Ethan/Rupert backlog**, i.e. things they need for **January testing** (they have been fighting Kubernetes issues), rather than generating more tech-debt PRs for them to review.

---

## 6. Action items

| Owner | Action |
|-------|--------|
| Lead engineer (infra) | Finish the **remaining ~14 resources** for the NatSen environment and get the VPC in. |
| Lead engineer (infra) | `terraform import` the unmanaged sandbox VPCs. |
| Lead engineer (infra) | Rebase later onto **Ethan's new module toggle**. Ethan's team to carry on without waiting. |
| Lead engineer (infra) | Raise **small PRs against `main`** for backward-compatible changes. Flag them as minor. |
| Team / delivery lead | Brief **Rupert** on reviewing the small PRs. |
| Team | Ask Ethan/Rupert **what is blocking them for January** and pick up backlog items. |
| Lead engineer (infra) | Document **all manual environment setup steps** (e.g. secrets that can't be set in Terraform) on **Confluence**, doubling as a **disaster-recovery rebuild checklist**. |
| Team (group session) | Set up **functional testing**: service account access to the Cloud Armor-protected API. Walk through auth together and `curl` the ~2 endpoints NatSen actually needs (e.g. *classify*). |
| Delivery lead | Share the **WIP "external access" document** in chat (a simpler version to follow). |
| **Jeff** | **1:30 today:** demo for Joe and Dan covering the UIs, how components hook together, and specifically the **non-search-as-you-type web demo** (dynamic follow-up question flow) that NatSen will use. Run it from sandbox or locally against the sandbox API. |
| Joe | Laptop clock showing US timezone: request **admin access via JIT** to fix it. |
| Later (January) | Design work for P1–P3. Recommend capturing as an ADR beforehand. |

---

## 7. Key takeaways

- The infra work for NatSen is **deliberately non-breaking** (override variables, unchanged defaults), which makes small PRs to `main` low-risk.
- The **biggest real security gap** is the **broad default Cloud Build service account**. GitHub → Cloud Build only relocates the risk.
- The **target architecture is sound** but **timing is the constraint**. The team's priority until January is to **add value without adding review burden** to the existing team.
- **Documentation of manual steps** is a cheap, high-value deliverable that supports both new environments and DR.
