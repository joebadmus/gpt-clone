# Setup Guide (10min)

Populate ANTHROPIC_API_KEY and OPENAI_API_KEY.
- In the root directory, rename `.env.example` and rename as `.env` 

Get your OPENAI_API_KEY
- Populate `supabase/functions/.env`

Setup Task Master in MCP settings [Task Master AI](https://github.com/eyaltoledano/claude-task-master?tab=readme-ov-file)

Go through the Task Master Setup above.

## Backend Setup
 Download Docker according to your system [Docker](https://docs.docker.com/get-started/get-docker/)

Download the Supabase CLI [Supabase CLI Install](https://supabase.com/docs/guides/local-development/cli/getting-started)

Add OpenAI Keys: In the `supabase` folder, rename `supabase/functions/.env.example` and rename as `.env` [Get OpenAI Keys](http://platform.openai.com/account/)


Start Supabase
```
npx supabase start
```
Note: If you change your `supabase/functions/.env` file locally, then you'll need to restart `npx supabase stop && npx supabase start`

Update your NextJS app `.env.local` file
```
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=ey...
```

Serve Functions Locally
```
npx supabase functions serve --import-map ./supabase/functions/import_map.json
```

Call the `hello-world` edge function.
```
  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/hello-world' \
    --header 'Authorization: Bearer SUPABASE_ANON_KEY' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'
```






Instructions
- Rename .env.example to .env in `supabase/functions/.env` and add your OPENAI_API_KEY
