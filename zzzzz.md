Hi all,
Could someone please review my GKE maintenance exclusion PR (SA-1244) when you get a chance? [link] It prevents sandbox node upgrades during load testing, so results stay consistent between runs.
It's a small change. The exclusion is optional and off by default, so there are no preprod changes. Sandbox gets a one-time update with a two-week window starting 25 November, and it's already planned in both environments.
Thanks!
