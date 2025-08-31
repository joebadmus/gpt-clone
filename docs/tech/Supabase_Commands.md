# Supabase Development Cheatsheet

## Quickstart
Reset database, apply migrations, and start functions server.
⚠️ Warning: Use the --import-map flag ensure the dependencies can be found.
```bash
npx supabase db reset && npx supabase functions serve --import-map ./supabase/functions/import_map.json
```
Optionally, then go to /test-supa and insert therapists. 
Or import CSVs of mock therapirsts.


## Local Development
```bash
npx supabase start
```

## Apply migrations to local
```bash
npx supabase migration up
```

## Reset Local Database
```bash
npx supabase db reset
```

## Database Management
```bash
# Create new migration file
npx supabase migration new create_therapists_table

# Dump specific table data (useful for backups)
npx supabase db dump --table http_request_queue
```
## Edge Functions
```bash
# Create new edge function
npx supabase functions new my-function

# Deploy edge function
npx supabase functions deploy my-function

# Test edge function locally
npx supabase functions serve
```

## Deployment
1. On first deployment, link to your project.
```
npx supabase link --project-ref your-project-ref
```
2. Push migrations to production
```bash
npx supabase db push
```
3. Deploy edge functions to production
```bash
npx supabase functions deploy --import-map ./supabase/functions/import_map.json
```


4. Optional: Generate TypeScript types from your database
```bash
npx supabase gen types typescript --local > types/supabase.ts
```

## Common Issues
- If `supabase start` fails, check if Docker is running
- If you get InvalidWorker, ensure you're passing the `import-map` flag to the functions serve/deploy commands.

## Troubleshooting
Check Supabase status
```bash
npx supabase status
```
Stop local instance 
```bash
npx supabase stop
```
View logs
```bash
npx supabase logs
```


