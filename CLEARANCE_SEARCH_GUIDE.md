# Clearance Search - User Guide

## Overview
The Clearance Search is the primary feature for locating individuals across all docket records. It uses advanced fuzzy matching to find exact matches, aliases, and similar names with confidence scoring.

---

## Search Examples

### Example 1: Exact Name Search
**Search Query**: `Carlos Santos`

**Results**:
- **Match Type**: Exact Match (100%)
- **Confidence**: 100%
- **Records Found**: 2 related cases under one docket
  - OCP-2025-001 (Drug dealing case)
  - OCP-2025-011 (Theft case)
- **Aliases on File**: "CR Santos", "Carlos R. Santos", "Carlito Santos", "Charles Santos", "C.R. Santos", "Carl Santos"
- **Status**: Both cases filed
- **Cases Count**: 2 related matters

**Why This Works**: Exact string match in full name database returns 100% confidence.

---

### Example 2: Alias Search (Nickname)
**Search Query**: `Carlito`

**Results**:
- **Match Type**: Alias Match
- **Confidence**: 95%+
- **Records Found**: Same Carlos Santos cases via alias "Carlito Santos"
- **Display**: Alias match highlighted showing where the match was found
- **Interpretation**: System found the person through a known alias

**Why This Works**: "Carlito" is registered as an alias for Carlos Rene Santos, providing high-confidence identification.

---

### Example 3: Partial Name Search
**Search Query**: `Carl`

**Results**:
- **Match Type**: Similar/Fuzzy Match
- **Confidence**: 80%+ (High Confidence)
- **Records Found**: 
  - Carlos Santos (multiple aliases match: "Carl Santos", "Carlito")
  - Possibly Rosa Fernandez or other partial matches
- **Display**: Grouped in "High Confidence" section (blue-bordered)

**Why This Works**: "Carl" is a substring of "Carlos" and exact alias "Carl Santos", providing 80%+ confidence.

---

### Example 4: Fuzzy Name Variation
**Search Query**: `Maria Garcia`

**Results**:
- **Match Type**: Exact Match or High Confidence
- **Confidence**: 90-100%
- **Records Found**: Maria Luz Garcia with cases as:
  - Complainant (multiple cases)
  - Respondent (OCP-2025-005)
  - Witness (OCP-2025-004, OCP-2025-009)
- **Aliases**: "Maria L. Garcia", "M. Luz Garcia", "Mary Garcia", "Maria Garcia-Santos", "Maria Luz Reyes"
- **Note**: Shows person involved in multiple roles

**Why This Works**: Exact name match plus multiple registered aliases provide high confidence.

---

### Example 5: Similar Names with Low Confidence
**Search Query**: `Maria`

**Results**:
- **Match Type**: Similar/Fuzzy Match
- **Confidence**: 60-79% (Medium Confidence)
- **Records Found**: 
  - Maria Luz Garcia (from name)
  - Other partial matches
- **Display**: Grouped in "Medium Confidence" section (amber-bordered)
- **Action**: Click "Review" to manually verify

**Why This Works**: Single name provides multiple potential matches, reducing automatic confidence.

---

### Example 6: Related Cases Search
**Search Query**: `Santos`

**Results**:
- **Match Type**: Similar Match
- **Confidence**: 70-90% (High to Medium)
- **Records Found**: Multiple Santas cases:
  - Carlos (Rene) Santos: 2 cases
  - Rosa Fernandez (maiden name context)
  - Maria Garcia-Santos (possible married name)
- **Display**: Shows related cases count for each person

**Why This Works**: Common surname returns multiple matches; confidence based on full string matching.

---

## Confidence Levels Explained

### Exact Match (100%)
- **Description**: Exact match to a known name or registered alias
- **Color**: Blue background, bold typography
- **Action**: "Verify Record" button prominently displayed
- **Examples**: "Carlos Santos", "Carlito Santos" (his alias)

