#### Issue: Vitest cannot find .env keys

**Error Message:**
Error: supabaseUrl is required.

**What It Means:**
Vitest tests could not access the required Supabase environment variables, so the Supabase client could not be initialized.

**Steps Attempted:**
- Created `.env.test` with correct keys in `todo-app/`
- Added `import 'dotenv/config'` to `vitest.setup.ts`
- Installed `dotenv` as a dev dependency
- Forced loading of `.env.test` in `vitest.setup.ts` with:
  ```typescript
  import { config } from 'dotenv';
  config({ path: '.env.test' });
  ```
- Added a debug log to confirm env loading
- Re-ran tests and checked output

**Solution:**
- Explicitly load `.env.test` using `config({ path: '.env.test' })` in the Vitest setup file.
- Ensure `dotenv` is installed.
- Confirmed with a debug log that the environment variable is loaded.
- After these changes, tests now pass and environment variables are available to Vitest.

**Result:**
Tests now pass and environment variables are available to Vitest. Confirmed by debug log and successful test run.

