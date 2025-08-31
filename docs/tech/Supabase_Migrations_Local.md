# Local Development with Schema Migrations
https://supabase.com/docs/guides/local-development/cli/getting-started


Develop locally with the Supabase CLI and schema migrations.

Supabase is a flexible platform that lets you decide how to build your projects. You can use the Dashboard directly for quick setup or opt for a proper local development workflow. We suggest working locally and deploying your changes to a linked Supabase project.

Use the CLI to run a local Supabase stack. You can make changes through the Studio Dashboard and capture them in schema migration files stored in version control.  

Alternatively, if you're comfortable with migration files and SQL, write your own migrations and push them to the local database before sharing.

---

## Database Migrations

Database changes are managed through *migrations*, a common way to track database changes over time.

In this guide, we'll create an `employees` table and demonstrate how to modify it.

### 1. Create Your First Migration File

Generate a new migration:

```bash
supabase migration new create_employees_table
````

### 2. Add the SQL to Your Migration File

A new migration file will be created:
`s‍upabase/migrations/<timestamp>_create_employees_table.sql`

Example:

```sql
create table employees (
  id bigint primary key generated always as identity,
  name text,
  email text,
  created_at timestamptz default now()
);
```

### 3. Apply Your Migration

Run the migration to create the `employees` table:

```bash
supabase db reset
```

### 4. Modify Your Employees Table

Create a new migration to add a `department` column:

```bash
supabase migration new add_department_to_employees_table
```

### 5. Add a New Column

Add the following to your migration file:
`s‍upabase/migrations/<timestamp>_add_department_to_employees_table.sql`

```sql
alter table if exists public.employees
add department text default 'Hooli';
```

---

## Add Sample Data

Create a seed script to add initial data.

**File:** `supabase/seed.sql`

```sql
insert into public.employees (name) 
values 
  ('Erlich Bachman'),
  ('Richard Hendricks'),
  ('Monica Hall');
```

### Reset and Populate the Database

```bash
supabase db reset
```

Your `employees` table should now appear in the Dashboard with the seed data.

---

## Diffing Changes

If you’re more comfortable using the Dashboard, you can use the CLI to generate migration files for your changes.

### Create a New Table via Dashboard

Create a table `cities` with columns `id`, `name`, and `population`.
Then run:

```bash
supabase db diff --schema public
```

The output will look like this:

```sql
create table "public"."cities" (
    "id" bigint primary key generated always as identity,
    "name" text,
    "population" bigint
);
```

Copy the SQL into a migration file and apply changes:

```bash
supabase db reset
```

---

# Deploy Your Project

After developing locally, deploy to the Supabase Platform.

### 1. Log in to the Supabase CLI

```bash
npx supabase login
```

### 2. Link Your Project

```bash
supabase link --project-ref <project-id>
```

You can get `<project-id>` from your project’s Dashboard URL.

Optional: Capture any remote database changes:

```bash
supabase db pull
```

Apply the generated migration locally:

```bash
supabase migration up
```

Or reset your local database completely:

```bash
supabase db reset
```

### 3. Deploy Database Changes

```bash
supabase db push
```

### 4. Deploy Edge Functions

```bash
supabase functions deploy <function_name>
```

---

## Use Auth Locally

Update `supabase/config.toml`:

```toml
[auth.external.github]
enabled = true
client_id = "env(SUPABASE_AUTH_GITHUB_CLIENT_ID)"
secret = "env(SUPABASE_AUTH_GITHUB_SECRET)"
redirect_uri = "http://localhost:54321/auth/v1/callback"
```

Add environment variables to `.env`:

```env
SUPABASE_AUTH_GITHUB_CLIENT_ID="redacted"
SUPABASE_AUTH_GITHUB_SECRET="redacted"
```

Restart your local instance:

```bash
supabase stop
supabase start
```

Pull auth schema migrations:

```bash
supabase db pull --schema auth
```

---

## Sync Storage Buckets

Pull storage policies:

```bash
supabase db pull --schema storage
```

Define buckets in `supabase/config.toml`:

```toml
[storage.buckets.images]
public = false
file_size_limit = "50MiB"
allowed_mime_types = ["image/png", "image/jpeg"]
objects_path = "./images"
```

Upload files:

```bash
supabase seed buckets
```

---

## Sync Any Schema

```bash
supabase db pull --schema <schema_name>
```

If the `supabase/migrations` directory is empty, run:

```bash
supabase db pull
supabase db pull --schema <schema_name>
```

---

## Limitations and Considerations

* Project settings cannot be updated via the local Dashboard; use the config file.
* The CLI version controls the local Studio version. Keep it updated to access the latest features.
