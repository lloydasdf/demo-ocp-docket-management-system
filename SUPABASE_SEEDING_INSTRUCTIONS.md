# Supabase Seed Data Setup Guide

## Overview

The seed data includes 10 realistic dockets with multiple cases, persons, violations, and full audit trails.

**All data is fictional and safe for demonstration purposes only.**

## What's Included

### Dockets (10 total)
- DK-2025-001: Drug possession with 2 related cases
- DK-2025-002: Retail theft (Pending)
- DK-2025-003: VAWC case (For Review)
- DK-2025-004: Estafa/Fraud (Pending)
- DK-2025-005: Cybercrime harassment (Dismissed)
- DK-2025-006: Malicious mischief (Filed)
- DK-2025-007: Robbery (For Review)
- DK-2025-008: Simple assault (Pending)
- DK-2025-009: Trespass with 2 related cases (Filed)
- DK-2025-010: Illegal firearm possession (Dismissed)

### Records
- **22 Persons** (complainants, respondents, witnesses)
- **24 Cases** (multiple cases under single dockets)
- **12 Violations** (different statutory charges)
- **Aliases** (3-7 per person)
- **Addresses** (1-2 per person)
- **Case Participants** (proper roles assigned)
- **Prosecutor Assignments** (5 prosecutors)
- **Case Status Updates** (timeline per case)
- **Attachments** (metadata only, no files)
- **Clearance Searches** (3 examples with matches)
- **Audit Logs** (action tracking)
- **Extraction Drafts** (AI form extraction samples)

## How to Load the Seed Data

### Option 1: Using Supabase SQL Editor (Recommended)

1. Go to Supabase Dashboard → Your Project
2. Click "SQL Editor" in the left sidebar
3. Click "New Query"
4. Copy the entire contents of `/supabase/seed.sql`
5. Paste into the SQL editor
6. Click "Run"
7. Verify all records inserted successfully

### Option 2: Using Supabase CLI

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Reset database (careful - this deletes all data)
supabase db reset

# Or run seed manually
psql -h your-host -U postgres -d postgres -f supabase/seed.sql
```

### Option 3: PostgreSQL Client

```bash
psql -h your-supabase-host -U postgres -f supabase/seed.sql
```

## Verifying the Data

After loading seed data, verify in Supabase:

1. **Dockets Table**: Should have 10 rows
   - Check docket_number column (DK-2025-001 through DK-2025-010)

2. **Cases Table**: Should have 12 rows
   - Check case_number column (OCP-2025-001 through OCP-2025-012)

3. **Persons Table**: Should have 22 rows
   - Includes complainants, respondents, witnesses

4. **Case Participants Table**: Should have 20+ rows
   - Properly linked persons to cases with roles

5. **Violations Table**: Should have 12 rows
   - Different statute citations (RA, RPC articles)

6. **Clearance Searches**: Should have 3 rows
   - With matches and review decisions

7. **Sync Status**: Should have 1 row
   - System status indicating "connected"

## Seed Data Features

✓ **Realistic Philippine Context**
- Use actual statutes (RA 9165, RA 10175, RPC articles)
- Filipino locations (barangays, municipalities)
- Filipino names with common aliases

✓ **Complete Relationships**
- Every person linked to cases via participants
- Every case linked to violations
- Every docket assigned to prosecutor
- Proper complainant/respondent/witness roles

✓ **Case Status Variety**
- Pending: 3 dockets
- For Review: 3 dockets
- Filed in Court: 3 dockets
- Dismissed: 2 dockets

✓ **Multiple Cases Per Docket**
- Docket 1 has 2 cases
- Docket 9 has 2 cases
- Others have 1 case each

✓ **Audit Trail**
- Case status updates with timestamps
- Prosecution assignments with notes
- Audit logs for major actions

✓ **Clearance Search Examples**
- Exact matches
- Similar name matches
- Review decisions with notes

✓ **Local-First System Status**
- Sync status showing system connected
- Offline readiness flag

## Important Notes

1. **No Authentication Required Yet**
   - Seed data uses public anon key
   - No RLS policies enabled
   - All records visible to all roles

2. **No File Attachments**
   - Attachments table contains metadata only
   - File_name and file_size fields populated
   - Actual file storage not implemented

3. **Dummy Data Safe**
   - All names are fictional
   - No real OCP records
   - Safe for demonstration and testing

4. **Ready for Backend Integration**
   - All tables follow production schema
   - Foreign keys properly configured
   - Indexes ready for optimization

## Using Seed Data in Your UI

Once seeded, your UI can query:

```typescript
// Example query in your service
const { data, error } = await supabase
  .from('docket_list_view')
  .select('*')
  .order('date_received', { ascending: false });
```

The views `docket_list_view` and `case_list_view` make displaying data easier.

## Resetting the Database

If you need to start over:

```bash
# Via Supabase Dashboard
1. Go to Project Settings
2. Click "Database" in left sidebar
3. Scroll down to "Danger Zone"
4. Click "Reset database"
5. Re-run the seed.sql file

# Or via SQL
TRUNCATE TABLE dockets CASCADE;
-- Then reload seed.sql
```

## Next Steps

1. ✓ Load seed data (this guide)
2. Create Supabase service for read queries
3. Connect Dashboard component to database
4. Connect Docket Search component
5. Connect Case Details component
6. Connect Clearance Search component
7. Add loading/empty states
8. Plan write operations (after read works)

## Support

- Seed data structure follows Supabase schema exactly
- All references/foreign keys properly configured
- Ready to connect to UI components
- Comments in seed.sql explain each section

