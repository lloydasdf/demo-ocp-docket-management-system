# Case Details Page Enhancements

## Overview

The Case Details page has been redesigned to clearly show the relationship between dockets and cases, with each case having independent status and details.

## Key Improvements

### 1. Hierarchical Structure - Docket Level

**Before:** Page showed a single case with references to the docket
**After:** Page prominently displays docket information with all cases underneath

```
┌─────────────────────────────────────────────────────┐
│ DOCKET: DK-2025-001                                 │
│ Multiple cases involving Carlos Rene Santos         │
│                                          [Filed]    │ ← DOCKET STATUS
├─────────────────────────────────────────────────────┤
│ Created | Total Cases | Status Breakdown | Prosecutors
├─────────────────────────────────────────────────────┤
│ 1/15/25 | 2 cases    | 1 Filed, 1 Pending | 1 assigned
└─────────────────────────────────────────────────────┘
```

**Benefits:**
- Clear visual hierarchy
- Immediate view of docket scope
- Status applies to entire docket collection

### 2. Multiple Cases Display

**New Section: "Cases Under This Docket"**

Each case shows:
- **Case Number** (e.g., OCP-2025-001)
- **Individual Case Status** - NOT the docket status
- **Date of Incident**
- **Violation Count**
- **Assigned Prosecutor**

```
┌──────────────────────────────────────────────────┐
│ OCP-2025-001  [Filed] ◄─── CASE-LEVEL STATUS   │
│ Incident: 1/15/2025                             │
│ Violations: 1 | Prosecutor: Maria Santos        │
├──────────────────────────────────────────────────┤
│ OCP-2025-011  [Pending] ◄── DIFFERENT STATUS   │
│ Incident: 2/1/2025                              │
│ Violations: 1 | Prosecutor: Unassigned          │
└──────────────────────────────────────────────────┘
```

**Key Feature:** Each case can have a DIFFERENT status from the docket and from other cases.

### 3. Case-Level Status Separation

**Critical Distinction:**
- **Docket Status** (top of page): DK-2025-001 = **Filed**
- **Case Statuses** (in cards): OCP-2025-001 = **Filed**, OCP-2025-011 = **Pending**

This clearly shows:
- Cases progress independently
- A docket can contain cases at different stages
- Each case maintains its own history

### 4. Interactive Case Selection

When a case is selected:
1. The case card highlights with a blue border
2. A "Case Details" card appears showing case-specific information
3. Tabs become available with detailed information:
   - Overview
   - Parties (Complainants, Respondents, Witnesses)
   - Violations
   - History (Status timeline)
   - Attachments
   - Summary

### 5. Professional Government Aesthetic

**Visual Improvements:**
- Navy blue headers for docket sections
- Status badges with government-standard colors:
  - Amber = Pending
  - Navy Blue = Filed
  - Gray = Dismissed
  - Green = Resolved
  - Orange = RFI
- Clear typography hierarchy
- Proper spacing and alignment

### 6. Updated Navigation

**Docket Search → Case Details Flow:**
```
Docket Search Page
    ↓
[View Cases (2)] button
    ↓
Case Details Page
    ├─ Shows Docket: DK-2025-001
    ├─ Shows Cases Under Docket
    │  ├─ OCP-2025-001 [Filed]
    │  └─ OCP-2025-011 [Pending]
    └─ Click any case to view details in tabs
```

## Data Structure

### Docket
```
{
  id: "docket-1",
  docketNumber: "DK-2025-001",
  createdDate: "2025-01-15",
  cases: [Case1, Case2],  // ← MULTIPLE CASES
  status: "Filed",
  description: "..."
}
```

### Case (within Docket)
```
{
  id: "case-1",
  caseNumber: "OCP-2025-001",
  dateOfIncident: "2025-01-15",
  status: "Filed",           // ← INDEPENDENT STATUS
  prosecutor: "Maria Santos",
  violations: [...],
  statusHistory: [...]
}
```

## User Workflow

### Scenario: Review all cases in a docket

1. User goes to Docket Search
2. User searches or browses for docket DK-2025-001
3. User clicks "View Cases (2)"
4. Case Details page loads showing:
   - Docket header with filing status
   - 2 cases with different individual statuses
   - Quick stats: 1 filed, 1 pending, 1 prosecutor
5. User clicks on OCP-2025-011 (pending case)
6. Details appear showing:
   - Date: 2/1/2025
   - Prosecutor: Unassigned
   - Violations: 1
   - Tabs show full information
7. User can switch between cases by clicking different cards

### Scenario: Track case progression

1. User navigates to case in docket
2. Clicks "History" tab
3. Sees timeline:
   - Received (1/15)
   - Filed (1/25)
   - Status remarks and who updated
4. Another case in same docket may have different history
5. Clear audit trail per case

## Technical Implementation

### Component Changes
- **case-details.tsx**: Completely redesigned
  - Now takes only `docketId` (not `caseId`)
  - Shows all cases under docket
  - Optional `caseId` for direct case selection
  - Conditional rendering of tabs (only when case selected)

### Page Route
- **app/case-details/page.tsx**: Fixed Suspense boundary
  - Required for Next.js 16 with `useSearchParams()`
  - Wraps search params hook properly

### URL Parameters
```
/case-details?docketId=docket-1              # Shows docket + all cases
/case-details?docketId=docket-1&caseId=case-1 # Highlights specific case
```

### Styling
- Border highlighting for selected case
- Professional grid layouts
- Status badge color system
- Clear typography hierarchy
- Proper whitespace and padding

## Benefits for Staff

### 1. Complete Picture
- See entire docket at once
- Understand all related cases
- No need to navigate between pages

### 2. Status Clarity
- Docket status vs. case status clearly separated
- Each case progresses independently
- No confusion about where cases stand

### 3. Efficient Navigation
- Click to switch between cases
- No page reloads
- Tab system keeps context

### 4. Professional Look
- Government-standard aesthetics
- Clear information hierarchy
- Easy on the eyes during long research sessions

### 5. Complete Information
- All parties, violations, history in one place
- No information scattered across pages
- Single source of truth per case

## Future Enhancements

Possible additions:
- Bulk actions (reassign prosecutor, update multiple cases)
- Export case summary as PDF
- Print-friendly view
- Case comparison mode
- Status update form inline
- Document upload from details page

## Testing

### Test Cases to Try

1. **View Docket with Multiple Cases**
   - Go to Docket Search
   - Click any "View Cases" button
   - Verify all cases show under docket
   - Verify each case has its own status

2. **Case Selection**
   - Click different case cards
   - Verify case details update
   - Verify tabs show correct case data

3. **Status Independence**
   - Look at docket status (top)
   - Look at case statuses (in cards)
   - Verify they can differ

4. **Navigation**
   - Try switching between cases
   - Try clicking History tab
   - Try viewing different parties per case

5. **Visual Design**
   - Check color coding matches status
   - Verify all text is readable
   - Check responsive layout on mobile
