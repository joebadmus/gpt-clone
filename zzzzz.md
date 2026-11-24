Make a new GPG key on the Jamf machine for the same ONS email, and add it to your joeg-ons GitHub account alongside this Mac's key. GitHub accepts several keys, so commits from both machines will show as Verified. It's also safer than moving your private key between machines, especially as you can't easily copy files across.

Here's how this Mac is set up, so the Jamf machine can match it:
- An ed25519 key for "Joe Gbadamosi (joeg-ons) <joe.gbadamosi@ext.ons.gov.uk>", expiring after 1 year.
- `gpg` from Homebrew, with `pinentry-mac` for the passphrase prompt.
- Signing switched on only for repos under the ONS folder, through `~/.gitconfig-ons`.

## Steps on the Jamf machine

**1. Install GPG and the Mac passphrase prompt**

```sh
brew install gnupg pinentry-mac
```

If Homebrew isn't allowed, look in Self Service for "GPG Suite", or ask IT.

**2. Point GPG at the Mac prompt**

```sh
mkdir -p ~/.gnupg && chmod 700 ~/.gnupg
echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
echo 'export GPG_TTY=$(tty)' >> ~/.zshrc && source ~/.zshrc
```

**3. Create the key** (same name, email and type as this Mac)

```sh
gpg --quick-gen-key "Joe Gbadamosi (joeg-ons) <joe.gbadamosi@ext.ons.gov.uk>" ed25519 sign 1y
```

Set a passphrase when it asks.

**4. Get the key ID**

```sh
gpg --list-secret-keys --keyid-format=long
```

The ID is the part after `ed25519/` on the `sec` line, for example `ABCD1234EF567890`.

**5. Set up Git the same way as this Mac**

Change `~/my_ons.nosync/` to wherever your repos live on the Jamf machine, and put your key ID in place of `<KEY_ID>`:

```sh
git config --global includeIf."gitdir:~/my_ons.nosync/".path ~/.gitconfig-ons
git config --file ~/.gitconfig-ons user.name "Name"
git config --file ~/.gitconfig-ons user.email <email>
git config --file ~/.gitconfig-ons user.signingkey <KEY_ID>
git config --file ~/.gitconfig-ons commit.gpgsign true
git config --file ~/.gitconfig-ons gpg.program "$(brew --prefix)/bin/gpg"
```

If the Jamf machine is only ever used for ONS work, you can set these with `--global` instead and skip the `includeIf`.

**6. Add the public key to GitHub**

```sh
gpg --armor --export <KEY_ID> | pbcopy
```

In a browser on the Jamf machine, signed in as **joeg-ons**, go to Settings > SSH and GPG keys > New GPG key. Paste the key and give it a title like "Jamf Mac".

The ONS email is already verified on that account, because this Mac's commits show as Verified, so there's nothing else to do there.

**7. Test it**

```sh
cd <any ONS repo>
git config user.email         # should show the ONS email
git commit --allow-empty -m "test signing"
git log -1 --show-signature   # should say "Good signature"
git reset --hard HEAD~1       # remove the test commit
```

Your next real commit pushed from the Jamf machine should show "Verified" on GitHub.

Two small things:
- The key expires in a year, like this one. You'll get a reminder to extend it around November 2027.
- If `pinentry-mac` offers to save the passphrase in Keychain, tick it, or it'll ask on every commit.


====
Your remote is `https://`, so you push with a token and the SSH key isn't needed for pushing. Once GPG signing works, you can delete the SSH key safely.

That last command found nothing, though (the red cross means no matches). So Git in this repo has no signing settings yet, and the step 5 setup isn't being picked up. Your repos live in a `target-repo` folder, not `~/my_ons.nosync/`, so the `includeIf` path from step 5 doesn't match.

The Jamf machine is only used for ONS work, so the simplest fix is to set it globally:

```sh
git config --global user.name ""
git config --global user.email 
git config --global user.signingkey 
git config --global commit.gpgsign true
git config --global gpg.program "$(which gpg)"
git config --global --unset gpg.format
```

The last line clears any old SSH signing setting. If it errors, there wasn't one, which is fine.

Then check it, still inside `survey-assist-load`:

```sh
git config --show-origin --get-regexp '^(gpg\.|user\.|commit\.gpgsign)'
git commit --allow-empty -m "test signing"
git log -1 --show-signature
git reset --hard HEAD~1
```

You should see your ONS email, the key ``, and "Good signature". After that, add the key on GitHub (it's already on your clipboard from the `pbcopy`). Then push a real commit and check it shows Verified before deleting the SSH key.
