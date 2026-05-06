# Seed Data Quick Start

## 30-Second Setup

1. **Copy seed data**
   ```
   supabase/seed.sql
   ```

2. **Load into Supabase**
   - Go to Supabase Dashboard → SQL Editor
   - Create New Query
   - Paste entire seed.sql
   - Click Run

3. **Verify**
   - Check Dockets table: 10 rows
   - Check Cases table: 12 rows
   - Check Persons table: 22 rows

**Done! Your UI now has realistic demo data.**

## What You Get

### 10 Realistic Dockets
- Drug possession case (with 2 linked cases)
- Retail theft
- Violence against women and children (VAWC)
- Fraud/Estafa
- Cybercrime harassment
- Malicious mischief
- Robbery
- Simple assault
- Trespass with property damage (2 linked cases)
- Illegal firearm possession

### Complete Records
- 22 fictional persons (no real names)
- 12 different violation types
- Multiple case statuses (Pending, Filed, Dismissed, For Review)
- Full audit trails
- Clearance search examples
- Prosecutor assignments

### All Relationships Working
- Persons linked to cases
- Cases linked to violations
- Dockets assigned to prosecutors
- Complete role assignments (complainant, respondent, witness)
- Status update history

## Important Notes

✓ **Safe Demo Data**
- No real OCP records
- All fictional names
- Ready for government office use

✓ **Production Ready**
- Proper schema relationships
- All foreign keys configured
- Indexes ready for optimization

✓ **Backend Integration Ready**
- Structure matches PostgreSQL schema
- Ready to connect to UI components
- Easy to replace with real data later

## Next Step

Connect your UI to Supabase:
1. Create services in `lib/supabase-services.ts`
2. Update Dashboard component to use `getDockets()`
3. Update Docket Search to use database view
4. Update Case Details to fetch related records
5. Add loading/error states

## File Locations

- **SQL Seed**: `/supabase/seed.sql`
- **Reference Guide**: `SEED_DATA_REFERENCE.md`
- **Setup Instructions**: `SUPABASE_SEEDING_INSTRUCTIONS.md`
- **This Guide**: `SEED_DATA_QUICKSTART.md`

---

**Ready to go! Load the seed.sql and your app has demo data.**
