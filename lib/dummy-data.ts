import {
  Docket,
  CaseDetails,
  Person,
  Violation,
  Prosecutor,
  Attachment,
  CaseDetailsWithAttachments,
} from './types';

// Sample prosecutors
export const prosecutors: Prosecutor[] = [
  {
    id: '1',
    name: 'Maria Santos',
    contactNumber: '09171234567',
    email: 'maria.santos@ocp.gov.ph',
    officeLocation: 'OCP Quezon City',
  },
  {
    id: '2',
    name: 'Juan Reyes',
    contactNumber: '09172345678',
    email: 'juan.reyes@ocp.gov.ph',
    officeLocation: 'OCP Makati',
  },
  {
    id: '3',
    name: 'Anna Dela Cruz',
    contactNumber: '09173456789',
    email: 'anna.delacruz@ocp.gov.ph',
    officeLocation: 'OCP Cebu',
  },
];

// Sample persons
const samplePersons = {
  maria_garcia: {
    id: 'person-1',
    firstName: 'Maria',
    lastName: 'Garcia',
    middleName: 'Luz',
    aliases: ['Maria L. Garcia', 'ML Garcia'],
    dateOfBirth: '1985-03-15',
    gender: 'Female' as const,
    contactNumber: '09051234567',
    email: 'maria.garcia@email.com',
    addresses: [
      {
        id: 'addr-1',
        type: 'Residential' as const,
        street: '123 Mabini St',
        barangay: 'Barangay 1',
        municipality: 'Quezon City',
        province: 'Metro Manila',
        zipCode: '1100',
        isPrimary: true,
      },
    ],
  },
  carlos_santos: {
    id: 'person-2',
    firstName: 'Carlos',
    lastName: 'Santos',
    middleName: 'Rene',
    aliases: ['CR Santos', 'Carlos R. Santos'],
    dateOfBirth: '1980-07-22',
    gender: 'Male' as const,
    contactNumber: '09061234567',
    email: 'carlos.santos@email.com',
    addresses: [
      {
        id: 'addr-2',
        type: 'Residential' as const,
        street: '456 EDSA Ave',
        barangay: 'Barangay 2',
        municipality: 'Makati',
        province: 'Metro Manila',
        zipCode: '1200',
        isPrimary: true,
      },
    ],
  },
  juan_cruz: {
    id: 'person-3',
    firstName: 'Juan',
    lastName: 'Cruz',
    middleName: 'Miguel',
    aliases: ['JM Cruz', 'Juan M. Cruz', 'Juaning'],
    dateOfBirth: '1990-11-10',
    gender: 'Male' as const,
    contactNumber: '09071234567',
    email: 'juan.cruz@email.com',
    addresses: [
      {
        id: 'addr-3',
        type: 'Residential' as const,
        street: '789 Roxas Blvd',
        barangay: 'Barangay 3',
        municipality: 'Pasay',
        province: 'Metro Manila',
        zipCode: '1300',
        isPrimary: true,
      },
    ],
  },
  rosa_fernandez: {
    id: 'person-4',
    firstName: 'Rosa',
    lastName: 'Fernandez',
    middleName: 'Pilar',
    aliases: ['Rosa P. Fernandez', 'RP Fernandez'],
    dateOfBirth: '1992-05-18',
    gender: 'Female' as const,
    contactNumber: '09081234567',
    email: 'rosa.fernandez@email.com',
    addresses: [
      {
        id: 'addr-4',
        type: 'Office' as const,
        street: '321 Pilipinas St',
        barangay: 'Barangay 4',
        municipality: 'Las Piñas',
        province: 'Metro Manila',
        zipCode: '1740',
        isPrimary: true,
      },
    ],
  },
  rodrigo_torres: {
    id: 'person-5',
    firstName: 'Rodrigo',
    lastName: 'Torres',
    aliases: ['Rod Torres', 'Rodrigo T.'],
    dateOfBirth: '1988-09-25',
    gender: 'Male' as const,
    contactNumber: '09091234567',
    email: 'rodrigo.torres@email.com',
    addresses: [
      {
        id: 'addr-5',
        type: 'Residential' as const,
        street: '654 Magsaysay Ave',
        barangay: 'Barangay 5',
        municipality: 'Cavite City',
        province: 'Cavite',
        zipCode: '4100',
        isPrimary: true,
      },
    ],
  },
};