### High Confidence (80-99%)
- **Description**: Strong match through substring or character sequence
- **Color**: Green background
- **Action**: "Verify" button available
- **Examples**: "Carl" matches "Carlos", partial aliases match

### Medium Confidence (60-79%)
- **Description**: Weak match requiring human review
- **Color**: Amber background
- **Action**: "Review" button for manual verification
- **Examples**: Single name searches, partial phone numbers

---

## How Match Types Work

### Exact Match Algorithm
```
IF (searchText == fullName) → 100% confidence
IF (fullName.contains(searchText)) → 95% confidence
```

### Alias Matching Algorithm
```
FOR each registered alias:
  IF (searchText == alias) → 95-100% confidence
  IF (alias.contains(searchText)) → 80-90% confidence
```

### Fuzzy Matching Algorithm
```
Calculate character position scoring:
- Find each letter of search term in target text
- Score based on how closely letters appear
- Result: 60-79% confidence for partial matches
```

---

## Using the Verification Panel

### When to Verify
After finding a record, click "Verify Record" or "Review" to:
1. Confirm the identity matches your investigation
2. Document the search and result
3. Create an audit trail
4. Record findings in official docket system

### Verification Form Fields
- **Subject Name**: Pre-filled with found person
- **Confidence**: Shows the match confidence percentage
- **Docket Number**: Reference for case tracking
- **Case Status**: Current status of related cases
- **Verification Notes**: Your findings and confirmations

### Recording Results
Click "Confirm & Record" to:
- Add to session verification list
- Create audit timestamp
- Save notes for official record
- Enable export for reports

---

## Tips for Effective Searching

### Best Practices
1. **Start with Full Name**: "Carlos Santos" is more reliable than "Carlos"
2. **Try Variations**: If unsure, search for:
   - Full name
   - First name only
   - Last name only
   - Known aliases
3. **Use Confidence Levels**: 
   - Exact matches (blue) = instant verification
   - High matches (green) = likely correct with quick review
   - Medium matches (amber) = verify before confirming
4. **Review Multiple Cases**: Notice when one person has multiple related cases
5. **Document Everything**: Use verification notes to record findings

### Common Searches
| Purpose | Search Query | Expected Result |
|---------|--------------|-----------------|
| Verify known person | "Carlos Santos" | Exact match, 100% |
| Find by nickname | "Carlito" | Alias match, 95%+ |
| Broad search | "Santos" | Multiple high-confidence |
| Investigate variation | "Carl S" | Fuzzy match, 80%+ |
| Verify witness | "Maria Garcia" | Exact match in roles |

---

## Related Cases Under One Person

### Example: Carlos Rene Santos
When searching for Carlos Santos, the system shows:
- **Respondent in**: OCP-2025-001 (Drug dealing)
- **Respondent in**: OCP-2025-011 (Theft)
- **Under Same Docket**: DK-2025-001
- **Related Cases Count**: 2 displayed with full details

### Why This Matters
- Investigate pattern of behavior
- See connections between cases
- Track repeat offenders
- Identify relationships/accomplices

---

## Troubleshooting

### No Results Found
- Try shorter/simpler name
- Check spelling of aliases
- Try first or last name separately
- Search for related persons

### Too Many Results
- Be more specific (use full name)
- Use exact aliases when known
- Review confidence levels
- Filter by case status if possible

### Unsure About Match
- Use "Review" button on medium-confidence results
- Check docket and case numbers
- Compare addresses and phone numbers
- Verify through multiple search methods

---

## Privacy & Security Notes

- All searches are logged for audit purposes
- Verification records include timestamp and user
- Records are secured within official docket system
- Access follows role-based permissions
- Export reports follow government procedures

---

## Quick Reference

**Feature**: Clearance Record Search
**Location**: Main navigation (#2 in sidebar)
**Purpose**: Locate individuals by name, alias, or variation
**Search Types**: Exact, Alias, Fuzzy Matching
**Confidence Range**: 60%-100%
**Actions**: Verify, Review, Record
**Integration**: Official docket system records
