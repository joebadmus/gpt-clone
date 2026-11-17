stand-up and defend if asked.

**Stand-up**

> **Yesterday:** Got the Gemini model override, the Vertex AI region and the NatCen Gemini model merged, plus the Terraform version pin, so every environment is on the same version now. This morning the API side of the Vertex AI region change went in too, so that ticket's done.
>
> **Today:** Starting the Terraform version ticket. I've got a small tidy-up ready, and I'm waiting on Dan to confirm which version we move to before I raise it, so it all goes in one PR.
>
> **NatCen CI/CD ticket:** It's nearly there, but it can't be finished until NatCen finish testing, which is next week. I'll explain below if anyone asks.

**If someone asks why SA-1119 is still open**

> The code's basically done. The pipeline change is raised and in review, and the version pin it needed is merged. What's holding it is that NatCen are testing right now, and we agreed with Dan not to apply anything to their environment until they finish, so we don't disrupt them. Proving the pipeline properly needs a real plan and apply, so we can't close the ticket until after their testing. That's next week.
>
> There's also some catching up to do. The NatCen code in main was renamed after NatCen had already started testing, so main and what's deployed don't match yet. One apply after testing sorts that out, and I've got a small PR in review to make that apply safer.
>
> So it's not stuck, it's waiting on NatCen's testing window. I'd expect to close it the week after.

**Things that could come up**
- **"Can't you just apply it?"** "We could, but Dan and I agreed not to risk disrupting NatCen during testing. The plan removes some network resources, and there could be a dependency we haven't spotted."
- **"What about the app deployments?"** "The NatCen app triggers PR is in draft. It needs that same apply first, plus the data in the NatCen bucket, which Dan's checking."
- **"Anything blocking you?"** "Only the NatCen testing window. I'm also checking the CI/CD service account has enough access to NatCen for plans to run in the pipeline."


SA="serviceAccount:ons-cicd-surveyassist@ons-cicd-surveyassist.iam.gserviceaccount.com"
for P in ons-survey-assist-dev survey-assist-sandbox-external; do
  gcloud projects get-iam-policy $P --flatten=bindings --filter="bindings.members:$SA" --format="value(bindings.role)" | sort > /tmp/roles-$P.txt
done
diff /tmp/roles-ons-survey-assist-dev.txt /tmp/roles-survey-assist-sandbox-external.txt