const sampleViolations = {
  drug_dealing: {
    id: 'vio-1',
    statute: 'RA 9165',
    description: 'Illegal Sale of Dangerous Drugs',
    dateCommitted: '2025-01-15',
    location: 'Barangay 1, Quezon City',
    details: 'Possession and sale of 50 grams of methamphetamine hydrochloride',
  },
  theft: {
    id: 'vio-2',
    statute: 'RPC Article 308',
    description: 'Theft',
    dateCommitted: '2025-01-10',
    location: 'Makati Commercial Center',
    details: 'Shoplifting of electronics worth PHP 45,000',
  },
  estafa: {
    id: 'vio-3',
    statute: 'RPC Article 315',
    description: 'Estafa',
    dateCommitted: '2025-01-20',
    location: 'Online Transaction',
    details: 'Fraudulent transaction involving PHP 100,000',
  },
  vawc: {
    id: 'vio-4',
    statute: 'RA 9262',
    description: 'Violence Against Women and Children',
    dateCommitted: '2025-01-12',
    location: 'Residential area, Pasay',
    details: 'Physical abuse and threats',
  },
  cybercrime: {
    id: 'vio-5',
    statute: 'RA 10175',
    description: 'Cybercrime Prevention Act Violation',
    dateCommitted: '2025-01-18',
    location: 'Online',
    details: 'Unauthorized access to computer system',
  },
};

// Sample cases
const sampleCases: CaseDetails[] = [
  {
    id: 'case-1',
    caseNumber: 'OCP-2025-001',
    dateOfIncident: '2025-01-15',
    complainants: [samplePersons.maria_garcia],
    respondents: [samplePersons.carlos_santos],
    witnesses: [],
    violations: [sampleViolations.drug_dealing],
    status: 'Filed',
    statusHistory: [
      {
        id: 'status-1',
        date: '2025-01-15',
        status: 'Pending',
        remarks: 'Case received',
        updatedBy: 'Officer Santos',
      },
      {
        id: 'status-2',
        date: '2025-01-25',
        status: 'Filed',
        remarks: 'Case filed in court',
        updatedBy: 'Prosecutor Maria Santos',
      },
    ],
    assignedProsecutor: prosecutors[0],
    prosecutor: prosecutors[0].name,
  },
  {
    id: 'case-2',
    caseNumber: 'OCP-2025-002',
    dateOfIncident: '2025-01-10',
    complainants: [samplePersons.rosa_fernandez],
    respondents: [samplePersons.juan_cruz],
    witnesses: [samplePersons.maria_garcia],
    violations: [sampleViolations.theft],
    status: 'Pending',
    statusHistory: [
      {
        id: 'status-3',
        date: '2025-01-10',
        status: 'Pending',
        remarks: 'Case received',
        updatedBy: 'Officer Reyes',
      },
    ],
    prosecutor: undefined,
  },
  {
    id: 'case-3',
    caseNumber: 'OCP-2025-003',
    dateOfIncident: '2025-01-20',
    complainants: [samplePersons.juan_cruz],
    respondents: [samplePersons.rodrigo_torres],
    witnesses: [],
    violations: [sampleViolations.estafa],
    status: 'Pending',
    stage: 'For Filing',
    statusHistory: [
      {
        id: 'status-4',
        date: '2025-01-20',
        status: 'Pending',
        remarks: 'Case received',
        updatedBy: 'Officer Gonzales',
      },
      {
        id: 'status-5',
        date: '2025-02-05',
        status: 'Pending',
    stage: 'For Filing',
        remarks: 'Requesting further information from complainant',
        updatedBy: 'Prosecutor Anna Dela Cruz',
      },
    ],
    assignedProsecutor: prosecutors[2],
    prosecutor: prosecutors[2].name,
  },
  {
    id: 'case-4',
    caseNumber: 'OCP-2025-004',
    dateOfIncident: '2025-01-12',
    complainants: [samplePersons.maria_garcia],
    respondents: [samplePersons.carlos_santos],
    witnesses: [samplePersons.rosa_fernandez],
    violations: [sampleViolations.vawc],
    status: 'Mixed Result',
    stage: 'Mixed Result',
    statusHistory: [
      {
        id: 'status-6',
        date: '2025-01-12',
        status: 'Pending',
        remarks: 'Case received',
        updatedBy: 'Officer Santos',
      },
      {
        id: 'status-7',
        date: '2025-02-10',
        status: 'Filed',
        remarks: 'Case filed in court',
        updatedBy: 'Prosecutor Maria Santos',
      },
      {
        id: 'status-8',
        date: '2025-03-01',
        status: 'Mixed Result',
    stage: 'Mixed Result',
        remarks: 'Case settled and resolved',
        updatedBy: 'Prosecutor Maria Santos',
      },
    ],
    assignedProsecutor: prosecutors[0],
    prosecutor: prosecutors[0].name,
  },
];

