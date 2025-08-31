# Supabase Tools

Note: This server is pre-1.0, so expect some breaking changes between versions. Since LLMs will automatically adapt to the tools available, this shouldn't affect most users.

The following Supabase tools are available to the LLM:

## Project Management
Note: these tools will be unavailable if the server is scoped to a project.

- list_projects: Lists all Supabase projects for the user.
- get_project: Gets details for a project.
- create_project: Creates a new Supabase project.
- pause_project: Pauses a project.
- restore_project: Restores a project.
- list_organizations: Lists all organizations that the user is a member of.
- get_organization: Gets details for an organization.

## Database Operations
- list_tables: Lists all tables within the specified schemas.
- list_extensions: Lists all extensions in the database.
- list_migrations: Lists all migrations in the database.
- apply_migration: Applies a SQL migration to the database. SQL passed to this tool will be tracked within the database, so LLMs should use this for DDL operations (schema changes).
- execute_sql: Executes raw SQL in the database. LLMs should use this for regular queries that don't change the schema.
- get_logs: Gets logs for a Supabase project by service type (api, postgres, edge functions, auth, storage, realtime). LLMs can use this to help with debugging and monitoring service performance.

## Edge Function Management
- list_edge_functions: Lists all Edge Functions in a Supabase project.
- deploy_edge_function: Deploys a new Edge Function to a Supabase project. LLMs can use this to deploy new functions or update existing ones.

## Project Configuration
- get_project_url: Gets the API URL for a project.
- get_anon_key: Gets the anonymous API key for a project.

## Branching (Experimental, requires a paid plan)
- create_branch: Creates a development branch with migrations from production branch.
- list_branches: Lists all development branches.
- delete_branch: Deletes a development branch.
- merge_branch: Merges migrations and edge functions from a development branch to production.
- reset_branch: Resets migrations of a development branch to a prior version.
- rebase_branch: Rebases development branch on production to handle migration drift.

## Development Tools
- generate_typescript_types: Generates TypeScript types based on the database schema. LLMs can save this to a file and use it in their code.

## Cost Confirmation
- get_cost: Gets the cost of a new project or branch for an organization.
- confirm_cost: Confirms the user's understanding of new project or branch costs. This is required to create a new project or branch.
