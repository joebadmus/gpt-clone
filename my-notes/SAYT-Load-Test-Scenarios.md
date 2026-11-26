Survey Assist · sandbox · load testing

# SAYT load test scenarios

Each scenario asks one question about the system. It lists the settings to use, what should happen, what isn't normal, and where to look. Use it with the [run sheet](https://claude.ai/artifact/83kU7wvXc3MQ8yL4HYQmd4) (what to do on the day) and the [map](https://claude.ai/artifact/XpjhtBGgkzWTR95ABwVzDV) (where each check lives).

## Pass rules for every scenario

- **Search suggestions:** 95% answered in 1 second or less (p95), 99% in 3 seconds or less (p99).
- **Pages and saving answers:** the same, p95 1 second or less and p99 3 seconds or less.
- **Errors:** none we can't explain. Report anything over 3 seconds, and investigate anything over 10 seconds.
- **Health:** nothing crashes or restarts, and latency doesn't keep rising while the number of users stays the same.

These come from Geoff's Confluence page. The CPU limits in the tables below are suggestions to help you spot trouble. They haven't been agreed with the team. Sandbox runs the UI, API and OTP service on one fixed instance each, so the instance count won't change during any of these runs.

## All scenarios at a glance

In a suggested order: find the limit cheaply first, then run the main tests, then the vector store checks. "Think time" is the random pause before each answer. Zero or near zero makes each Locust user much busier than a real person.

