// Dummy form extraction utility for AI-assisted docket entry
// This uses hardcoded dummy data to simulate OCR/extraction results

export type ConfidenceLevel = 'high' | 'review' | 'missing';

export interface ExtractedField {
  name: string;
  value: string | string[];
  confidence: ConfidenceLevel;
  originalText?: string;
}

export interface ExtractionResult {
  fileName: string;
  extractedAt: string;
  fields: Record<string, ExtractedField>;
  extractedText: string;
  duplicatePersonMatches: Array<{
    name: string;
    similarity: number;
    docketId: string;
  }>;
  potentialDuplicateDockets: Array<{
    docketNumber: string;
    similarity: number;
  }>;
}

// Dummy extraction profiles for different form types
const dummyExtractionProfiles = [
  {
    // High quality extraction
    docketNumber: { value: 'DK-2025-045', confidence: 'high' as const },
    dateReceived: { value: '2025-03-12', confidence: 'high' as const },
    complainantName: { value: 'Antonio Santos Reyes', confidence: 'high' as const },
    complainantAka: { value: 'Tony Santos, A. Santos', confidence: 'high' as const },
    respondentName: { value: 'Maria Garcia Lopez', confidence: 'high' as const },
    respondentAka: { value: 'M. Garcia, Mary Lopez', confidence: 'review' as const },
    respondentAge: { value: '34', confidence: 'high' as const },
    respondentBirthDate: { value: '1991-05-18', confidence: 'high' as const },
    residentialAddress: { value: '456 Roxas Boulevard, Barangay 2, Makati, Metro Manila 1200', confidence: 'high' as const },
    officeAddress: { value: '789 EDSA Avenue, Makati Business District, 1200', confidence: 'review' as const },
    violation: { value: 'RA 9165 - Comprehensive Dangerous Drugs Act', confidence: 'high' as const },
    placeOfCommission: { value: '789 EDSA Avenue, Makati', confidence: 'high' as const },
    prosecutorAssignment: { value: '', confidence: 'missing' as const },
    remarks: { value: 'Arrest made after surveillance operation. Subject found in possession of methamphetamine.', confidence: 'high' as const },
  },
  {
    // Mixed quality extraction
    docketNumber: { value: 'DK-2025-046', confidence: 'high' as const },
    dateReceived: { value: '2025-03-15', confidence: 'high' as const },
    complainantName: { value: 'Rosa Fernandez Pilar', confidence: 'high' as const },
    complainantAka: { value: '', confidence: 'missing' as const },
    respondentName: { value: 'Juan [UNCLEAR] Cruz', confidence: 'review' as const },
    respondentAka: { value: 'J. Cruz, Johnny C.', confidence: 'review' as const },
    respondentAge: { value: '[UNCLEAR]', confidence: 'missing' as const },
    respondentBirthDate: { value: '', confidence: 'missing' as const },
    residentialAddress: { value: '123 [PARTIAL TEXT] Street, Pasay City', confidence: 'review' as const },
    officeAddress: { value: '', confidence: 'missing' as const },
    violation: { value: 'Theft / RA 10175 - Cybercrime Prevention Act', confidence: 'review' as const },
    placeOfCommission: { value: 'TBA - Shopping Mall, Makati', confidence: 'review' as const },
    prosecutorAssignment: { value: '', confidence: 'missing' as const },
    remarks: { value: 'Case involves vehicle theft and online fraud.', confidence: 'high' as const },
  },
  {
    // Poor quality extraction
    docketNumber: { value: '', confidence: 'missing' as const },
    dateReceived: { value: '2025-03-18', confidence: 'high' as const },
    complainantName: { value: '[HANDWRITTEN - UNCLEAR]', confidence: 'missing' as const },
    complainantAka: { value: '', confidence: 'missing' as const },
    respondentName: { value: 'Rodrigo Torres', confidence: 'review' as const },
    respondentAka: { value: '', confidence: 'missing' as const },
    respondentAge: { value: '38', confidence: 'review' as const },
    respondentBirthDate: { value: '', confidence: 'missing' as const },
    residentialAddress: { value: '654 [BLURRED] Avenue, Cavite City', confidence: 'review' as const },
    officeAddress: { value: '', confidence: 'missing' as const },
    violation: { value: 'VAWC - Violence Against Women and Children', confidence: 'review' as const },
    placeOfCommission: { value: '[NOT CLEARLY MARKED]', confidence: 'missing' as const },
    prosecutorAssignment: { value: '', confidence: 'missing' as const },
    remarks: { value: '', confidence: 'missing' as const },
  },
];

// Dummy duplicate matches
const possibleDuplicatePersons = [
  { name: 'Maria Garcia López', similarity: 0.92, docketId: 'DK-2025-001' },
  { name: 'M. Garcia', similarity: 0.87, docketId: 'DK-2025-015' },
];

const possibleDuplicateDockets = [
  { docketNumber: 'DK-2025-002', similarity: 0.78 },
  { docketNumber: 'DK-2025-035', similarity: 0.65 },
];

