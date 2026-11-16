# Survey Assist – Architecture and Pipelines (single reference)

**Last checked:** 16 Nov 2026, against `main` in `survey-assist-api`, `survey-assist-terraform`, `survey-assist-ui`, `survey-assist-sayt-ui` and `survey-assist-vector-store-api`.
**Replaces** the diagrams in `current-setup.md`, `deployment-flow.md`, `proposed-setup.md` and `app-demo-summary.md` (Oct 2026). Those are kept for history but are out of date.

> **Key**
> - Solid line or box = seen in code.
> - Dashed = not in any repo or not confirmed (ask Dan / Ethan).
> - Red = gap or work still to do.

---

## 1. GCP projects

```mermaid
flowchart TB
    classDef todo fill:#fde2e2,stroke:#c0392b,color:#000
    classDef unknown stroke-dasharray: 5 5

    subgraph CICD["ons-cicd-surveyassist (CI/CD project, number 113332539420)"]
        CB["Cloud Build<br/>runs all pipelines"]
        REL[("Artifact Registry<br/>*-releases repos")]
        SEC[("Secret Manager<br/>UI Flask keys, NAT IP secrets")]
        PM[("Parameter Manager<br/>infra-test-config per env")]
        TRG["Cloud Build triggers<br/>not in any repo"]:::unknown
    end

    subgraph SBX["survey-assist-sandbox"]
        S["Full stack + GKE trial<br/>+ UI test proxy + NAT"]
    end
    subgraph DEV["ons-survey-assist-dev"]
        D["Full stack"]
    end
    subgraph PPR["ons-survey-assist-preprod"]
        P["Full stack + GKE"]
    end
    subgraph NAT["survey-assist-sandbox-external (NatCen)"]
        N["Full stack, GKE off<br/>+ own UI test proxy + NAT"]
    end
    PRD["Prod project"]:::unknown

    CB --> SBX
    CB --> DEV
    CB --> PPR
    CB --> NAT
    CB -.-> PRD
```

| Project | Terraform folder | Notes |
|---|---|---|
| `ons-cicd-surveyassist` | none (not in this repo) | Cloud Build, release images, shared secrets, test config |
| `survey-assist-sandbox` | `survey-assist-sandbox/` | Where new infra is tried first |
| `ons-survey-assist-dev` | `ons-survey-assist-dev/` | Gets every merge to main (app pipelines) |
| `ons-survey-assist-preprod` | `ons-survey-assist-preprod/` | Gets tagged releases |
| `survey-assist-sandbox-external` | `survey-assist-sandbox-external/` | NatCen. On main since 11 Nov |

---

## 2. Runtime architecture (one environment)

What runs inside each environment project and who calls what.

```mermaid
flowchart LR
    classDef ext fill:#fef9e7,stroke:#b7950b,color:#000

    USER["Respondent / tester"]
    CLIENT["External client e.g. NatCen<br/>signed JWT"]

    subgraph ENV["Environment project"]
        subgraph UIS["UIs (Cloud Run, module cloud-run-ui)"]
            SUI["survey-ui"]
            SAYTUI["sayt-ui<br/>search as you type"]
            THUI["themes-ui"]
            GUI["survey-genie-ui"]
        end
        OTP["firestore-otp<br/>OTP API + cleanup job"]
        REDIS[("Redis<br/>UI sessions")]
        GW["API Gateway<br/>JWT check"]
        API["survey-assist-api<br/>Cloud Run"]
        subgraph VS["Vector stores (Cloud Run)"]
            SIC["sic-vector-store"]
            SOC["soc-vector-store"]
            SAYT["sayt-vector-store"]
        end
        FS[("Firestore<br/>results, feedback")]
        EVAL["survey-assist-api-eval"]
        THJ["themes job + workflow"]
        LOG[("log analytics bucket<br/>SAYT")]
    end

    GEM["Gemini on Vertex AI<br/>model: GEMINI_MODEL_NAME<br/>region: VERTEX_AI_LOCATION"]:::ext

    USER --> SUI & SAYTUI & THUI & GUI
    SUI --> OTP
    SUI & SAYTUI --> REDIS
    SUI & SAYTUI -->|via gateway| GW
    CLIENT --> GW
    GW --> API
    API --> SIC & SOC & SAYT
    API --> FS
    API --> GEM
    THUI --> THJ
```

- The API reads `GEMINI_MODEL_NAME` (NatCen: `gemini-3.5-flash`, others: app default) and, once PR 82 merges, `VERTEX_AI_LOCATION` (default `europe-west2`).
- GKE (`vector-store-gke`) exists in sandbox and preprod as a trial. It's commented out in NatCen and not used in dev.
- UI Flask secret keys live in the **CI/CD project** and are shared across all environments (SA-1127).

---

## 3. App pipeline – Survey Assist API (build once, promote by digest)

This is the model the other apps should follow. Done in SA-1117.

```mermaid
flowchart LR
    classDef manual fill:#eaf2ff,stroke:#2e6fd9,color:#000
    classDef unknown stroke-dasharray: 5 5

    PR["PR"] --> GHA["GitHub Actions ci.yml<br/>lint + tests only, no GCP"]
    MERGE["Merge to main"] --> B["cloudbuild_dev_and_sandbox.yaml<br/>ONLY place the image is built<br/>test, build, push, deploy @digest, smoke test"]
    B --> DEVAR[("dev Artifact Registry<br/>tag SHORT_SHA")]
    B --> DEVCR["Dev (and sandbox) Cloud Run"]

    TAG["Release tag"]:::manual --> PP["cloudbuild_promote_preprod.yaml<br/>copy dev image to releases as TAG<br/>deploy to preprod, smoke test"]
    DEVAR --> PP
    PP --> RELAR[("releases repo<br/>CI/CD project")]
    PP --> PPCR["Preprod Cloud Run"]

    RELAR --> PROD["cloudbuild_promote_prod.yaml<br/>checks preprod runs same digest"]
    RELAR --> NATP["cloudbuild_promote_natcen.yaml<br/>checks preprod digest + GEMINI_MODEL_NAME set"]
    PROD -.-> PRODCR["Prod Cloud Run"]:::unknown
    NATP --> NATCR["NatCen Cloud Run"]
```

