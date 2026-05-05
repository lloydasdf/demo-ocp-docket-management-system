# Case Details Page - User Guide

## Overview

The enhanced Case Details page displays a complete view of a docket and all its associated cases. This guide explains the new hierarchical structure and how to navigate between docket-level and case-level information.

## Page Structure

### 1. Docket Header Section

The top section shows **docket-level information** that applies to all cases within the docket:

```
┌─────────────────────────────────────────────┐
│ DOCKET: DK-2025-001                         │
│                                             │
│ Multiple cases involving Carlos Rene Santos │
│ - Drug and theft charges                    │
│                                             │
│                    Status: Filed ◄────────  │ ← DOCKET STATUS
└─────────────────────────────────────────────┘
```

**Key Information:**
- **Docket Number**: Unique identifier for the docket (e.g., DK-2025-001)
- **Docket Description**: Summary of what the docket covers
- **Docket Status**: Overall status affecting all cases (Filed, Pending, Resolved, etc.)
- **Created Date**: When the docket was created

### 2. Docket Overview Grid

Below the header are four quick-reference cards:

| Card | Shows |
|------|-------|
| Created | Date the docket was created |
| Total Cases | Number of cases in this docket |
| Status Breakdown | Visual count of cases by status |
| Prosecutors | Number of unique prosecutors assigned |

### 3. Cases Under This Docket (NEW)

This **prominent section** shows all cases filed under the docket with individual statuses:

```
CASES UNDER THIS DOCKET
────────────────────────────────────────────────────────
│ OCP-2025-001  [Filed]                                │
│ Incident: 1/15/2025                                  │
│ Violations: 1 | Prosecutor: Maria Santos             │
├────────────────────────────────────────────────────────┤
│ OCP-2025-011  [Pending]                              │
│ Incident: 2/1/2025                                   │
│ Violations: 1 | Prosecutor: Unassigned               │
└────────────────────────────────────────────────────────┘
```

**Key Features:**
- **Individual Case Status Badges**: Each case shows its own status (Filed, Pending, Dismissed, Resolved, RFI)
- **Case-Level Details**: Date of incident, violation count, assigned prosecutor
- **Visual Highlighting**: Selected case is highlighted with a blue border
- **Separate from Docket Status**: Note that Case OCP-2025-001 is "Filed" while Case OCP-2025-011 is "Pending" - they can have different statuses within the same docket

### 4. Case Details Card

When you click on a case in the list above, this card appears showing:
- Case Number
- Case Status (separate from docket status)
- Date of Incident
- Assigned Prosecutor
- Number of Violations

### 5. Detailed Tabs (When Case Selected)

Once a case is selected, you can view detailed information:

**Overview Tab**
- Case Number, Status, Date of Incident, Prosecutor
- Complainants, Respondents, Witnesses counts

**Parties Tab**
- Detailed information for each complainant, respondent, and witness
- Contact information and aliases

**Violations Tab**
- List of all violations in this case
- For each violation: description, statute, date committed, location, details

**History Tab**
- Timeline of status changes for this case
- Shows who made each update and when
- Visual timeline indicator

**Attachments Tab**
- Files uploaded for this case
- File details: size, upload date, uploaded by
- Download buttons

**Summary Tab**
- Complete case overview
- All key information in one place

## Understanding the Status Hierarchy

### Docket Status
- Applies to the **entire docket**
- Shows the overall state of all cases combined
- Example: Docket might be "Filed" but still contain pending cases

### Case Status
- Individual status for **each case**
- Can differ from docket status
- Each case progresses independently

### Possible Status Values

| Status | Color | Meaning |
|--------|-------|---------|
| Pending | Amber | Under review, awaiting action |
| Filed | Navy Blue | Formally filed in court |
| Dismissed | Gray | Case dismissed by prosecutor |
| Resolved | Green | Case resolved/concluded |
| RFI | Orange | Request for Investigation pending |

## Example Scenario

**Docket: DK-2025-001** (Docket Status: **Filed**)
```
├─ Case OCP-2025-001
│  └─ Status: Filed ✓ (Prosecution proceeding)
│
└─ Case OCP-2025-011
   └─ Status: Pending ⏳ (Still under investigation)
```

In this example:
- The **docket overall is filed** because the primary case was filed
- But the **second case is still pending**, showing independent case progression
- Both are visible in one docket view, making it easy to see the complete picture

## How to Use

### To View a Docket with Multiple Cases

1. Navigate to Cases page or Docket Search
2. Click on a docket (they all have multiple cases)
3. You'll see the docket header with status
4. Below, you'll see all cases under that docket

### To View Detailed Information for a Specific Case

1. On the Case Details page, find the case in the "Cases Under This Docket" section
2. Click on the case card (it will highlight in blue)
3. The "Case Details" card below will show case-specific information
4. Click on tabs to see different aspects of that case

### To Compare Cases in Same Docket

1. View the docket
2. Notice how each case has its own status badge
3. Review the Status Breakdown card to see distribution (e.g., "1 Filed, 1 Pending")
4. Click between different cases to compare their details

## Key Distinctions

| Aspect | Docket Level | Case Level |
|--------|-------------|-----------|
| Unique ID | DK-2025-001 | OCP-2025-001, OCP-2025-011 |
| Status | One per docket | One per case |
| Cases | Multiple | One |
| Prosecutors | Multiple possible | One assigned per case |
| Violations | Combined | Per case |
| Details View | Overview grid | Full tabs + details |

## Tips

1. **Color-coded badges** - Quickly scan status by color
2. **Cases grid** - Shows all cases at a glance, no need to navigate away
3. **Separate statuses** - Each case progresses independently
4. **Prosecutor tracking** - See who's handling each case
5. **Timeline view** - History tab shows complete audit trail per case

## Accessing Case Details

You can reach the case details page by:
1. **Docket Search** - Click a docket to view all its cases
2. **Cases Listing** - Select a docket to see its cases
3. **Direct URL** - `/case-details?docketId=docket-1&caseId=case-1`
