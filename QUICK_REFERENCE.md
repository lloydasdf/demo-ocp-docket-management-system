# OCP Docket System - Quick Reference

## Key Concepts

### Docket vs. Case

| | Docket | Case |
|---|--------|------|
| **ID Format** | DK-2025-001 | OCP-2025-001 |
| **Purpose** | Groups related cases | Individual legal matter |
| **Status** | One per docket | Independent per case |
| **Cases** | Can have many | One case |
| **Example** | "All cases involving Carlos Santos" | "Drug possession charge" |

### Status Colors & Meanings

| Color | Status | Meaning |
|-------|--------|---------|
| 🟨 Amber | Pending | Under investigation, awaiting action |
| 🔵 Navy | Filed | Formally filed in court, prosecution ongoing |
| 🔘 Gray | Dismissed | Case dismissed by prosecutor |
| 🟢 Green | Resolved | Case concluded/resolved |
| 🟠 Orange | RFI | Request for Investigation pending |

## How to Use the System

### Access Case Details
1. **Docket Search** → Search/browse dockets → Click "View Cases (2)" button
2. **Cases** → Select a docket from the list
3. **Direct URL** → `/case-details?docketId=docket-id`

### View All Cases Under a Docket
- Go to Case Details page
- Scroll to "Cases Under This Docket" section
- Each card shows one case with its status
- Cases can have DIFFERENT statuses

### Get Details for a Specific Case
- Click on a case card in the list
- Case details appear below
- Use tabs to view:
  - Overview → Key information
  - Parties → Complainants, respondents, witnesses
  - Violations → Charges/violations
  - History → Timeline of updates
  - Attachments → Documents
  - Summary → Complete case info

### Find Cases in Docket
**Question:** "Are there any other cases involving Carlos Santos?"
**Answer:** Look at Docket DK-2025-001 → See all related cases in one view

### Understand Status
**Question:** "Why is the docket status 'Filed' but this case shows 'Pending'?"
**Answer:** Docket status = overall progress. Individual cases progress independently.

## Common Tasks

### Search for Specific Case
1. Go to **Docket Search**
2. Type case number in search box (e.g., OCP-2025-001)
3. Click "View Cases" to see full details

### Check Case History
1. Go to Case Details page
2. Click the case card
3. Click **History** tab
4. See timeline of all status changes

### Find All Cases by Prosecutor
1. Go to Case Details page
2. Look at "Cases Under This Docket"
3. Check "Prosecutor" column for each case
4. Or use Search/Filter by prosecutor name

### Understand Why Case Status Changed
1. Go to Case Details
2. Click case card
3. Click **History** tab
4. View status updates and remarks
5. See who made each update and when

### Find All Violations for a Case
1. Go to Case Details
2. Click case card
3. Click **Violations** tab
4. See all charges with statute, location, details

## Navigation Quick Links

| Page | Purpose | Access |
|------|---------|--------|
| **Dashboard** | KPIs and overview | Home icon in sidebar |
| **Clearance Search** | Find person by name/aliases | Featured in sidebar |
| **Docket Search** | Find dockets by number/status | Search icon in sidebar |
| **Case Details** | View all cases in docket | From Docket Search |
| **Cases** | Browse all cases | Cases icon in sidebar |
| **Prosecutor Assignment** | Assign prosecutor to case | Users icon in sidebar |
| **Status Update** | Update case status | Checkmark icon in sidebar |
| **Reports** | View analytics | Chart icon in sidebar |

## Important Distinctions

### Docket-Level Status
- Shown at **TOP** of Case Details page
- Applies to the **entire docket**
- Example: DK-2025-001 = "Filed"

### Case-Level Status
- Shown in **case cards** in the list
- Each case has **independent** status
- Example: OCP-2025-001 = "Filed", OCP-2025-011 = "Pending"

They can be **DIFFERENT** ✓

## Pro Tips

✓ **Compare cases** - Click between case cards to compare details
✓ **Check status history** - History tab shows complete audit trail
✓ **Multiple prosecutors** - Different cases in same docket can have different prosecutors assigned
✓ **Filter by status** - Use Docket Search status filter to find filed vs. pending dockets
✓ **Direct URL** - Bookmark case details URLs for quick access

## Keyboard Shortcuts (Coming Soon)

| Shortcut | Action |
|----------|--------|
| `Ctrl+F` | Search this page |
| `?` | Show help |

## Icons in Sidebar

| Icon | Page |
|------|------|
| 🏠 | Dashboard |
| 🔍 | Clearance Search (Featured) |
| 🔎 | Docket Search |
| 📄 | Case Details |
| 👥 | Prosecutor Assignment |
| ✓ | Status Update |
| 📊 | Reports |

## Getting Help

1. **For questions about a case:** Go to Case Details, click History tab
2. **For prosecutor assignments:** Go to Prosecutor Assignment page
3. **For status changes:** Check History tab, look at Status History timeline
4. **For missing information:** Check all tabs (Overview, Parties, Violations, etc.)

## Data Retention Notes

- All cases are stored with complete history
- Status changes are logged with timestamp and updater
- No data is deleted, only archived when resolved
- Use History tab to audit case progression

---

**Last Updated:** 2025-05-05
**System Version:** 1.1 (Enhanced Case Details)
