import { config } from "dotenv";
config({ path: ".env.test" }); // Force load .env.test
import "@testing-library/jest-dom";

console.log("SUPABASE_URL:", process.env.NEXT_PUBLIC_SUPABASE_URL);
