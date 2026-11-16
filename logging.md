Here's what's been said about logging and monitoring so far, and what you could ask.

**What's been discussed**
- **27 Oct infra sync:** logging and monitoring is "the next big piece before January". It's mostly at the edges, with few infrastructure changes.
- **28 Oct, with Dan and Ethan:**
  - The idea was one log sink in a central project, perhaps CI/CD, with a dashboard per component.
  - Moving workloads to GKE would change the tools, so requirements come before dashboards.
- **3 Nov:** Rupert got logs landing in the bucket after delays and syntax problems with the log sink.
- **Ethan, at another stand-up:** a subset of logs is now brought together for log analytics, so later you can write SQL queries and build dashboards. He asked developers to say what logs they want: "now is a good time to make sure we've got all the logs we want".
- **4 Nov refinement:**
  - There's a "logging the user journey" ticket, with Steve's name on it as a placeholder. It aims for the same logging as the last public test.
  - Correlation IDs will be a separate, nice-to-have ticket.
- **13 Nov stand-up:** Rupert's logging and monitoring spike is complete.
- **In Terraform:** dev, preprod and sandbox have `logging.tf` with the log analytics bucket. That was 10 Nov in dev, starting with SAYT.
  - **NatCen (sandbox-external) has none.**

**Questions to ask**
1. What did Rupert's spike recommend, and what's the order of work?
2. The log analytics bucket covers SAYT so far. When do the API, vector stores, API Gateway and jobs come in?
3. **Does NatCen get logging too?** It has no `logging.tf`, and it's the environment an external partner uses.
4. **Alerting:** what do we alert on (5xx rate, latency, restarts, gateway errors), who gets the alerts, and in which channel?
5. **Model deprecation:** can we add a log-based alert on Vertex AI "model not found"? That's the error that broke NatCen with Gemini 2.5 Flash. It links to the spike Dan agreed with you.
6. **GKE:** do we build dashboards on Cloud Run now, or wait for the move in January?
7. **Your part:** what can you pick up? For example, rolling the bucket out to NatCen, or Terraform for the alert policies.

**Good to know going in**
- The NatCen Terraform pipeline (SA-1119) is in review. Once it's live, adding logging to NatCen goes through the normal PR and plan flow.
- The OTP job deliberately errors on an empty database, as a crude monitor. If that changes, check with Ethan whether any alert depends on it.


======
I couldn't find notes from today's infra sync. Nothing new has been saved in `ons_ws/meeting/`, Downloads, Desktop or Documents in the last three hours. The newest notes are the Dan catch-up from this morning.

Can you paste the transcript, or save it as something like `ons_ws/meeting/1611-infra-sync.txt`? Once it's there, I'll summarise the decisions, your actions and any open questions, in the same format as the 27 Oct infra sync summary.
