# Survey Assist API – Deployment Flow (Code to Cloud Run)

**Date:** 2026-10-29
**Status:** DRAFT. Built from the `survey-assist-api` repo (`main` + branch `sa-1117-build-promote-single-image`), not from the GCP console. Items marked *inferred* need confirming with Dan / Ethan.
**Sources:** `.github/workflows/ci.yml`, `cicd/cloudbuild_dev_and_sandbox.yaml`, `cicd/cloudbuild_promote_preprod.yaml`, `Dockerfile`, `docs/gcp_deployment.md`, plus meeting notes (`271026-infra-sync-summary.md`, `28-Oct26-DanCatchUp.md`).
**Related diagrams:** infra/Terraform pipeline → [current-setup.md §3](current-setup.md) · target build-once design → [J8 ticket §3](tickets/J8-build-once-promote-many.md) · runtime call flow → [app-demo-summary.md §5](app-demo-summary.md)

> **How to read the diagrams**
> - Solid = **seen in code/docs**. Dashed = **inferred**, confirm.
> - Two separate pipelines touch an environment: **app pipeline** (Cloud Build: build image, `gcloud run deploy`) and **infra pipeline** (Terraform: creates Cloud Run service, gateway, IAM…). This doc is mainly the app pipeline.
> - **GitHub Actions does not deploy.** It only lints and tests. Deployment is **Cloud Build**, triggered from GitHub.

---

## 1. Big picture

```mermaid
flowchart LR
    classDef inferred stroke-dasharray: 5 5
    classDef manual fill:#ffd6d6,stroke:#c0392b,color:#000
    classDef ext fill:#fef9e7,stroke:#b7950b,color:#000

    DEV["Developer"] -->|"push branch / open PR"| GH["GitHub<br/>survey-assist-api"]

    GH -->|"PR + push to main"| GHA["GitHub Actions ci.yml<br/>lint + unit tests only<br/>(no GCP access)"]
    GH -->|"merge to main<br/>Cloud Build trigger"| CB1

    subgraph CICD["CI/CD project (where Cloud Build runs) – inferred"]
        CB1["Cloud Build: cloudbuild_dev_and_sandbox.yaml<br/>image: testrunner"]
        CB2["Cloud Build: cloudbuild_promote_preprod.yaml<br/>manual run with TAG_NAME"]:::manual
        REL[("GAR: releases repo<br/>tag = TAG_NAME")]
    end

    GCS[("GCS bucket<br/>SIC/SOC lookup + rephrase CSVs")]
    GCS -->|"gsutil cp, baked into image"| CB1

    subgraph DEVP["Dev / Sandbox project"]
        GAR[("GAR: $_GAR_IMAGE<br/>tags = SHORT_SHA + latest")]
        CRD["Cloud Run<br/>survey-assist-api"]
    end

    CB1 -->|"docker build + push"| GAR
    CB1 -->|"gcloud run deploy<br/>(@digest on SA-1117 branch)"| CRD
    CB1 -->|"smoke tests: pytest cicd<br/>ID token as $_API_SA"| CRD

    GAR -->|"docker pull by SHORT_SHA"| CB2
    CB2 -->|"retag + push (no rebuild)"| REL

    subgraph PPP["Pre-prod project"]
        CRP["Cloud Run<br/>survey-assist-api"]
    end
    REL -->|"gcloud run deploy"| CRP
    CB2 -->|"smoke tests"| CRP

    PRD["Prod"]:::inferred
    NAT["NatCen project<br/>own branch build + own registry (interim)"]:::inferred
    REL -.->|"not in this repo – how?"| PRD
```

**In words:**
1. **Developer pushes** to GitHub. **GitHub Actions** runs lint + tests on the PR. It never touches GCP.
2. **Merge to `main`** fires a **Cloud Build trigger**. One build step (in the `testrunner` image) does everything: tests (80% coverage gate) → copy lookup CSVs from GCS → `docker build` → push to Artifact Registry → `gcloud run deploy` → smoke tests.
3. The same YAML serves **dev and sandbox** (the target comes from `$_TARGET_PROJECT_ID`), so **the image is built once per environment** today. That's the J8 / SA-1117 problem.
4. **Pre-prod** is a **manual** Cloud Build run with a `TAG_NAME`: it pulls the **dev** image by SHA, retags it, pushes to the **releases** repo, deploys to pre-prod and runs smoke tests. No rebuild.
5. **Prod** and **NatCen** paths aren't in this repo.

---

