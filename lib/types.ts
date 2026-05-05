// Status enums and types
export type CaseStatus = 'Pending' | 'Filed' | 'Dismissed' | 'Resolved' | 'RFI';
export type PersonRole = 'Complainant' | 'Respondent' | 'Witness' | 'Representative';
export type AddressType = 'Residential' | 'Office' | 'Barangay';

// Core entities
export interface Address {
  id: string;
  type: AddressType;
  street: string;
  barangay: string;
  municipality: string;
  province: string;
  zipCode: string;
  isPrimary: boolean;
}

export interface Person {
  id: string;
  firstName: string;
  lastName: string;
  middleName?: string;
  aliases: string[];
  dateOfBirth?: string;
  gender?: 'Male' | 'Female' | 'Other';
  contactNumber?: string;
  email?: string;
  addresses: Address[];
}

export interface Violation {
  id: string;
  statute: string;
  description: string;
  dateCommitted?: string;
  location?: string;
  details?: string;
}

export interface CaseDetails {
  id: string;
  caseNumber: string;
  dateOfIncident: string;
  complainants: Person[];
  respondents: Person[];
  witnesses: Person[];
  violations: Violation[];
  status: CaseStatus;
  statusHistory: StatusUpdate[];
  assignedProsecutor?: Prosecutor;
  prosecutor?: string;
  remarks?: string;
}

export interface Docket {
  id: string;
  docketNumber: string;
  createdDate: string;
  cases: CaseDetails[];
  status: CaseStatus;
  description?: string;
}

export interface StatusUpdate {
  id: string;
  date: string;
  status: CaseStatus;
  remarks: string;
  updatedBy: string;
}

export interface Prosecutor {
  id: string;
  name: string;
  contactNumber: string;
  email: string;
  officeLocation: string;
}

export interface ProsecutorAssignment {
  id: string;
  caseId: string;
  prosecutorId: string;
  prosecutorName: string;
  assignmentDate: string;
  status: 'Active' | 'Reassigned' | 'Completed';
}

export interface Attachment {
  id: string;
  fileName: string;
  fileType: string;
  uploadDate: string;
  size: string;
  uploadedBy: string;
}

export interface CaseDetailsWithAttachments extends CaseDetails {
  attachments: Attachment[];
}

export interface ClearanceSearchResult {
  id: string;
  docketNumber: string;
  caseNumber: string;
  respondent: Person;
  status: CaseStatus;
  lastUpdated: string;
  confidenceScore?: number; // For fuzzy search results
}
