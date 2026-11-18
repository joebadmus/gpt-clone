# SAYT vector store on GKE: handover from Ethan (18 Nov)

**Who:** Ethan (presenting), Dan, Joe, Rupert (working on CI/CD in the background), Steve (briefly).
**Recording:** On SharePoint, which deletes it after 30 days. Ethan will try to move it to Confluence, alongside his live notes page and an overview diagram later this week.
**Next sessions:** More handovers tomorrow and Friday, IAM on Monday, and a Q&A catch-up next Wednesday or Thursday. Ethan is around for about another week and a half.

---

## Key takeaways

1. **The SAYT vector store now runs on GKE in sandbox and preprod** as an internal service. Only the API talks to it, through the VPC. SIC and SOC are still on Cloud Run.
2. **Everything is Terraform controlled, including the Helm values.** Values that change per environment (static IP, image, host, pod service account) are read from `infra-test-config` in Parameter Manager. If one is missing, the Helm deploy fails on purpose.
3. **Helm is not in CI/CD yet.** Deploys are done locally with three helper scripts. Rupert has `kubectl` working in Cloud Build through the cluster's DNS endpoint (SA-1242).
4. **Traffic inside the VPC is HTTP on port 80, not HTTPS.** Google-managed certs were trialled, but the API needs an update to handle PEM. The risk is accepted for now because of the firewall rules and because the data isn't sensitive.
5. **Everything has been tested.** Evidence for each resource is on Ethan's Confluence page. An Apache Bench load test against the internal load balancer handled about 22 requests per second, and the HPA scaled from 1 to 2 pods. That's the service on its own, so expect extra overhead from the API.
6. **Most of the tuning waits for load testing**: machine type, resources, HPA timings and the startup probe.

---

## How it's built

**Networking (all Terraform)**
- The API joins `vector-store-vpc` through direct VPC egress on its own subnet, for private IPs only. The `vpc_access_enabled` flag on the API module turns this on.
- There are three subnets: API, GKE (with secondary ranges for pods and services) and a proxy-only subnet for the internal load balancer. The ranges are sized well beyond what the public test needs, and all subnets have VPC flow logs on.
- The private DNS zone (`vector-store.internal`) is attached to the VPC only. The `sayt.` record points at the internal load balancer's static IP. To add SIC or SOC later, you'd just add another record.
- **Firewall:**
  - Deny all ingress.
  - A deny egress rule to the load balancer IP, plus an allow rule for the API subnet to reach it on port 80. These two work together. They're egress rules because the load balancer IP has no NIC.
  - Three GKE-managed rules for health checks and node-to-node traffic. These aren't in Terraform.
- **Cloud NAT** uses an ephemeral IP, limited to the GKE subnet. It exists because the pods download the embedding model from Hugging Face when they start.
- **Network Intelligence Center:** one happy-path test (API subnet to pod) and one basic unhappy-path test (external IP blocked). Both run as part of the infra test suite. The unhappy test shows as "fail" in the console even when it passes.

**Cluster**
- GKE Autopilot with private nodes, so the nodes have no public IPs.
- **Control plane access:**
  - For debugging only, through the control plane IP. This needs an allow-listed CIDR from the secret in the CI/CD project, plus IAM.
  - For CI/CD, through the DNS endpoint with IAM.
- **Service accounts:**
  - A dedicated node SA, with GKE node permissions and read access to the vector store registry.
  - A pod SA for SAYT with no roles at all, linked through Workload Identity to the Kubernetes SA in its namespace.
- **Maintenance window:** 2am daily for 4 hours, which is the minimum Google allows. There's no exclusion yet, which is what SA-1244 covers.
- **Helm charts:** stored in Artifact Registry (`survey-assist-helm`), which keeps the latest 5 tags. The current version is 0.1.2.

**Helm chart**
- Deploys into its own `vector-store` namespace, plus a separate namespace for Helm tests.
- The chart is built to hold several vector stores. Adding SIC or SOC means duplicating the SAYT block in `values.yaml`.
- **base:**
  - Ingress for the internal load balancer.
  - Resource quotas and limit ranges, worked out from the replica and HPA settings, with headroom for rollouts.
  - **Gotcha:** the quota maths assumes milli-CPU and GB. It's documented in the README.
- **vector-store:**
  - **Deployment:**
    - Runs on C4 performance nodes, which were about 10–15 ms faster than E2. This can be switched back to save money.
    - Uses `imagePullPolicy: IfNotPresent` because the image is about 8 GB.
    - The probes hit `/`.
  - **Startup probe:** the failure threshold is 5, so a pod that takes longer than about 25 seconds to start fails it. If that happens in load testing, raise it to 7.
  - **Service:** port 80.
  - **HPA:**
    - Scales on CPU, with a 50% target.
    - Scale-up waits 15 seconds and scale-down 60 seconds, which is test-friendly. Ethan suggests about 30 seconds up and 10–15 minutes down for real use.
  - **Pod disruption budget:** at most 1 pod unavailable.
  - **Network policy:** only GCP health checks, the load balancer's proxy subnet and the Helm test pods can reach the SAYT pods.
- **tests:** a happy-path pod calls SAYT through the internal DNS and expects a 200, and a deny pod checks that the network policy blocks it. The test pods are kept afterwards for debugging. A flag turns this off.
- **Docs:** `helm-docs` generates them from comments in `values.yaml`, and a pre-commit hook checks them, so you need `helm-docs` installed locally.

