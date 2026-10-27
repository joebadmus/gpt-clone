**SIC** isn't an endpoint. It's the industry code the app is trying to find. For example, `43210` means "electrical installation". The three endpoints are three steps towards that code.

**The happy path**, using the API directly with no UI:

```
Person describes their job and what their company does
   │
   ▼
1. LOOKUP     GET /sic-lookup     "Is this an exact match in the SIC list?"
   │            yes → returns the SIC code → go to step 3
   │            no  ↓
   ▼
2. CLASSIFY   POST /classify      "AI, which SIC code fits best?"
   │            sure     → returns the SIC code
   │            not sure → returns a follow-up question + a shortlist of codes
   │                        (person answers or picks one from the list)
   ▼
3. RESULT     POST /result        "Save everything the person said and got back"
```

**Like you're 10:** it's like asking a librarian where a book goes.
- **Lookup:** they check the index. If the title is there exactly, done.
- **Classify:** if it's not in the index, they think it over and suggest the best shelf. If they're unsure, they ask you one more question.
- **Result:** they write down everything in a notebook so someone can check it later.

The "type, see a list, pick one" journey you described is the new search-as-you-type UI. In the API flow above, picking from a list only happens at the follow-up stage.