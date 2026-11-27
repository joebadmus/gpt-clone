Yes, this is the Terraform upgrade . Our pipelines copy the Terraform binary from Platform Engineering's `ons-ci-binaries` bucket, and 1.17.2 isn't in there yet. Here's the request:

**Short description:**
> Add Terraform 1.17.2 binary to the ons-ci-binaries bucket

**Description:**
> Hi, please could Platform Engineering security scan and add the Terraform 1.17.2 binary to the `ons-ci-binaries` GCS bucket?
>
> **Why:** the Survey Assist team is upgrading Terraform from 1.11.0 to 1.17.2 across our environments. Our Cloud Build pipelines (in the `ons-cicd-surveyassist` project) pull the binary from your bucket with:
> `gsutil cp gs://ons-ci-binaries/terraform-<version> /usr/bin/terraform`
> Our plan checks currently fail at this step, because `terraform-1.17.2` isn't in the bucket.
>
> **What we need:**
> - File name `terraform-1.17.2`, matching the existing `terraform-1.11.0`
> - Linux amd64 build, because it runs in Cloud Build
> - Source: https://releases.hashicorp.com/terraform/1.17.2/ (checksums are in `terraform_1.17.2_SHA256SUMS` there)
>
> If 1.17.2 can't be added soon, could you tell us which Terraform versions are already in the bucket? We can upgrade to the latest of those instead.
>
> Thanks!

If you already have a reference from your earlier email to Platform Engineering, mention it in the request so they can link the two.