// Sample attachments
const sampleAttachments: Attachment[] = [
  {
    id: 'attach-1',
    fileName: 'Initial_Complaint.pdf',
    fileType: 'PDF',
    uploadDate: '2025-01-15',
    size: '2.4 MB',
    uploadedBy: 'Maria Garcia',
  },
  {
    id: 'attach-2',
    fileName: 'Evidence_Photo.jpg',
    fileType: 'Image',
    uploadDate: '2025-01-16',
    size: '1.8 MB',
    uploadedBy: 'Officer Santos',
  },
  {
    id: 'attach-3',
    fileName: 'Witness_Statement.docx',
    fileType: 'Document',
    uploadDate: '2025-01-18',
    size: '0.5 MB',
    uploadedBy: 'Rosa Fernandez',
  },
];

// Sample dockets
export const dockets: Docket[] = [
  {
    id: 'docket-1',
    docketNumber: 'DK-2025-001',
    createdDate: '2025-01-15',
    cases: [sampleCases[0]],
    status: 'Filed',
    description: 'Drug-related case involving possession and sale',
  },
  {
    id: 'docket-2',
    docketNumber: 'DK-2025-002',
    createdDate: '2025-01-10',
    cases: [sampleCases[1]],
    status: 'Pending',
    description: 'Theft case from retail establishment',
  },
  {
    id: 'docket-3',
    docketNumber: 'DK-2025-003',
    createdDate: '2025-01-20',
    cases: [sampleCases[2]],
    status: 'Pending',
    stage: 'For Filing',
    description: 'Online fraud case - estafa',
  },
  {
    id: 'docket-4',
    docketNumber: 'DK-2025-004',
    createdDate: '2025-01-12',
    cases: [sampleCases[3]],
    status: 'Mixed Result',
    stage: 'Mixed Result',
    description: 'Violence against women case',
  },
  {
    id: 'docket-5',
    docketNumber: 'DK-2025-005',
    createdDate: '2025-01-22',
    cases: [
      {
        id: 'case-5',
        caseNumber: 'OCP-2025-005',
        dateOfIncident: '2025-01-22',
        complainants: [samplePersons.juan_cruz],
        respondents: [samplePersons.maria_garcia],
        witnesses: [],
        violations: [sampleViolations.cybercrime],
        status: 'Pending',
        statusHistory: [
          {
            id: 'status-9',
            date: '2025-01-22',
            status: 'Pending',
            remarks: 'Case received',
            updatedBy: 'Officer Lopez',
          },
        ],
      },
    ],
    status: 'Pending',
  },
  {
    id: 'docket-6',
    docketNumber: 'DK-2025-006',
    createdDate: '2025-02-01',
    cases: [
      {
        id: 'case-6',
        caseNumber: 'OCP-2025-006',
        dateOfIncident: '2025-01-28',
        complainants: [samplePersons.rosa_fernandez],
        respondents: [samplePersons.rodrigo_torres],
        witnesses: [samplePersons.juan_cruz],
        violations: [sampleViolations.drug_dealing],
        status: 'Filed',
        statusHistory: [
          {
            id: 'status-10',
            date: '2025-01-28',
            status: 'Pending',
            remarks: 'Case received',
            updatedBy: 'Officer Santos',
          },
          {
            id: 'status-11',
            date: '2025-02-08',
            status: 'Filed',
            remarks: 'Case filed in court',
            updatedBy: 'Prosecutor Juan Reyes',
          },
        ],
        assignedProsecutor: prosecutors[1],
        prosecutor: prosecutors[1].name,
      },
    ],
    status: 'Filed',
  },
  {
    id: 'docket-7',
    docketNumber: 'DK-2025-007',
    createdDate: '2025-02-03',
    cases: [
      {
        id: 'case-7',
        caseNumber: 'OCP-2025-007',
        dateOfIncident: '2025-02-03',
        complainants: [samplePersons.maria_garcia],
        respondents: [samplePersons.carlos_santos],
        witnesses: [],
        violations: [sampleViolations.vawc],
        status: 'Dismissed',
        statusHistory: [
          {
            id: 'status-12',
            date: '2025-02-03',
            status: 'Pending',
            remarks: 'Case received',
            updatedBy: 'Officer Santos',
          },
          {
            id: 'status-13',
            date: '2025-02-15',
            status: 'Dismissed',
            remarks: 'Case dismissed due to lack of evidence',
            updatedBy: 'Prosecutor Maria Santos',
          },
        ],
        assignedProsecutor: prosecutors[0],
        prosecutor: prosecutors[0].name,
      },
    ],
    status: 'Dismissed',
  },
  {
    id: 'docket-8',
    docketNumber: 'DK-2025-008',
    createdDate: '2025-02-05',
    cases: [
      {
        id: 'case-8',
        caseNumber: 'OCP-2025-008',
        dateOfIncident: '2025-02-05',
        complainants: [samplePersons.rosa_fernandez],
        respondents: [samplePersons.juan_cruz],
        witnesses: [],
        violations: [sampleViolations.theft],
        status: 'Pending',
        statusHistory: [
          {
            id: 'status-14',
            date: '2025-02-05',
            status: 'Pending',
            remarks: 'Case received',
            updatedBy: 'Officer Reyes',
          },
        ],
      },
    ],
    status: 'Pending',
  },
  {
    id: 'docket-9',
    docketNumber: 'DK-2025-009',
    createdDate: '2025-02-07',
    cases: [
      {
        id: 'case-9',
        caseNumber: 'OCP-2025-009',
        dateOfIncident: '2025-02-07',
        complainants: [samplePersons.juan_cruz],
        respondents: [samplePersons.rodrigo_torres],
        witnesses: [samplePersons.maria_garcia],
        violations: [sampleViolations.cybercrime],
        status: 'Filed',
        statusHistory: [
          {
            id: 'status-15',
            date: '2025-02-07',
            status: 'Pending',
            remarks: 'Case received',
            updatedBy: 'Officer Gonzales',
          },
          {
            id: 'status-16',
            date: '2025-02-18',
            status: 'Filed',
            remarks: 'Case filed in court',
            updatedBy: 'Prosecutor Anna Dela Cruz',
          },
        ],
        assignedProsecutor: prosecutors[2],
        prosecutor: prosecutors[2].name,
      },
    ],
    status: 'Filed',
  },
  {
    id: 'docket-10',
    docketNumber: 'DK-2025-010',
    createdDate: '2025-02-10',
    cases: [
      {
        id: 'case-10',
        caseNumber: 'OCP-2025-010',
        dateOfIncident: '2025-02-10',
        complainants: [samplePersons.rosa_fernandez],
        respondents: [samplePersons.carlos_santos],
        witnesses: [samplePersons.juan_cruz, samplePersons.rodrigo_torres],
        violations: [sampleViolations.estafa],
        status: 'Mixed Result',
    stage: 'Mixed Result',
        statusHistory: [
          {
            id: 'status-17',
            date: '2025-02-10',
            status: 'Pending',
            remarks: 'Case received',
            updatedBy: 'Officer Lopez',
          },
          {
            id: 'status-18',
            date: '2025-02-20',
            status: 'Filed',
            remarks: 'Case filed in court',
            updatedBy: 'Prosecutor Juan Reyes',
          },
          {
            id: 'status-19',
            date: '2025-03-05',
            status: 'Mixed Result',
    stage: 'Mixed Result',
            remarks: 'Case resolved with settlement',
            updatedBy: 'Prosecutor Juan Reyes',
          },
        ],
        assignedProsecutor: prosecutors[1],
        prosecutor: prosecutors[1].name,
      },
    ],
    status: 'Mixed Result',
    stage: 'Mixed Result',
  },
];

// Cases with attachments for the case details view
export const getCaseWithAttachments = (
  caseId: string
): CaseDetailsWithAttachments | undefined => {
  const caseDetail = sampleCases.find((c) => c.id === caseId);
  if (!caseDetail) return undefined;

  return {
    ...caseDetail,
    attachments: sampleAttachments,
  };
};

// Helper function to get a docket by ID
export const getDocketById = (id: string): Docket | undefined => {
  return dockets.find((d) => d.id === id);
};

// Helper function to get a case by ID across all dockets
export const getCaseById = (caseId: string): CaseDetails | undefined => {
  for (const docket of dockets) {
    const caseDetail = docket.cases.find((c) => c.id === caseId);
    if (caseDetail) return caseDetail;
  }
  return undefined;
};