## 2. Dev / sandbox deploy, step by step

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant CB as Cloud Build (testrunner)
    participant GCS as GCS (lookup CSVs)
    participant GAR as Artifact Registry
    participant CR as Cloud Run (target env)
    participant IAM as IAM (impersonation)

    Dev->>GH: Open PR
    GH->>GHA: ci.yml – make check-python-nofix, make all-tests
    GHA-->>GH: ✅ / ❌ status check
    Dev->>GH: Merge to main
    GH->>CB: Trigger build (substitutions: _TARGET_PROJECT_ID, _GAR_IMAGE, _API_SA...)
    CB->>CB: poetry install + pytest (fail if coverage < 80%)
    CB->>GCS: gsutil cp SIC/SOC lookup + rephrase CSVs → data/
    CB->>CB: docker build -t IMAGE:SHORT_SHA -t IMAGE:latest
    CB->>GAR: docker push :latest and :SHORT_SHA
    CB->>CR: gcloud run deploy survey-assist-api --image=IMAGE:SHORT_SHA<br/>(SA-1117 branch: IMAGE@sha256:digest)
    CR-->>CB: New revision serving
    CB->>IAM: gcloud auth print-identity-token --impersonate-service-account=$_API_SA
    IAM-->>CB: ID token
    CB->>CR: pytest cicd – smoke tests direct to Cloud Run URL<br/>(not via API Gateway)
    CB-->>GH: Build ✅ / ❌
```

---

## 3. Pre-prod promotion, step by step

```mermaid
sequenceDiagram
    autonumber
    actor Rel as Releaser
    participant CB as Cloud Build (manual run)
    participant DGAR as GAR – dev repo
    participant RGAR as GAR – releases repo (CI/CD project)
    participant CR as Cloud Run (pre-prod)

    Rel->>CB: Run promote trigger with TAG_NAME (+ SHORT_SHA)
    CB->>DGAR: docker pull IMAGE:SHORT_SHA
    CB->>CB: docker tag → releases/IMAGE:TAG_NAME
    CB->>RGAR: docker push :TAG_NAME
    Note over CB,RGAR: SA-1117 branch adds: check source digest == release digest
    CB->>CR: gcloud run deploy (release image)
    CB->>CR: smoke tests (ID token as $_API_SA)
```

---

## 4. What the deployed API touches at runtime

Not created by the app pipeline. These come from **Terraform** or **manual steps**, but the deploy only works if they exist.

```mermaid
flowchart LR
    classDef manual fill:#ffd6d6,stroke:#c0392b,color:#000
    classDef ext fill:#fef9e7,stroke:#b7950b,color:#000

    CLIENT["NatCen / UIs / Postman"] -->|"signed JWT"| GW["API Gateway<br/>config versioned by hand"]:::manual
    GW --> API["Cloud Run: survey-assist-api<br/>runtime SA"]
    API -->|"ID token<br/>roles/run.invoker"| VS["Cloud Run: vector stores<br/>SIC · SOC · SAYT"]
    API -->|"gemini model<br/>Vertex AI"| LLM["Gemini"]:::ext
    API -->|"FIRESTORE_DB_ID"| FS[("Firestore<br/>results + feedback")]
    UI["Survey Assist UI"] -->|"OTP check"| OTP["OTP verify service<br/>Cloud Run + Firestore"]
```

---

## 5. Services and identities touched

| Step | Service | Identity | Seen in |
|---|---|---|---|
| Lint/test on PR | GitHub Actions | GitHub runner (no GCP creds) | `ci.yml` |
| Trigger | Cloud Build trigger | – | Trigger defined in CI/CD repo (Terraform) – *inferred* |
| Build/test/deploy | Cloud Build, `gcr.io/$PROJECT_ID/testrunner` image | Cloud Build SA (default SA per infra notes) | both cloudbuild YAMLs |
| Lookup data | GCS (`$_SIC_LOOKUP_CSV` etc.) | Cloud Build SA | dev YAML |
| Image store | Artifact Registry (env repo; releases repo in build project) | Cloud Build SA | both YAMLs |
| Deploy | Cloud Run Admin API (`gcloud run deploy`) | Cloud Build SA (needs `run.developer` + `iam.serviceAccountUser` on runtime SA) | both YAMLs |
| Smoke test | IAM Credentials (ID token) → Cloud Run | Cloud Build SA impersonating `$_API_SA` | both YAMLs |
| Runtime | Vector stores, Vertex AI, Firestore | API runtime SA (`run.invoker` on vector stores, `iam.serviceAccountTokenCreator`) | `docs/gcp_deployment.md` |
| Public entry | API Gateway (JWT, `x-google-issuer` = API access SA) | Client signs JWT as API access SA | `docs/gcp_deployment.md` |

## 6. Manual steps / gaps (known so far)

- **Pre-prod promotion** is a manual Cloud Build run.
- **API Gateway config** is versioned by hand (`gcloud api-gateway api-configs create` + `gateways update`).
- **NatCen** builds from its own branch into its own registry (interim, Gemini model change).
- **Prod** deploy path not in this repo. *Confirm.*
- **Image built per environment** (dev and sandbox each run the full YAML), being fixed by J8 / SA-1117.
- **Smoke tests bypass the API Gateway** (direct Cloud Run URL), so gateway config/JWT issues aren't caught by the pipeline (Postman collection covers this).

## 7. Questions to confirm

1. Which project does Cloud Build run in for each trigger, and where does `_GAR_IMAGE` point for dev vs sandbox?
2. How does prod get deployed?
3. Is the Cloud Build SA still the default SA, or a dedicated deployer SA?
4. Does Terraform also set the Cloud Run image (risk of rolling back a deploy), or does it `ignore_changes = [image]`?
