# AI-Assisted Form Extraction Feature

## Overview
The New Docket Entry page now includes an AI-assisted form extraction mode that allows staff to upload scanned investigation forms, images, or PDFs to automatically extract docket information.

## Entry Modes

### 1. Manual Entry (Default)
- Traditional form-filling approach
- Complete control over all fields
- Suitable for digital/typed documents
- No extraction required

### 2. Scan / Upload Mode (New)
- Upload scanned forms, images, or PDFs
- Automatic OCR/data extraction simulation
- Confidence-based field extraction
- AI-assisted but requires staff review

---

## Form Extraction Workflow

### Step 1: Upload Form
- Click on the upload area or drag and drop
- Supported formats: PDF, JPG, PNG, GIF
- Max file size: 25MB
- File name is tracked for audit trail

### Step 2: Extract Data
- Click "Extract Form Data" button
- System processes the uploaded form
- Returns extracted fields with confidence levels

### Step 3: Review Extracted Data
The extracted data is displayed in multiple tabs:

#### Extracted Data Tab
- All extracted fields are displayed and editable
- Each field shows a confidence indicator:
  - **High Confidence** (Green): 95%+ accuracy, minimal review needed
  - **Needs Review** (Amber): 60-85% accuracy, verify carefully
  - **Missing** (Red): Could not be extracted, manual input required

#### Form Preview Tab
- Shows placeholder for uploaded form
- In production: displays the actual scanned image
- Allows visual cross-reference with extracted data

#### Missing Fields Tab
- Lists all fields that couldn't be extracted
- Provides input area to manually add missing data
- Shows which fields are required for submission

#### Duplicates Tab
- **Possible Duplicate Persons**: Shows similar names found in existing records
  - Lists matching dockets
  - Shows similarity percentage
  - Helps prevent duplicate entries

- **Possible Duplicate Dockets**: Shows similar dockets
  - Helps identify related cases
  - Prevents duplicate docket creation

### Step 4: Make Corrections
- All extracted fields are fully editable
- Click on any field to modify the value
- Changes are temporary until confirmed
- No auto-save (prevents accidental overwrites)

### Step 5: Add Review Notes
- Provide context about the extraction
- Examples:
  - "Form quality was poor, manual verification done"
  - "Contacted complainant for missing address"
  - "Handwritten portions were unclear"
- Notes are stored for compliance/audit purposes

### Step 6: Finalize Entry
Three action buttons:

1. **Save as Draft**
   - Saves extraction with all edits to draft folder
   - Can be resumed later
   - No docket entry created yet

2. **Review Missing Fields**
   - Jumps to Missing Fields tab
   - Shows count of fields still missing
   - Required before creating entry

3. **Confirm and Create Docket Entry**
   - Enabled only when all required fields are filled
   - Creates the docket entry
   - Stores review notes with the entry
   - Returns to manual mode

---

## Extracted Fields

The system extracts the following fields from investigation forms:

### Docket Information
- Docket Number
- Date Received

### Complainant Information
- Complainant Name
- Complainant Aliases / AKA

### Respondent Information
- Respondent Name
- Respondent Aliases / AKA
- Respondent Age
- Respondent Birth Date

### Address Information
- Residential Address
- Office Address

### Violation Information
- Violation / Statute (e.g., RA 9165)
- Place of Commission

### Case Information
- Prosecutor Assignment (if listed on form)
- Remarks

---

## Confidence Levels Explained

### High Confidence (95-100%)
- Clear, well-printed text
- Unambiguous data
- No corrections needed
- Example: "Maria Garcia" clearly printed in complainant field

### Needs Review (60-85%)
- Partially legible text
- Possible OCR errors
- Handwritten portions
- Abbreviations that might be unclear
- Example: "M. Garcia" - could expand to multiple names
- Example: "[UNCLEAR TEXT]" - OCR uncertain

### Missing (0-59%)
- Field is blank or illegible on form
- OCR completely failed
- Handwritten text too unclear
- Example: Blank birth date field
- Example: "[ILLEGIBLE HANDWRITING]"

---

## Duplicate Detection

### Person Matching
- Fuzzy matching algorithm simulates finding similar names
- Shows similarity percentage (0-100%)
- Lists which docket the person appears in
- **Action**: Review to prevent duplicate records of same person

### Docket Matching
- Identifies potentially related dockets
- Shows similarity score
- **Action**: Review to see if should add case to existing docket vs. creating new docket

---

## Important UX Principles

### Non-Destructive Workflow
- ✅ All changes are temporary
- ✅ No auto-save to prevent accidents
- ✅ Must explicitly click "Confirm" to create entry
- ✅ Can save as draft and resume later

