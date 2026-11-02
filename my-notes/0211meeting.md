
## The goal in one line
NatCen was set up by hand. We're putting its Terraform on `main` so the pipeline can manage it like the other environments.

## What we did and why
1. **Moved the NatCen folder onto a branch off `main`.** It lived on an old feature branch, and the pipeline only works from `main`.
2. **Fixed the gateway hostname.** NatCen's copy had sandbox's gateway address, so the plan would have broken NatCen's gateway.
3. **Bumped the gateway config version to `v3`.** The hostname fix needs a new config. `v1` already exists and `v2` is Dan's hand-made one, so `v3` is the next free name.
4. **Renamed two network resources.** ONS checks reject underscores in names. `moved` blocks tell Terraform it's a rename, so nothing gets deleted.
5. **Added a deny-all firewall rule.** A security check (checkov) wanted it written out explicitly. It changes nothing in practice.
6. **Made the NAT IP secret name a variable.** NatCen has its own secret, `nat-ip-natcen-ext`. Other environments keep the default `nat-ip`.
7. **Fixed a bug in Dan's SA-1121 change.** His bucket-name check crashes when no name is set, which would hit every other environment.

## API gateway: what's in the box

```
   Survey UI / api-eval job / testers
                 |
                 v
  +----------------------------------------+
  |  API GATEWAY  (survey-assist-api-gw)   |
  |  hostname: ...-7i5aup1a.nw.gateway.dev |
  |                                        |
  |  uses one CONFIG at a time:            |
  |   v1 = old, has sandbox hostname       |
  |   v2 = Dan made by hand   <- LIVE      |
  |   v3 = Terraform will make             |
  |                                        |
  |  a config = OpenAPI file with:         |
  |   - host     = gateway hostname        |
  |   - audience = gateway hostname        |
  |   - backend  = Cloud Run API URL       |
  +----------------------------------------+
                 |  calls as service account
                 v
       Cloud Run: survey-assist-api
                 |
                 v
   Vector stores (SIC / SOC / SAYT), Firestore
```

**Key points:**
- **A config is a snapshot of the API rules.** You can't edit one. You make a new one and give it a new name.
- **Why the hostname matters:** the gateway checks that callers' tokens were made for its own hostname. With sandbox's hostname, NatCen calls would fail.
- **Why `v3`:** a new config needs a new name. `v1` and `v2` are taken.
- **The gateway stays on `v2` for now.** Terraform is told to ignore which config the gateway uses, so `v3` gets created but isn't switched on. Moving the gateway to `v3` is a later step.
- **The root problem:** you only know the gateway hostname after the gateway exists, which is why Dan had to fix it by hand first time. That's the "hard-coded gateway URL" ticket.

## What's the api-eval job?
- It's a Cloud Run job, a one-off batch run, not a service that stays up.
- It reads test survey answers from a storage bucket.
- It sends them through the API gateway to the API.
- It saves the results in Firestore so the team can check how good the classification is.
- It uses the gateway hostname, so it had the wrong one too until we fixed it.
- Dan's SA-1121 lets you set the bucket name, because NatCen's project ID makes the default name too long.

## The questions you sent, and what to listen for
1. **Does he want GKE in NatCen?** `main` now creates a GKE cluster there. If not, we add an on/off switch.
2. **Where are the Cloud Build plan triggers defined?** They aren't in any repo, so probably in the console. We need them to copy for NatCen.
3. **Is he OK with the SA-1121 fix?** It's small and safe.
4. **Move the gateway to `v3` now or later?** Suggest later, under the hard-coded URL ticket.
5. **(if you added it) Does the CI/CD service account have access to the NatCen project and its state bucket?** Dan applied with his own login, so maybe not.

## Also worth mentioning
- Before the first pipeline apply, someone has to add a value by hand to the new GKE whitelist secret, `natcen-sandbox-gke-master-whitelist-cidrs`.
- Next steps: you re-run the plan, raise the PR, then set up the trigger.