export function extractFormData(fileName: string, fileType: string): ExtractionResult {
  // Select random dummy profile to simulate different extraction qualities
  const profile = dummyExtractionProfiles[Math.floor(Math.random() * dummyExtractionProfiles.length)];

  const fields: Record<string, ExtractedField> = {
    docketNumber: {
      name: 'Docket Number',
      value: profile.docketNumber.value,
      confidence: profile.docketNumber.confidence,
      originalText: profile.docketNumber.value,
    },
    dateReceived: {
      name: 'Date Received',
      value: profile.dateReceived.value,
      confidence: profile.dateReceived.confidence,
      originalText: profile.dateReceived.value,
    },
    complainantName: {
      name: 'Complainant Name',
      value: profile.complainantName.value,
      confidence: profile.complainantName.confidence,
      originalText: profile.complainantName.value,
    },
    complainantAka: {
      name: 'Complainant AKA / Aliases',
      value: profile.complainantAka.value ? profile.complainantAka.value.split(', ') : [],
      confidence: profile.complainantAka.confidence,
      originalText: profile.complainantAka.value,
    },
    respondentName: {
      name: 'Respondent Name',
      value: profile.respondentName.value,
      confidence: profile.respondentName.confidence,
      originalText: profile.respondentName.value,
    },
    respondentAka: {
      name: 'Respondent AKA / Aliases',
      value: profile.respondentAka.value ? profile.respondentAka.value.split(', ') : [],
      confidence: profile.respondentAka.confidence,
      originalText: profile.respondentAka.value,
    },
    respondentAge: {
      name: 'Respondent Age',
      value: profile.respondentAge.value,
      confidence: profile.respondentAge.confidence,
      originalText: profile.respondentAge.value,
    },
    respondentBirthDate: {
      name: 'Respondent Birth Date',
      value: profile.respondentBirthDate.value,
      confidence: profile.respondentBirthDate.confidence,
      originalText: profile.respondentBirthDate.value,
    },
    residentialAddress: {
      name: 'Residential Address',
      value: profile.residentialAddress.value,
      confidence: profile.residentialAddress.confidence,
      originalText: profile.residentialAddress.value,
    },
    officeAddress: {
      name: 'Office Address',
      value: profile.officeAddress.value,
      confidence: profile.officeAddress.confidence,
      originalText: profile.officeAddress.value,
    },
    violation: {
      name: 'Violation / Statute',
      value: profile.violation.value,
      confidence: profile.violation.confidence,
      originalText: profile.violation.value,
    },
    placeOfCommission: {
      name: 'Place of Commission',
      value: profile.placeOfCommission.value,
      confidence: profile.placeOfCommission.confidence,
      originalText: profile.placeOfCommission.value,
    },
    prosecutorAssignment: {
      name: 'Prosecutor Assignment',
      value: profile.prosecutorAssignment.value,
      confidence: profile.prosecutorAssignment.confidence,
      originalText: profile.prosecutorAssignment.value,
    },
    remarks: {
      name: 'Remarks',
      value: profile.remarks.value,
      confidence: profile.remarks.confidence,
      originalText: profile.remarks.value,
    },
  };

  // Generate extracted text summary
  const extractedText = generateExtractedTextSummary(fields);

  return {
    fileName,
    extractedAt: new Date().toISOString(),
    fields,
    extractedText,
    duplicatePersonMatches: possibleDuplicatePersons,
    potentialDuplicateDockets: possibleDuplicateDockets,
  };
}

function generateExtractedTextSummary(fields: Record<string, ExtractedField>): string {
  return `
DOCKET ENTRY - EXTRACTED TEXT SUMMARY

Docket Number: ${fields.docketNumber.value || '[MISSING]'}
Date Received: ${fields.dateReceived.value}

COMPLAINANT:
Name: ${fields.complainantName.value}
AKA: ${Array.isArray(fields.complainantAka.value) ? fields.complainantAka.value.join(', ') || '[Not provided]' : fields.complainantAka.value}

RESPONDENT:
Name: ${fields.respondentName.value}
AKA: ${Array.isArray(fields.respondentAka.value) ? fields.respondentAka.value.join(', ') || '[Not provided]' : fields.respondentAka.value}
Age: ${fields.respondentAge.value}
Birth Date: ${fields.respondentBirthDate.value || '[Not provided]'}

ADDRESSES:
Residential: ${fields.residentialAddress.value}
Office: ${fields.officeAddress.value || '[Not provided]'}

VIOLATION:
Statute: ${fields.violation.value}
Place of Commission: ${fields.placeOfCommission.value}

REMARKS:
${fields.remarks.value || '[No remarks]'}

---
Data Extraction Status:
- ${Object.values(fields).filter(f => f.confidence === 'high').length} fields with high confidence
- ${Object.values(fields).filter(f => f.confidence === 'review').length} fields requiring review
- ${Object.values(fields).filter(f => f.confidence === 'missing').length} fields missing
  `.trim();
}

export function getMissingFields(fields: Record<string, ExtractedField>): ExtractedField[] {
  return Object.values(fields).filter(f => f.confidence === 'missing');
}

export function getReviewFields(fields: Record<string, ExtractedField>): ExtractedField[] {
  return Object.values(fields).filter(f => f.confidence === 'review');
}

export function getConfidenceStats(fields: Record<string, ExtractedField>) {
  const total = Object.keys(fields).length;
  const high = Object.values(fields).filter(f => f.confidence === 'high').length;
  const review = Object.values(fields).filter(f => f.confidence === 'review').length;
  const missing = Object.values(fields).filter(f => f.confidence === 'missing').length;

  return {
    total,
    high,
    review,
    missing,
    overallConfidence: Math.round((high / total) * 100),
  };
}