### Clear Warning
"Extracted data must be reviewed by staff before saving."
- Displayed prominently at top of extraction results
- Reminds staff that extraction is not 100% accurate
- Requires conscious decision to proceed

### Audit Trail
- Source file name stored
- Extraction timestamp recorded
- Staff review notes preserved
- All edits tracked (in production)

---

## Dummy Behavior

This is a dummy implementation simulating real AI/OCR extraction. The feature includes:

1. **Three extraction profiles**: High quality, mixed quality, poor quality
   - Randomly selected to simulate different form conditions
   - Shows realistic confidence variations

2. **Realistic field values**: Philippine-specific data
   - Statute names (RA 9165, RA 10175, VAWC, etc.)
   - Local place names (barangays, municipalities)
   - Realistic names and addresses

3. **Confidence distribution**:
   - Mix of high, review, and missing fields
   - Simulates real-world extraction challenges

4. **Duplicate matching**: Sample data
   - Shows how person/docket matching would work
   - Provides actionable results

---

## Workflow Examples

### Example 1: High-Quality Scanned Form
```
User uploads clear PDF of typed investigation form
↓
System extracts 12 of 13 fields with high confidence
↓
User reviews one "Needs Review" field (Prosecutor name)
↓
User corrects prosecutor name
↓
User adds optional review notes
↓
User clicks "Confirm and Create Docket Entry"
↓
Docket entry created successfully
```

### Example 2: Poor Quality Handwritten Form
```
User uploads grainy image of handwritten form
↓
System extracts 5 fields clearly, 4 fields with uncertainty, 4 fields missing
↓
User reviews and corrects "Needs Review" fields
↓
User manually fills in 4 missing fields
↓
System warns: "4 missing fields still - fill to proceed"
↓
User completes missing fields
↓
User adds notes: "Form was handwritten and unclear - manually verified with complainant"
↓
User clicks "Confirm and Create Docket Entry"
↓
Docket entry created with staff review notes
```

### Example 3: Save as Draft
```
User uploads form with multiple missing fields
↓
System extracts partial data
↓
User reviews and corrects available fields
↓
User clicks "Save as Draft"
↓
System saves extraction state to draft folder
↓
User navigates away
↓
Later: User resumes from Draft
↓
User fills in remaining fields
↓
User confirms to create entry
```

---

## Technical Details

### Files
- `/lib/form-extraction.ts`: Core extraction logic and dummy data
- `/components/extraction-mode.tsx`: UI component for extraction workflow
- `/components/pages/new-docket.tsx`: Updated with mode selector

### Key Features Implemented
1. ✅ Mode selector UI (Manual vs. Scan)
2. ✅ File upload area with drag-and-drop
3. ✅ Dummy extraction with 3 quality profiles
4. ✅ Confidence indicators (High/Review/Missing)
5. ✅ Editable extracted fields
6. ✅ Side-by-side layout (form preview + extracted data)
7. ✅ Duplicate person/docket detection
8. ✅ Staff review notes section
9. ✅ Draft saving capability
10. ✅ Comprehensive warnings about data accuracy

### Not Implemented (Dummy Only)
- ❌ Real OCR/image processing
- ❌ Real AI extraction
- ❌ Actual file storage
- ❌ Real duplicate checking against database
- ❌ Form preview (placeholder only)

---

## Testing the Feature

1. Go to "New Docket Entry" page
2. Click "Scan / Upload" mode
3. Click upload area (you don't need to actually upload a file - the component accepts the interaction)
4. Click "Extract Form Data"
5. Review the extracted fields with confidence indicators
6. Edit fields as needed
7. Check "Missing Fields" and "Duplicates" tabs
8. Add review notes
9. Click "Confirm and Create Docket Entry"
10. Success message appears, mode switches back to manual

---

## Compliance & Audit Trail

The extraction feature includes several compliance features:

- **Source File Tracking**: Original file name stored
- **Extraction Timestamp**: When extraction occurred
- **Confidence Recording**: Which fields had issues
- **Staff Notes**: Why decisions were made
- **No Auto-Save**: Requires explicit confirmation

These features support:
- ✅ Government record accuracy requirements
- ✅ Audit trails for investigations
- ✅ Accountability for data entry
- ✅ Quality assurance processes

---

## Future Enhancements (Not Included)

For a production system, consider adding:
1. Real OCR/image processing libraries
2. ML-based entity extraction
3. Database integration for duplicate checking
4. Real file storage (Vercel Blob or similar)
5. Extraction history and drafts management
6. Multi-language support
7. Form type detection (different form templates)
8. Batch processing for multiple forms
9. Real confidence scoring based on ML models
10. Integration with complainant verification
