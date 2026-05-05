# Form Extraction Feature - Quick Start Guide

## 🚀 Accessing the Feature

**Page**: New Docket Entry (`/new-docket`)

## 📋 Two Entry Modes

### Mode 1: Manual Entry (Default)
- Fill out form fields manually
- Full control over every field
- Best for: Typed or digital documents

### Mode 2: Scan / Upload (New)
- Upload scanned forms or PDFs
- AI extracts fields automatically
- Staff reviews and confirms
- Best for: Paper forms and handwritten documents

---

## 🔄 Quick Workflow (Scan Mode)

```
1. Click "Scan / Upload" card
   ↓
2. Upload form image or PDF
   ↓
3. Click "Extract Form Data"
   ↓
4. Review extracted fields
   - High ✓ = Use as-is
   - Review ⚠️ = Check carefully
   - Missing ✗ = Fill manually
   ↓
5. Edit any field that needs correction
   ↓
6. Check "Duplicates" tab for conflicts
   ↓
7. Add review notes (optional)
   ↓
8. Click "Confirm and Create Docket Entry"
```

---

## 📊 Field Confidence Indicators

| Badge | Color | Meaning | Action |
|-------|-------|---------|--------|
| **High Confidence** | 🟢 | 95%+ accuracy | Use as-is |
| **Needs Review** | 🟡 | 60-85% accuracy | Verify and correct |
| **Missing** | 🔴 | Not found | Manually enter |

---

## 🎯 Extracted Fields (13 Total)

**Docket Section**
- Docket Number
- Date Received

**Complainant Section**
- Complainant Name
- Complainant Aliases/AKA

**Respondent Section**
- Respondent Name
- Respondent Aliases/AKA
- Age
- Birth Date

**Address Section**
- Residential Address
- Office Address

**Violation Section**
- Violation/Statute
- Place of Commission

**Case Section**
- Prosecutor Assignment
- Remarks

---

## 📑 Tabs Available

1. **Extracted Data** (Main Tab)
   - All fields are editable
   - Shows confidence for each field
   - Original text shown for review fields

2. **Form Preview**
   - Shows uploaded form
   - Compare extracted data with original

3. **Missing Fields**
   - Lists unfilled fields
   - Manual input area
   - Required before confirming

4. **Duplicates**
   - Similar persons in database
   - Similar dockets in system
   - Prevents duplicate records

---

## ✍️ Making Edits

✅ **Editable**
- Any extracted field
- Any missing field
- Review notes

✅ **Temporary**
- Changes not saved until confirmed
- Can save as draft

✅ **No Auto-Save**
- Must click button to create entry
- Prevents accidental overwrites

---

## 💾 Three Action Buttons

### 1. Save as Draft
- Saves current state
- Resume editing later
- No entry created yet

### 2. Review Missing Fields
- Jump to Missing Fields tab
- Shows count of unfilled required fields
- Must fill all before confirming

### 3. Confirm and Create Docket Entry
- ✅ Only enabled when all required fields filled
- Creates the docket entry
- Stores review notes
- Returns to manual mode

---

## ⚠️ Important Notes

> **"Extracted data must be reviewed by staff before saving."**

This message reminds you that:
- AI extraction is not 100% accurate
- Review all fields carefully
- Pay special attention to "Needs Review" fields
- Verify duplicate matches manually
- Save drafts if you need more time

---

## 🔍 Duplicate Detection

### Possible Duplicate Persons
- Shows similar names already in system
- Lists which docket they're in
- **Action**: Verify if it's the same person or someone new

Example:
```
Maria Garcia López    92% match    DK-2025-001
M. Garcia            87% match    DK-2025-015
```

### Possible Duplicate Dockets
- Shows related dockets in system
- **Action**: Check if case should be added to existing docket

Example:
```
DK-2025-002    78% similar
DK-2025-035    65% similar
```

---

## 📝 Review Notes Examples

Good notes to add:
- ✅ "Form was handwritten and unclear - manually verified addresses"
- ✅ "Scanned at low resolution - corrected respondent name"
- ✅ "Called complainant to confirm missing contact information"
- ✅ "Prosecutor not listed on form - will assign later"

---

## 🎬 Complete Example Workflow

### Scenario: Handwritten Form with Issues

**Step 1**: Click "Scan / Upload" → Form is uploaded

**Step 2**: Click "Extract Form Data"
```
Results:
High: 5 fields ✓
Needs Review: 5 fields ⚠️
Missing: 3 fields ✗
Overall: 38% confidence
```

**Step 3**: Review "Extracted Data" tab
- Complainant name is unclear → Correct it
- Respondent AKA has OCR error → Fix it
- Violation text is incomplete → Complete it

**Step 4**: Check "Missing Fields" tab
- Birth date: blank → Enter it
- Prosecutor: blank → Mark as TBA
- Remarks: blank → Enter any notes

**Step 5**: Check "Duplicates" tab
- Maria Garcia found → Review, it's different person

**Step 6**: Add review notes
```
"Form was handwritten with poor scan quality. 
Manually verified all addresses and contact info. 
Prosecutor to be assigned later."
```

**Step 7**: Click "Confirm and Create Docket Entry"
✅ Docket entry created successfully

---

## 🆘 Troubleshooting

### "Extract Form Data" button disabled
→ Upload a file first

### "Confirm and Create Docket Entry" disabled
→ Fill in all missing required fields first

### Changed my mind about extraction
→ Click "Manual Entry" mode to switch back

### Form preview not showing
→ This is a placeholder in dummy version
→ In production, actual form image will display

---

## 💡 Tips for Best Results

1. **Upload Quality**: Clear scans/photos work best
   - Well-lit images
   - Straight angles
   - Complete form visible

2. **Complete Forms**: More fields = better extraction
   - Fewer blanks to fill manually
   - Easier duplicate detection
   - Faster processing

3. **Review Carefully**: Don't skip the review
   - Check "Needs Review" fields
   - Verify duplicate matches
   - Add context in review notes

4. **Spelling Matters**: Especially for names
   - Affects duplicate detection
   - Used for searches
   - Critical for legal documents

5. **Save Drafts**: For complex forms
   - Save incomplete extractions
   - Resume when you have more info
   - Better than rushing

---

## 📞 Support

For issues with extraction:
1. Check if file format is supported (PDF, JPG, PNG, GIF)
2. Try uploading again
3. Check console for error messages
4. For persistent issues, use Manual Entry mode

---

**Version**: 1.0 (Dummy Implementation)
**Last Updated**: March 2025
