# Database Migrations
https://supabase.com/docs/guides/deployment/database-migrations

How to manage schema migrations for your Supabase project.

Database migrations are SQL statements that create, update, or delete your existing database schemas. They are a common way of tracking changes to your database over time.

---

## Schema Migrations

For this guide, we'll create a table called `employees` and see how we can make changes to it.

> You will need to install the Supabase CLI and start the local development stack.

### 1. Create Your First Migration File

Generate a new migration to store the SQL needed to create the `employees` table.

```bash
supabase migration new create_employees_table
````

### 2. Add the SQL to Your Migration File

This creates a new migration file in the `supabase/migrations` directory.
Add the following SQL to create the `employees` table:

**File:** `supabase/migrations/<timestamp>_create_employees_table.sql`

```sql
create table if not exists employees (
  id bigint primary key generated always as identity,
  name text not null,
  email text,
  created_at timestamptz default now()
);
```

### 3. Apply Your First Migration

Run this migration to create the `employees` table.

```bash
supabase migration up
```

You can now view the `employees` table in the local Dashboard.

### 4. Modify Your Employees Table

Add a new column for `department`.

```bash
supabase migration new add_department_column
```

### 5. Add a New Column to Your Table

Add the following SQL to the new migration file:

**File:** `supabase/migrations/<timestamp>_add_department_column.sql`

```sql
alter table if exists public.employees
add department text default 'Hooli';
```

### 6. Apply Your Second Migration

Run this migration to update the `employees` table.

```bash
supabase migration up
```

You should now see the `department` column added to your `employees` table in the local Dashboard.

---

## Seeding Data

Now that you are managing your database with migration scripts, it's helpful to have some seed data every time you reset the database.

### 1. Populate Your Table

Create a seed script at `supabase/seed.sql` and add the following:

```sql
insert into public.employees (name) 
values 
  ('Erlich Bachman'),
  ('Richard Hendricks'),
  ('Monica Hall');
```

### 2. Reset Your Database

Reset your database to reapply migrations and populate it with seed data.

```bash
supabase db reset
```

You should now see the `employees` table populated with seed data in the Dashboard.
All database changes are captured in code, and you can reset to a known state anytime.

---

## Diffing Changes

If you’re more comfortable using the Dashboard to create tables and columns, you can still use the CLI to diff your changes and create migrations.

### 1. Create Your Table from the Dashboard

Create a new table called `cities` with columns `id`, `name`, and `population`.
Then generate a schema diff:

```bash
supabase db diff -f create_cities_table
```

### 2. Add Schema Diff as a Migration

A new migration file will be created for you.

**File:** `supabase/migrations/<timestamp>_create_cities_table.sql`

```sql
create table "public"."cities" (
  "id" bigint primary key generated always as identity,
  "name" text,
  "population" bigint
);
```

### 3. Test Your Migration

Reset your local database and test the new migration.

```bash
supabase db reset
```

---

## Deploy Your Project

You’ve developed your project locally using migrations. Now it's time to deploy to the Supabase Platform and scale up!

1. **Log in to the Supabase CLI**

```bash
supabase login
```

2. **Link Your Project**

```bash
supabase link
```

3. **Deploy Database Migrations**

```bash
supabase db push
```

4. **Deploy Database Seed Data (Optional)**

```bash
supabase db push --include-seed
```

Visit your live project on Supabase, and you'll see the new `employees` table, complete with the `department` column.