| # | The question | Users | Added per second | Think time | How long | Codes (rough) | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S1 | [Does the test work end to end?](#s1) | 1 | 1 | 0–3 s | 5 min | about 25 | done 24 Nov |
| S2 | [How many users before search slows down?](#s2) | 5 → 10 → 15 → 20 | 2 | 0–3 s | 2 min a step | about 500 | to do |
| S3 | [Is search the bottleneck on its own?](#s3) | 5 → 10 → 20 | 2 | search only | 3 min a step | about 35 | needs Geoff |
| S4 | [Can 25 busy users use it at once? (Test 1)](#s4) | 25 | 5 | 0–3 s | 10 min | about 500 | 504s on 25 Nov |
| S5 | [Can 25, then 50, real-paced users finish? (Test 2)](#s5) | 25, then 50 | 1–2 | 12–30 s | 15 min each | about 350 | to do |
| S6 | [Can everyone log in at the same moment?](#s6) | 25, then 50 | all at once | 0–3 s | 2 min | about 300 | to do |
| S7 | [Does it stay healthy for an hour? (soak)](#s7) | 25 | 1–2 | 12–30 s | 60 min | about 350 | to do |
| S8 | [What breaks first when we push hard? (Test 3)](#s8) | 50 | 5 | 0 s | 15 min | thousands | needs more codes |
| S9 | [How many searches a second can one vector store pod take?](#s9) | direct calls | steps | none | 2–3 min a step | none | with Ethan |
| S10 | [Does the vector store add a second pod fast enough?](#s10) | enough to pass 50% CPU | — | — | until pod 2 is ready | few | to do |
| S11 | [What do users see if a vector store pod dies?](#s11) | 25 | 1–2 | 12–30 s | 15 min, twice | about 200 | sandbox only |

Codes = users × (1 + run length ÷ journey length). A journey takes about 13 seconds at 0–3 s think time, and about 4 to 5 minutes at 12–30 s. Failed journeys still use a code, so runs with lots of errors use more.

S1 · SMOKE

### Does the test work end to end?

Proves Locust, the access codes, the dashboard and the results all work before adding load.

**Given** 1 user, 0–3 seconds think time, 5 minutes

**When** the user goes through the whole survey, including searches

**Then** every request succeeds

**And** the dashboard shows the traffic in every section except Gemini

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Failures | 0 | Any failure, especially 401 (bad code) or 403 (Cloud Armor) | Locust failures tab |
| Suggestions latency | Under 1 s | Over 1 s with only one user | Latency p50, p95 and p99 (ms) · Load balancer |
| Traffic showing | Lines move in each section | A section stays flat | Every section of the dashboard |

**Done 24 Nov:** 33 requests with no failures. Suggestions took 742 ms at the median, which is already close to the 1 second target with one user.

S2 · STEP-UP

### How many users before search slows down?

Finds the knee: the user count where latency jumps. That's the most useful number for tuning, and the one to beat after a fix.

**Given** 5 users, then 10, then 15, then 20, each step held for 2 minutes

**And** users added 2 per second, with 0–3 seconds think time

**When** each step has settled for a minute

**Then** we write down the suggestions p95 and the error count for that step

**And** we note the first step where p95 goes over 1 second, or 504s start

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Suggestions p95 per step | Rises a little with each step | Jumps suddenly between two steps. That's the knee. | Latency p50, p95 and p99 (ms) · Load balancer, and `lt-summary.sh` for each step's window |
| API latency | Follows the load balancer's latency | Much higher than at 5 users while the vector store CPU stays low | Latency p95, by service (ms) · Cloud Run |
| API CPU | Under about 80% | Stuck near 100% | CPU utilisation p95, by service · Cloud Run |
| Vector store CPU | Rises with the load | Flat at about one core (12%) while the API is slow | CPU used against request, by pod · GKE, or the live line |
| Errors | 0 | 504s on suggestions | 4xx and 5xx per second · Load balancer |

**Expect in sandbox today:** the knee somewhere between 5 and 25 users, most likely at the vector store's single process (the API waits on it). Geoff can run the steps as separate short runs. Write down the start and end time of each one.

S3 · INFRA 2

### Is search the bottleneck on its own?

Takes page views and saves out of the picture, so any slowdown is the search path: UI → API Gateway → API → vector store. Cheap on codes, because each user logs in once.

**Given** a Locust user that logs in once, then only searches with varied terms

**And** 5 users, then 10, then 20, each step held for 3 minutes

**When** the searches are running

**Then** suggestions p95 stays at 1 second or less

**And** we can see whether the API or the vector store slows down first

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Suggestions p95 | 1 s or less | Over 1 s at a low user count | Latency p50, p95 and p99 (ms) · Load balancer |
| API compared with load balancer | About the same | The load balancer is much slower than the API: the time is lost in the UI or API Gateway | `lt-summary.sh`: suggestions p95 at the load balancer and at the API |
| API warnings | None | `ReadTimeout` or `PoolTimeout`: the vector store is too slow | `lt-summary.sh`, last section |
| Requests per second | Goes up with each step | Stops going up while latency climbs: the limit has been reached | Requests per second, by service · Cloud Run |

**Needs:** Geoff to add a search-only user class to the Locust suite.

S4 · TEST 1

### Can 25 busy users use the system at once?

A stress test at about the expected peak. Each user moves much faster than a real person, so it puts on more load than 25 real people would.

**Given** 25 users, added 5 per second, with 0–3 seconds think time

**And** 5 to 10 searches per search question, for 10 minutes

**When** all 25 users are running

**Then** the pass rules hold: p95 1 s or less, p99 3 s or less, no errors

**And** latency stays level for the whole 10 minutes

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Errors | 0 | 504s on suggestions after about 10 s: the UI gave up on the API | 4xx and 5xx per second · Load balancer, then 4xx and 5xx per second, by service · Cloud Run |
| Latency over time | Level after the first minute | Keeps climbing: requests are queueing | Latency p50, p95 and p99 (ms) · Load balancer |
| API busy | CPU under about 80% | CPU near 100%, and concurrency rising | CPU utilisation p95, by service and Max concurrent requests per instance (p99) · Cloud Run |
| Vector store | Under 50% CPU stays at 1 pod. Over 50% adds pod 2. | Restarts, or pod 2 stuck in Pending | Pods running, Container restarts, by pod · GKE |
| Redis | Connections well under 32 | Flat at a ceiling, and pages failing | Redis connected clients · Redis and Cloud Armor |

**25 Nov laptop check:** 504s on suggestions. The UI gave up after about 10 s, while the API took 9 to 17 s and the vector store never scaled. The API's CPU stayed low, so it was most likely waiting on the vector store. Expect it to fail on suggestions until the search path is tuned.

S5 · TEST 2

### Can 25, then 50, real-paced users finish the survey?

The closest to the real public test. The busiest expected moment is about 27 people at once, so 25 is realistic and 50 gives double the headroom. This is the most important one to pass.

**Given** 25 users, added 1 to 2 per second, with 12–30 seconds think time

**And** 15 minutes, then the same again with 50 users

**When** users read each page, pause and answer, like real people

**Then** the pass rules hold, and at least 99% of journeys finish

**And** no part of the system is close to its limit at 25 users

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Journeys finished | 99% or more | Users dropping out partway | Locust statistics, and failures by endpoint |
| Suggestions and pages | p95 1 s or less, p99 3 s or less | Either over target at 25 users | Latency p50, p95 and p99 (ms) · Load balancer |
| Headroom at 25 | API and UI CPU under about 50% | Over about 80% at 25: 50 will probably fail | CPU utilisation p95, by service · Cloud Run |
| Errors | 0 | Any 5xx | 4xx and 5xx per second, by service · Cloud Run |

**Expect:** 25 real-paced users is much lighter than 25 busy ones (S4), so this may pass at 25 even if S4 fails. 50 users is the real question.

S6 · LOGIN BURST

### Can everyone log in at the same moment?

Invite emails go out at the same time, so logins can bunch up. Every journey starts with a login through the OTP service, which runs as one instance handling 3 requests at a time.

**Given** 25 users added all at once (25 per second), with 0–3 seconds think time

**And** 2 minutes, then the same again with 50 users

**When** every user tries to log in during the first second or two

**Then** every login succeeds within 3 seconds

**And** the OTP service sends back no 429 or 503 errors

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Login errors | 0 | 429 (too busy) or 503 from the OTP service | 4xx and 5xx per second, by service · Cloud Run (firestore-otp-api) |
| OTP concurrency | Under 3 | Stuck at 3: requests are queueing or being turned away | Max concurrent requests per instance (p99) · Cloud Run |
| Login latency | About 0.5 s | Several seconds in the first minute | Latency p95, by service (ms) · Cloud Run |
| 401s | 0 | 401: used or expired codes. That's a Locust CSV problem, not the infra. | Locust failures tab |

**Expect in sandbox today:** slow logins or 429s, because the OTP service is 1 instance with concurrency 3. Last year's pilot ran it at 5 to 35 instances.

S7 · INFRA 5 · SOAK

### Does it stay healthy for an hour?

Some problems only show over time: memory slowly filling up, connections not being released, latency creeping up.

**Given** the S5 settings: 25 users, 12–30 seconds think time

**When** it runs for 60 minutes

**Then** latency at the end is the same as after the first 5 minutes

**And** memory stays level, and nothing restarts

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Latency trend | Flat line | Slowly climbing | Latency p50, p95 and p99 (ms) · Load balancer, time range set to the full hour |
| Memory | Level after warming up | Climbing steadily: a leak | Memory used, by pod · GKE, and Memory utilisation p95, by service · Cloud Run |
| Restarts | 0 | Any restart | Container restarts, by pod · GKE |
| Redis | Connections level | Connections creeping up over the hour | Redis connected clients and Redis memory usage |

S8 · TEST 3 · STRESS

### What breaks first when we push hard?

Not pass or fail. It shows the order things break in, and whether the system recovers once the load stops.

**Given** 50 users, added 5 per second, with no think time

**When** it runs for 15 minutes

**Then** we write down the first thing to struggle, and when

**And** within 5 minutes of stopping, latency and CPU are back to normal

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| First to struggle | Something will. That's expected. | Several things at once, with no clear first | All sections. Note the times in order. |
| Recovery | Back to the S1 numbers within 5 minutes | Still slow, or errors after the load has stopped | Keep the live line running for 5 minutes after the stop |
| Crashes | None | Restarts or OOMKilled | Container restarts, by pod, and `kubectl get events` |

**Needs:** a bigger batch of codes, because no think time uses thousands. Probably best after the API has been tuned, or it only tells us what we already know.

S9 · INFRA 1

### How many searches a second can one vector store pod take?

Measures the vector store on its own, without the UI or the API in front, so we know its real limit.

**Given** one vector store pod, called directly (not through the UI)

**And** 5, then 10, 20 and 30 searches a second, each held for 2 to 3 minutes

**When** each rate has settled

**Then** we find the highest rate where its p95 stays at 1 second or less

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| CPU per rate | Goes up with the rate | Stuck at about 1000m (one core) whatever the rate: one process is the limit | `kubectl top pods -n vector-store`, or CPU used against request, by pod |
| Response time | p95 1 s or less | Climbs sharply at one rate. That's the pod's limit. | The load tool's own output (Apache Bench or similar) |
| Pods | Stays at 1 | The HPA adds pod 2 partway through, so it's no longer measuring one pod | `kubectl get hpa -n vector-store -w` |

**Before:** Ethan got about 22 a second with Apache Bench. Run it with him. The vector store sits behind an internal load balancer, so it has to be called from inside the network.

S10 · INFRA 3

### Does the vector store add a second pod fast enough?

The second pod needs a brand new 8-CPU node, the 8 GB image and a model download. If that takes minutes, users see errors in the meantime, and we should start with 2 pods.

**Given** the vector store at 1 pod, and enough search load to push its CPU over 50%

**When** the HPA asks for a second pod

**Then** we time each step: asked, node ready, pod running, pod serving

**And** users see no errors while it happens

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| HPA asks | Replicas go from 1/1 to 1/2 within about 15 seconds of passing 50% | Never asks, because CPU never reaches 50% | The live line, or `kubectl get hpa -n vector-store -w` |
| Pod 2 ready | Running within a few minutes | Pending for more than 5 minutes, or a quota error | `kubectl get pods -n vector-store -w`, `kubectl get events -n vector-store`, Pods running |
| Users meanwhile | No errors | 504s until pod 2 is ready | 4xx and 5xx per second · Load balancer |

**Expect in sandbox today:** it may never trigger. The vector store runs one process, so its CPU may sit at about 12%. If so, that's the finding: the HPA can't help until it runs more workers.

S11 · INFRA 4

### What do users see if a vector store pod dies?

Pods get moved or restarted (upgrades, node problems). This shows how bad that is for someone halfway through the survey.

**Given** the S5 settings running steadily, with the vector store pinned at 2 pods

**When** we delete one pod with `kubectl delete pod`

**Then** searches carry on with few or no errors, because the other pod takes over

**And** with only 1 pod, we time how long searches fail before a new pod is ready

| Check | Normal | Not normal | Where to look |
| --- | --- | --- | --- |
| Errors with 2 pods | A brief blip or none | Errors for more than a few seconds | 4xx and 5xx per second · Load balancer |
| Errors with 1 pod | Errors until the new pod is ready. Time it. | Errors carry on after the pod is Running | The live line, and Pods running |
| Replacement pod | Back to Running | CrashLoopBackOff, or stuck in Pending | `kubectl get pods -n vector-store -w` |

**Before:** sandbox only. Agree it with Ethan and Dan first. Pin at 2 pods with the `kubectl patch hpa` command on the run sheet, and undo it afterwards.

Settings for S1, S4, S5 and S8 follow Geoff's tests and what we agreed in Teams on 24 and 25 November. S2 is a suggestion. S3 and S7 to S11 are the infra tests on the Confluence page.

Dashboard names are the tile titles on "SAYT load testing (sandbox)", in its five sections: Load balancer, Cloud Run, GKE, Redis and Cloud Armor, and Gemini.