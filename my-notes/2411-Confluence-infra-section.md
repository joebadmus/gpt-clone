## Infrastructure

### Sandbox setup today, compared with last year's pilot

Sandbox is the environment for the first runs. Most services are fixed at one instance, so the first runs test sandbox as it is, not the size we'd use for the public test. Last year's pilot settings are kept as comments in the pre-prod config. They're the starting point for a later run at production-like size.

| Service | Sandbox now | Last year's pilot | What it means for the tests |
|---|---|---|---|
| SAYT UI (Cloud Run) | 1 instance, concurrency 40, 6 CPU, 4 GB | 10 to 20 instances | Can't scale. Concurrency 40 is above the 32 Redis connections per container. |
| Survey Assist API (Cloud Run) | 1 instance, concurrency 80, 1 CPU, 1 GB | 5 instances | Handles every save and every search. The most likely first bottleneck. |
| OTP service (Cloud Run) | 1 instance, concurrency 3 | 5 to 35 instances | Every journey starts with a login. A fast spawn rate could swamp it. |
| SAYT vector store (GKE) | 1 pod, scales to 2 at 50% CPU, 8 CPU and 32 GB per pod | New this year | Can only reach 2 pods. A second pod needs a new node, which takes time. |
| Redis (UI sessions) | Basic tier, 1 GB | Pre-prod uses the high-availability tier | Linked to the 32-connection risk. |

Search-as-you-type goes from the API to the GKE vector store. It doesn't use Gemini, so there's no Vertex AI quota or cost involved.

### Smoke run, 24 November

1 user for 5 minutes against sandbox, from a laptop on the VPN. 33 requests with no failures.

| Request | Response time |
|---|---|
| Page views | 50 to 80 ms |
| Answer saves | 350 to 680 ms |
| Login (access code check) | about 540 ms |
| Business activity suggestions | 742 ms median, 946 ms max |

Suggestions are already close to the 1 second p95 target with one user. Before adding load, we'll check how much of that is the VPN and how much is the API or the vector store, using the Cloud Run and load balancer numbers.

### Infrastructure test cases

These sit alongside Tests 1 to 3. They focus on the vector store, which is new this year.

| Test | How | What it tells us | What we watch |
|---|---|---|---|
| Infra 1: Capacity of one pod | Call the vector store directly, stepping up through 5, 10, 20 and 30 requests a second | The most one pod can handle within the latency target | Pod CPU, p95 latency, errors |
| Infra 2: Search only | A Locust user that logs in once, then only calls suggestions with varied search terms. Step the load up. | Load on the whole search path, without page saves in the way | API latency against vector store latency, to show which step is slow |
| Infra 3: Scale-up timing | Start at 1 pod and push CPU past 50%. Time each step until the new pod serves its first request. | Whether scaling is fast enough, or whether we need 2 pods from the start | Pod and node events, time to ready |
| Infra 4: Losing a pod | During a steady run, delete one pod with 2 running, then with 1 | What users see if a pod restarts or is moved | Error spike and how long it lasts |
| Infra 5: Soak | 30 to 60 minutes at realistic load (Test 2 settings) | Memory and latency stay flat over time | Memory, restarts, latency trend |

Infra 4 only runs in sandbox.

### What we watch during each run

Locust shows response times from the laptop. Alongside it we'll watch:

- **Cloud Run (UI, API, OTP):** requests, latency, 5xx errors, instance count, CPU
- **Vector store (GKE):** pod CPU and memory, number of pods, restarts
- **Load balancer:** latency and errors per page
- **Redis:** connections
- **Cloud Armor:** blocked requests

We'll note the start and end time, the Locust settings and the image versions for each run, so the runs can be compared. Server-side latency is reported next to the Locust numbers, because Locust's numbers include the VPN.

### Before the final pre-prod run

- Run only after manual testing in pre-prod has finished.
- Use a set-aside block of the existing access codes. Making a new set would wipe the testers' codes.
- Apply the agreed public test settings to pre-prod first.
- If the UK-only rate limit is on (60 requests a minute per address), keep the Locust address on the allow-list, or the run will get blocked.

### Open points

- Where does the 32 Redis connection limit come from, and is it per container or per instance?
- Does the real UI call suggestions on every keystroke? If so, Locust's 5 to 10 searches may under-count.
- Should we do a run at last year's pilot settings after the first sandbox runs?


====


==
The page looks good overall. Fix two things before you message Geoff:

1. **"Before the final pre-prod run" is under Results overview.** It isn't a result, so move it to the end of Test Plan, after Infrastructure test cases. The "Open points" heading also got lost, so the three questions now read as pre-prod steps. Put the heading back above the Redis, keystroke and pilot settings questions.
2. **The smoke run sits above Geoff's results table.** Move it below his table, so Results overview opens with the Test 1 and Test 2 results. Or add it as a "Smoke" row in his table and keep your table underneath for the detail.

Optional: Environment and Monitoring each have one subheading under them, which repeats itself. You could drop "Sandbox setup today…" and "What we watch during each run" and keep the intro text. It's fine either way.

There's also a small mismatch in Geoff's part. The Test 2 description says a spawn rate of 5 users a second, but its config says `spawn-rate = 1`. It's his section, so just mention it in the message.

Here's the message for Geoff:

> Hi Geoff, I've added the infra bits to the load testing page: the environment and monitoring under Setup, the vector store tests under Test Plan, and yesterday's smoke run under Results. Feel free to move anything around. One small thing I noticed: the Test 2 description says a spawn rate of 5, but the config has 1. Which one do you want to go with?

On codes: Test 1 could use about 250 to 300, and Test 2 about 150. So get the new set before Wednesday's run.Results. Feel free to move anything around. One small thing I noticed: the Test 2 description says a spawn rate of 5, but the config has 1. Which one do you want to go with?
