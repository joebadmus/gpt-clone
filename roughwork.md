Written for: your team at stand-up, spoken or posted.

> **Yesterday:** Got the Gemini model override, the Vertex AI region setting and the NatCen Gemini model merged in Terraform, plus the Terraform version pin, so all environments now use the same version. Ran a NatCen plan and found a big diff from the folder move. Agreed with Dan that NatCen stays plans only until NatCen finish testing. Raised a small PR so the network and subnet are kept, not recreated, when we do apply. Put the NatCen app triggers back in draft until then. Also wrote up the logging catch-up and a ticket list.
>
> **Today:** Raising two tech debt tickets, one for build once, promote many and one for a model deprecation alert. Then checking with Dan on who picks up the logging tickets, starting with the NatCen token alert.
>
> **Waiting on:** Reviews for the API Vertex AI region change, the NatCen Terraform pipeline and the moved blocks PR. The NatCen app triggers are on hold until NatCen testing finishes.
