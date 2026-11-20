Here are the details to paste into SA-1266:

**Description**

SA-1244 added an optional maintenance exclusion to the GKE module and tested it in sandbox. Preprod doesn't have one yet, because the public test dates aren't agreed.

Without an exclusion, Google can upgrade the preprod cluster in its daily 2am window. A node upgrade restarts the SAYT pods, and each new pod has to pull a large image and download the embedding model before it can serve. That could slow down or break search-as-you-type during the public test.

This ticket sets the preprod exclusion to cover the public test, as part of the final test preparations.

**Approach**

1. Get the confirmed public test dates. Check whether December's load testing also needs a stable cluster.
2. In `ons-survey-assist-preprod/vector-stores.tf`, set `gke_maintenance_exclusions` on the GKE module, with a day either side of the test and the `NO_MINOR_OR_NODE_UPGRADES` scope.
3. Update the preprod changelog and raise a PR. The plan should show one in-place change to the cluster.
4. Merge. The pipeline applies it to preprod.
5. Check the exclusion shows in the GKE console (Cluster details, Maintenance exclusions).

**Things to be aware of**

- Google can still apply urgent security fixes during an exclusion.
- If the test dates move, update them and apply again.
- Remove the exclusion after the test, so preprod gets upgrades again.

**Definition of done**

- Public test dates confirmed
- Preprod exclusion set to cover the test, with a day either side
- Preprod plan shows only the expected in-place change
- Applied through the pipeline and visible in the GKE console
- Changelog updated
- Follow-up noted to remove the exclusion after the test

**Label:** SAYT public test. **Linked to:** SA-1244 (depends on).

I've also updated your local files. SA-1244 now references SA-1266, and the follow-up item is ticked. The draft is renamed to [SA-1266.md](SA-1266.md) with the new title.