**Using it**
- Get credentials for the cluster, then use the three scripts in the Helm folder. Each takes the CI/CD project and `infra-test-config`.
  - **check-diff:** like a `terraform plan`. It uses `kubectl diff` against what's actually on the cluster, not Helm's diff.
  - **deploy:** builds and pushes the chart (or reuses an existing version), shows the diff and asks for "yes", then runs the upgrade.
  - **test:** runs the Helm tests and collects the logs.
- **Network policy deny logging** was turned on by hand with `kubectl edit` on a GKE-managed resource. It's not in Helm, because breaking that resource could mean rebuilding the cluster. Deny logs already go to the log analytics bucket. Allow logging is off.
- **CI/CD service account in sandbox:** it has only a few roles, because sandbox was never meant to be in the pipeline. The rollout works once it has `container.developer` on sandbox. That needs adding to Terraform.

---

## Ethan's tickets (SA-1240 to SA-1256), in priority order

### Pick up now

| Ticket | What | Why now | Notes |
|---|---|---|---|
| **SA-1241** | Add ONS VPN IPs to the GKE control plane allow-list | Quick, and gives ONS Macs access to the cluster. Ethan suggested Dan or Joe. | No code change. Copy the three ONS VPN IPs from the Cloud Armor allow-list secret in the CI/CD project into the sandbox and preprod GKE master allow-list secrets, then apply Terraform in sandbox and preprod. Prove it with `gcloud container clusters get-credentials` and `kubectl get nodes`. |
| **SA-1244** | Maintenance exclusion for the public test | Must be in before the public test starts | Add an optional exclusion (type and date range) to the GKE module, defaulting to none. Set it for preprod. It's an in-place update. Google may cap an exclusion at about a month, so check the docs. |
| **SA-1245** | Kubernetes RBAC for the CI/CD SA, limited to rollouts in the `vector-store` namespace | Already in progress. Ethan says do it while he's still around to help. | Map the CI/CD SA to a Kubernetes SA and bind a minimal role in the namespace. Depends on the first CI/CD rollout (SA-1242), but can be tested early with something like "list pods", checked through the RBAC audit logs. Confirm with Dan who owns it. |
| **SA-1240** | Remove the `SAYT_SERVICE` env var from the API if it's unused | Small Terraform change | Confirm with Dominic and Steve first. Then remove it from the API module, apply everywhere, and test the `/suggestions` endpoint. |

### Already in progress or waiting

| Ticket | What | Status |
|---|---|---|
| SA-1242 | SAYT store CI/CD for sandbox and preprod, plus a smoke test through the API Gateway `/suggestion` endpoint | Rupert is on it. The SAYT pipeline also needs its own smoke test, because the current one runs the combined SIC and SOC tests. |
| SA-1243 | Tune the node type, resources, HPA and probes | Waits for load testing with Steve, Dominic, Jeff and Matt |

### Backlog (after the public test, or for Blaze)

| Ticket | What | Notes |
|---|---|---|
| SA-1246 | Resource-limit and user-principal access logs into alerting | Ethan sees the user-principal part as more important: alert when anyone other than known users or the CI/CD SA connects to the cluster. Email first, Slack later. Fits the logging work next sprint. |
| SA-1247 | Helm into CI/CD, with chart semantic versioning | Run the deploy script in Cloud Build, with a manual check before apply |
| SA-1248 | Stop sending the bearer token when the API calls GKE (or only send it for Cloud Run) | API code change, not infra |
| SA-1249 | HTTPS inside the VPC with Google-managed certs | Needs the API update for PEM, plus cert resources in Terraform |
| SA-1250 | Google Groups RBAC, coupled with IAM (and PAM in preprod) | Needs ONS Platform Engineering, because it uses an org-wide group. Could become urgent if a pen test comes up. |
| SA-1251 | Tighten the GKE firewall rules and NAT access to Hugging Face | Replace the GKE-managed rules with Terraform ones |
| SA-1252 | More Network Intelligence Center tests | Cover the other firewall rules |
| SA-1253 | VPC flow logs into alerting | For example, alert on unknown IPs |
| SA-1254 | Download the Hugging Face model at build time, not when the pod starts | Would remove the need for NAT. Trade-off is build time. |
| SA-1255 | Move SIC and SOC onto the cluster | Placeholder. Easy with the current chart. |
| SA-1256 | Move the API into Kubernetes | Placeholder. Raises questions about Blaise connectivity (IAP, or Kong to keep JWTs) and whether traffic is public or on-prem. |

---

## Actions

- [ ] **Joe:** pick up SA-1241, then SA-1244. Check with Dan which of you takes SA-1245.
- [ ] **Joe / Dan:** ask Dominic and Steve whether `SAYT_SERVICE` is still used (SA-1240).
- [ ] **Rupert / Dan:** add `container.developer` for the CI/CD SA on sandbox to Terraform.
- [ ] **Joe:** install `helm-docs` locally before changing the chart.
- [ ] **Ethan:** move the recording and notes to Confluence and add the overview diagram.
- [ ] **All:** bring questions to next week's catch-up.

## Things to watch in load testing

- Startup probe failures: raise the threshold from 5 to 7.
- HPA timings: about 30 seconds up and 10–15 minutes down.
- Node type: C4 versus E2, to save cost.
- Quota units: milli-CPU and GB.