- One image, built once on merge. Preprod, prod and NatCen all get **the same digest**, never a rebuild.
- Prod and NatCen promotes refuse to deploy unless preprod is running that exact release.
- Whether the prod and NatCen **triggers** exist is not visible in code (dashed).

---

## 4. App pipelines – other repos (today)

```mermaid
flowchart LR
    classDef todo fill:#fde2e2,stroke:#c0392b,color:#000

    subgraph REPOS["survey-assist-ui · survey-assist-sayt-ui · survey-assist-vector-store-api (SIC, SOC, SAYT)"]
        M["Merge to main"] --> DS["cloudbuild_dev_and_sandbox*.yaml<br/>build + deploy to dev / sandbox"]
        T["Release tag"] --> PP["cloudbuild_promote_preprod*.yaml<br/>re-tag dev image to releases,<br/>deploy to preprod"]
    end
    DS --> DEV["Dev / sandbox"]
    PP --> PPR["Preprod"]
    NOPE["No NatCen pipeline"]:::todo
    NOPE2["No prod pipeline"]:::todo
```

- Vector store and SAYT UI pipelines take `$_ENV_NAME` and read settings from Parameter Manager `infra-test-config`. NatCen's Terraform already creates its settings.
- These still re-tag on promote, rather than the API's digest checks.

---

## 5. NatCen CI/CD – target (what we're building)

```mermaid
flowchart LR
    classDef todo fill:#fde2e2,stroke:#c0392b,color:#000
    classDef done fill:#e3f6e8,stroke:#2e8b57,color:#000
    classDef unknown stroke-dasharray: 5 5

    RELAR[("releases repos<br/>CI/CD project")]
    PPR["Preprod running release X"]

    API["API promote_natcen"]:::done
    SICN["SIC / SOC / SAYT vector store<br/>promote_natcen"]:::todo
    SAYTN["SAYT UI promote_natcen"]:::todo
    UIN["survey-ui promote_natcen?<br/>ask Dan if NatCen uses it"]:::unknown
    TRIG["Triggers in CI/CD project"]:::todo
    IAM["NatCen Cloud Run agent:<br/>read releases repos"]:::todo
    TESTS["Infra tests: sandbox-external"]:::todo

    TRIG --> API & SICN & SAYTN & UIN
    RELAR --> API & SICN & SAYTN & UIN
    PPR -. same digest check .-> API & SICN & SAYTN
    API & SICN & SAYTN & UIN --> NATCR["NatCen Cloud Run services"]
    IAM --> NATCR
    NATCR --> TESTS
```

Still to decide with Dan: promote from preprod (proposed) or deploy on merge, survey-ui in or out, proxy in the pipeline or not, where triggers are managed.

---

## 6. Infra pipeline – Terraform

```mermaid
flowchart LR
    classDef unknown stroke-dasharray: 5 5

    PR["PR to survey-assist-terraform"] --> WF["GitHub Actions workflow.yml<br/>fmt, tflint, lint"]
    ENG["Engineer"] --> PLAN["terraform plan<br/>run locally per env folder"]
    PLAN --> APPLY["scripts/cloudbuild-apply.yml<br/>Cloud Build applies tfplan<br/>as ons-cicd-surveyassist SA"]:::unknown
    APPLY --> ENVS["sandbox · dev · preprod · NatCen"]
```

- Each environment folder has its own state. Cloud Run images are ignored by Terraform (`ignore_changes`), so the app pipelines own what's deployed.
- Drift appears when someone applies from a feature branch or changes things by hand (for example `AUTH_METHOD`, `GEMINI_MODEL_NAME`).
- How plans reach the apply step is not clear from the repo (dashed).

---

## 7. UI test proxy and NAT IP

How tests reach dev, preprod and NatCen UIs through Cloud Armor.

```mermaid
sequenceDiagram
    autonumber
    participant CB as Cloud Build test step
    participant PX as proxy-api (nginx, Cloud Run in sandbox)
    participant NAT as Sandbox NAT IP (module ui-testing)
    participant CA as Cloud Armor (target env)
    participant UI as Target UI

    CB->>PX: /{service}/{environment}/... e.g. /sayt-ui/dev/
    PX->>NAT: outbound via NAT
    NAT->>CA: request from allow-listed IP
    CA->>UI: {service}.{environment}.survey-assist.gcp.onsdigital.uk
```

- Each sandbox-style project (sandbox, NatCen) has its own NAT IP and its own secret name (SA-1122, merged).
- NatCen's Cloud Armor only allows **NatCen's own** NAT IP. Use the NatCen proxy to test NatCen (SA-1156).
- `proxy-api/cloudbuild.yaml` only deploys to sandbox. SA-1123 plans to move the proxy into the CI/CD project.

---

## 8. What changed since the October docs

| Then (Oct docs) | Now |
|---|---|
| NatCen on its own branch | On main, folder `survey-assist-sandbox-external` |
| One fixed NAT IP secret, NatCen clashes | Per-environment secret names |
| API image rebuilt per environment | Built once, promoted by digest to preprod, prod and NatCen |
| No prod or NatCen pipeline | API has both. Other apps don't yet |
| Gemini model set by hand on Cloud Run | Terraform input in review (189), NatCen value in draft (192) |
| Gemini region fixed | Configurable, in review (82, 190) |
