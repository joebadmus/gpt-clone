# Managing Secrets (Environment Variables)

## Managing secrets and environment variables.

It's common that you will need to use environment variables or other sensitive information Edge Functions. You can manage secrets using the CLI or the Dashboard.

You can access these using Deno's built-in handler

Deno.env.get('MY_SECRET_NAME')
Default secrets#
Edge Functions have access to these secrets by default:

SUPABASE_URL: The API gateway for your Supabase project.
SUPABASE_ANON_KEY: The anon key for your Supabase API. This is safe to use in a browser when you have Row Level Security enabled.
SUPABASE_SERVICE_ROLE_KEY: The service_role key for your Supabase API. This is safe to use in Edge Functions, but it should NEVER be used in a browser. This key will bypass Row Level Security.
SUPABASE_DB_URL: The URL for your Postgres database. You can use this to connect directly to your database.
## Local secrets#
You can load environment variables in two ways:

Through an .env file placed at supabase/functions/.env, which is automatically loaded on supabase start
Through the --env-file option for supabase functions serve, for example: supabase functions serve --env-file ./path/to/.env-file
Let's create a local file for storing our secrets, and inside it we can store a secret MY_NAME:

echo "MY_NAME=Yoda" >> ./supabase/.env.local
This creates a new file ./supabase/.env.local for storing your local development secrets.

Never check your .env files into Git!

Now let's access this environment variable MY_NAME inside our Function. Anywhere in your function, add this line:

console.log(Deno.env.get('MY_NAME'))
Now we can invoke our function locally, by serving it with our new .env.local file:

supabase functions serve --env-file ./supabase/.env.local
When the function starts you should see the name “Yoda” output to the terminal.

## Production secrets#
You will also need to set secrets for your production Edge Functions. You can do this via the Dashboard or using the CLI.

Using the Dashboard#
Visit Edge Function Secrets Management page in your Dashboard.
Add the Key and Value for your secret and press Save.
Note that you can paste multiple secrets at a time.
Edge Functions Secrets Management
Using the CLI#
Let's create a .env to help us deploy our secrets to production. In this case we'll just use the same as our local secrets:

cp ./supabase/.env.local ./supabase/.env
This creates a new file ./supabase/.env for storing your production secrets.

Never check your .env files into Git! You only use the .env file to help deploy your secrets to production. Don't commit it to your repository.

Let's push all the secrets from the .env file to our remote project using supabase secrets set:

supabase secrets set --env-file ./supabase/.env
# You can also set secrets individually using:
supabase secrets set MY_NAME=Chewbacca
You don't need to re-deploy after setting your secrets.

To see all the secrets which you have set remotely, use supabase secrets list:

supabase secrets list

