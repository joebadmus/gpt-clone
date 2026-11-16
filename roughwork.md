Yes. One plan on the Jamf machine, so we can prove the moved blocks work before raising the PR. Without it we'd only be assuming they do.

```bash
git fetch && git checkout fix/sa-1119-natcen-moved-blocks && git pull
cd survey-assist-sandbox-external
terraform plan -no-color -lock=false > natcen-moved.txt
grep "^Plan:" natcen-moved.txt
grep -E "has moved|survey-assist-vector-stores|survey-assist-api\b" natcen-moved.txt
```

What I'd expect to see:
- **16 to destroy** instead of 18.
- The network and subnet listed as **"has moved"**, not destroyed and created.
- **Fewer changes**, because the Gemini line is now in main.

A screenshot of those two `grep` outputs is enough.
