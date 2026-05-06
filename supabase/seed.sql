-- OCP Docket Management System - Safe Dummy Seed Data
-- Contains 10 dockets with realistic dummy data (no real OCP records)
-- All names and data are fictional for demonstration purposes only

-- Insert Prosecutors
INSERT INTO public.app_users (id, email, full_name, role, office_location, status, created_at) VALUES
('user-1', 'prosecutor1@example.com', 'Maria Santos', 'prosecutor', 'OCP Quezon City', 'active', NOW()),
('user-2', 'prosecutor2@example.com', 'Juan Reyes', 'prosecutor', 'OCP Makati', 'active', NOW()),
('user-3', 'prosecutor3@example.com', 'Anna Dela Cruz', 'prosecutor', 'OCP Cebu', 'active', NOW()),
('user-4', 'prosecutor4@example.com', 'Robert Santos', 'prosecutor', 'OCP Las Piñas', 'active', NOW()),
('user-5', 'staff1@example.com', 'Lisa Miguel', 'staff', 'OCP Quezon City', 'active', NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert Docket 1 with 2 cases
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-1', 'DK-2025-001', 2025, '2025-01-15', 'RA 9165 - Drug possession and intent to distribute', 'Barangay 1, Quezon City', 'Filed in Court', 'user-1', 'Complex case with multiple subjects', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-1', 'docket-1', 'OCP-2025-001', '2025-01-10', 'Filed in Court', 'user-1', NOW()),
('case-2', 'docket-1', 'OCP-2025-002', '2025-01-12', 'Pending', NULL, NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert Persons for Docket 1
INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-1', 'Carlos Rene Santos', '1985-07-22', 'Male', '09061234567', 'carlos.santos@email.com', 'Primary respondent', NOW()),
('person-2', 'Maria Luz Garcia', '1988-03-15', 'Female', '09051234567', 'maria.garcia@email.com', 'Complainant', NOW()),
('person-3', 'Juan Miguel Cruz', '1992-11-10', 'Male', '09071234567', 'juan.cruz@email.com', 'Witness', NOW())
ON CONFLICT (id) DO NOTHING;

-- Insert Person Aliases
INSERT INTO public.person_aliases (person_id, alias_name, type, created_at) VALUES
('person-1', 'CR Santos', 'nickname', NOW()),
('person-1', 'Carlito', 'nickname', NOW()),
('person-1', 'Charles Santos', 'alternative_name', NOW()),
('person-2', 'M. Luz Garcia', 'nickname', NOW()),
('person-2', 'Mary Garcia', 'nickname', NOW()),
('person-3', 'JM Cruz', 'nickname', NOW()),
('person-3', 'Juaning', 'nickname', NOW())
ON CONFLICT (person_id, alias_name) DO NOTHING;

-- Insert Person Addresses
INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-1', 'Residential', '456 EDSA Ave', 'Barangay 2', 'Makati', 'Metro Manila', '1200', true, NOW()),
('person-1', 'Office', '789 Amorsolo St', 'Barangay San Lorenzo', 'Makati', 'Metro Manila', '1200', false, NOW()),
('person-2', '123 Mabini St', 'Residential', 'Barangay 1', 'Quezon City', 'Metro Manila', '1100', true, NOW()),
('person-3', '789 Roxas Blvd', 'Residential', 'Barangay 3', 'Pasay', 'Metro Manila', '1300', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

-- Insert Case Participants
INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-1', 'person-1', 'respondent', NOW()),
('case-1', 'person-2', 'complainant', NOW()),
('case-1', 'person-3', 'witness', NOW()),
('case-2', 'person-1', 'respondent', NOW()),
('case-2', 'person-2', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

-- Insert Violations for Docket 1
INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-1', 'RA 9165 Sec. 11', 'Drug Possession', 'Illegal possession of dangerous drugs', 'Reclusion Temporal', NOW()),
('vio-2', 'RA 9165 Sec. 5', 'Drug Distribution', 'Attempt to distribute dangerous drugs', 'Reclusion Perpetua', NOW())
ON CONFLICT (id) DO NOTHING;

-- Link violations to cases
INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-1', 'vio-1', NOW()),
('case-1', 'vio-2', NOW()),
('case-2', 'vio-1', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

-- Insert Case Status Updates
INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-1', 'Pending', 'Case received and logged', 'user-5', '2025-01-15'),
('case-1', 'For Review', 'Evidence reviewed by prosecutor', 'user-1', '2025-01-20'),
('case-1', 'Filed in Court', 'Case filed in Metropolitan Trial Court', 'user-1', '2025-02-01'),
('case-2', 'Pending', 'Case received and logged', 'user-5', '2025-01-17')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

-- Insert Prosecutor Assignments
INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-1', 'user-1', '2025-01-20', 'Primary assigned prosecutor', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

-- Insert Attachments metadata
INSERT INTO public.attachments (id, docket_id, case_id, file_name, file_type, file_size, upload_date, uploaded_by, remarks, created_at) VALUES
('attach-1', 'docket-1', 'case-1', 'Investigation_Report.pdf', 'PDF', '2.5 MB', NOW(), 'user-5', 'Initial investigation report', NOW()),
('attach-2', 'docket-1', 'case-1', 'Evidence_Photos.jpg', 'Image', '8.7 MB', NOW(), 'user-5', 'Crime scene photographs', NOW()),
('attach-3', 'docket-1', 'case-2', 'Witness_Statement.pdf', 'PDF', '1.2 MB', NOW(), 'user-5', 'Witness written statement', NOW())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- DOCKET 2: Theft Case
-- =====================================================
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-2', 'DK-2025-002', 2025, '2025-01-18', 'Theft of merchandise from commercial establishment', 'SM Mall of Asia, Pasay', 'Pending', 'user-2', 'Retail theft case with CCTV evidence', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-3', 'docket-2', 'OCP-2025-003', '2025-01-15', 'Pending', 'user-2', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-4', 'Rosa Pilar Fernandez', '1992-05-18', 'Female', '09081234567', 'rosa.fernandez@email.com', 'Respondent - accused of theft', NOW()),
('person-5', 'David Reyes', '1980-09-25', 'Male', '09091234567', 'david.reyes@email.com', 'Store manager - complainant', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_aliases (person_id, alias_name, type, created_at) VALUES
('person-4', 'Rosita Fernandez', 'nickname', NOW()),
('person-4', 'RP Fernandez', 'nickname', NOW()),
('person-5', 'Dave Reyes', 'nickname', NOW())
ON CONFLICT (person_id, alias_name) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-4', 'Residential', '321 Pilipinas St', 'Barangay 4', 'Las Piñas', 'Metro Manila', '1740', true, NOW()),
('person-5', 'Office', 'SM MOA Business Office', 'Barangay Tambo', 'Pasay', 'Metro Manila', '1300', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-3', 'person-4', 'respondent', NOW()),
('case-3', 'person-5', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-3', 'RPC Art. 308', 'Theft', 'Simple theft of personal property', 'Prision Correccional', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-3', 'vio-3', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-3', 'Pending', 'Case received and documented', 'user-5', '2025-01-18')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-2', 'user-2', '2025-01-25', 'Assigned for review', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

INSERT INTO public.attachments (id, docket_id, case_id, file_name, file_type, file_size, upload_date, uploaded_by, remarks, created_at) VALUES
('attach-4', 'docket-2', 'case-3', 'CCTV_Footage_Timeline.mp4', 'Video', '45.3 MB', NOW(), 'user-5', 'Store CCTV footage of incident', NOW()),
('attach-5', 'docket-2', 'case-3', 'Store_Complaint_Form.pdf', 'PDF', '0.8 MB', NOW(), 'user-5', 'Official store complaint', NOW())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- DOCKET 3: VAWC (Violence Against Women and Children)
-- =====================================================
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-3', 'DK-2025-003', 2025, '2025-01-22', 'RA 9262 - Violence Against Women and Children', 'Residential address, Quezon City', 'For Review', 'user-3', 'Sensitive case requiring confidentiality', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-4', 'docket-3', 'OCP-2025-004', '2025-01-20', 'For Review', 'user-3', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-6', 'Antonio Rivera', '1979-04-12', 'Male', '09101234567', 'antonio.rivera@email.com', 'Respondent', NOW()),
('person-7', 'Elena Santos Rivera', '1990-08-30', 'Female', '09111234567', 'elena.santos@email.com', 'Victim - complainant', NOW()),
('person-8', 'Sofia Rivera', '2012-06-15', 'Female', NULL, NULL, 'Minor child - victim', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_aliases (person_id, alias_name, type, created_at) VALUES
('person-6', 'Tony Rivera', 'nickname', NOW()),
('person-7', 'Elena R. Santos', 'maiden_name', NOW())
ON CONFLICT (person_id, alias_name) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-6', 'Residential', '654 Magsaysay Ave', 'Barangay 5', 'Cavite City', 'Cavite', '4100', true, NOW()),
('person-7', 'Residential', '654 Magsaysay Ave', 'Barangay 5', 'Cavite City', 'Cavite', '4100', true, NOW()),
('person-8', 'Residential', '654 Magsaysay Ave', 'Barangay 5', 'Cavite City', 'Cavite', '4100', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-4', 'person-6', 'respondent', NOW()),
('case-4', 'person-7', 'complainant', NOW()),
('case-4', 'person-8', 'victim', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-4', 'RA 9262 Sec. 5', 'Acts of Abuse', 'Abuse against woman or child', 'Prision Correccional', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-4', 'vio-4', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-4', 'Pending', 'Confidential case received', 'user-5', '2025-01-22'),
('case-4', 'For Review', 'Requires sensitive handling', 'user-3', '2025-01-25')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-3', 'user-3', '2025-01-25', 'Specialist in VAWC cases', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

INSERT INTO public.attachments (id, docket_id, case_id, file_name, file_type, file_size, upload_date, uploaded_by, remarks, created_at) VALUES
('attach-6', 'docket-3', 'case-4', 'Medical_Certificate.pdf', 'PDF', '1.5 MB', NOW(), 'user-5', 'Medical examination results (CONFIDENTIAL)', NOW()),
('attach-7', 'docket-3', 'case-4', 'Barangay_Certification.pdf', 'PDF', '0.6 MB', NOW(), 'user-5', 'Barangay conciliation report', NOW())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- DOCKET 4: Estafa (Fraud)
-- =====================================================
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-4', 'DK-2025-004', 2025, '2025-01-25', 'RPC Art. 315 - Estafa through false pretenses', 'Online transaction, Metro Manila', 'Pending', 'user-1', 'Cybercrime-related fraud case', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-5', 'docket-4', 'OCP-2025-005', '2025-01-20', 'Pending', NULL, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-9', 'Victor Castillo', '1988-12-08', 'Male', '09121234567', 'victor.castillo@email.com', 'Respondent - accused of fraud', NOW()),
('person-10', 'Roberto Santos', '1975-03-20', 'Male', '09131234567', 'roberto.santos@email.com', 'Complainant - victim of fraud', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-9', 'Residential', '234 Laurel Ave', 'Barangay Greenhills', 'San Juan', 'Metro Manila', '1502', true, NOW()),
('person-10', 'Residential', '567 P Burgos St', 'Barangay 1', 'Taguig', 'Metro Manila', '1634', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-5', 'person-9', 'respondent', NOW()),
('case-5', 'person-10', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-5', 'RPC Art. 315', 'Estafa', 'Estafa through false pretenses and fraudulent acts', 'Prision Temporal', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-5', 'vio-5', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-5', 'Pending', 'Case received for investigation', 'user-5', '2025-01-25')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

-- =====================================================
-- DOCKET 5: Cybercrime (RA 10175)
-- =====================================================
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-5', 'DK-2025-005', 2025, '2025-01-28', 'RA 10175 - Cybercrime Prevention Act violations', 'Internet-based, multiple locations', 'Dismissed', 'user-4', 'Case dismissed due to insufficient evidence', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-6', 'docket-5', 'OCP-2025-006', '2025-01-22', 'Dismissed', 'user-4', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-11', 'Kenneth Reyes', '1995-07-14', 'Male', '09141234567', 'kenneth.reyes@email.com', 'Respondent - accused of cyber harassment', NOW()),
('person-12', 'Patricia Gonzales', '1992-11-22', 'Female', '09151234567', 'patricia.gonzales@email.com', 'Complainant - victim of cyber harassment', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_aliases (person_id, alias_name, type, created_at) VALUES
('person-11', 'Ken Reyes', 'nickname', NOW()),
('person-12', 'Patty Gonzales', 'nickname', NOW())
ON CONFLICT (person_id, alias_name) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-11', 'Residential', '789 Ortigas Ave', 'Barangay Sta. Maria', 'Pasig', 'Metro Manila', '1605', true, NOW()),
('person-12', 'Residential', '456 Aurora Blvd', 'Barangay Balanoy', 'Quezon City', 'Metro Manila', '1104', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-6', 'person-11', 'respondent', NOW()),
('case-6', 'person-12', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-6', 'RA 10175 Sec. 4', 'Cybercrime - Harassment', 'Cyber harassment through social media', 'Prision Correccional', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-6', 'vio-6', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-6', 'Pending', 'Cybercrime case filed', 'user-5', '2025-01-28'),
('case-6', 'For Review', 'Awaiting prosecutor evaluation', 'user-4', '2025-02-01'),
('case-6', 'Dismissed', 'Insufficient evidence for prosecution', 'user-4', '2025-02-05')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-5', 'user-4', '2025-02-01', 'Assigned for evaluation', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

-- =====================================================
-- DOCKET 6-10: Additional Dockets
-- =====================================================

-- DOCKET 6: Malicious Mischief
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-6', 'DK-2025-006', 2025, '2025-02-01', 'RPC Art. 327 - Malicious Mischief', 'Commercial property, Makati', 'Filed in Court', 'user-2', 'Property damage case with repair estimates', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-7', 'docket-6', 'OCP-2025-007', '2025-01-28', 'Filed in Court', 'user-2', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-13', 'Miguel Fernandez', '1998-05-09', 'Male', '09161234567', 'miguel.fernandez@email.com', 'Respondent', NOW()),
('person-14', 'Grace Aquino', '1982-09-17', 'Female', '09171234567', 'grace.aquino@email.com', 'Property owner - complainant', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-13', 'Residential', '890 Pasong Tamo', 'Barangay Magallanes', 'Makati', 'Metro Manila', '1232', true, NOW()),
('person-14', 'Office', 'Makati Business Center', 'Barangay Magallanes', 'Makati', 'Metro Manila', '1232', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-7', 'person-13', 'respondent', NOW()),
('case-7', 'person-14', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-7', 'RPC Art. 327', 'Malicious Mischief', 'Damage to commercial property', 'Prision Correccional', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-7', 'vio-7', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-7', 'Pending', 'Property damage case received', 'user-5', '2025-02-01'),
('case-7', 'For Review', 'Repair estimates verified', 'user-2', '2025-02-03'),
('case-7', 'Filed in Court', 'Case filed in appropriate court', 'user-2', '2025-02-10')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-6', 'user-2', '2025-02-03', 'Assigned for prosecution', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

-- DOCKET 7: Robbery
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-7', 'DK-2025-007', 2025, '2025-02-05', 'RPC Art. 294 - Robbery with intimidation', 'Commercial establishment, Las Piñas', 'For Review', 'user-1', 'Armed robbery case, suspect still at large', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-8', 'docket-7', 'OCP-2025-008', '2025-02-02', 'For Review', 'user-1', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-15', 'Samuel Gutierrez', '1990-02-28', 'Male', '09181234567', 'samuel.gutierrez@email.com', 'Respondent - suspect at large', NOW()),
('person-16', 'Theresa Villanueva', '1988-10-05', 'Female', '09191234567', 'theresa.villanueva@email.com', 'Store manager - complainant', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-15', 'Last known', '123 Rizal St', 'Barangay Pacita', 'Las Piñas', 'Metro Manila', '1740', true, NOW()),
('person-16', 'Office', 'Puregold Las Piñas', 'Barangay Talon', 'Las Piñas', 'Metro Manila', '1747', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-8', 'person-15', 'respondent', NOW()),
('case-8', 'person-16', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-8', 'RPC Art. 294', 'Robbery with Intimidation', 'Armed robbery of commercial establishment', 'Reclusion Temporal', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-8', 'vio-8', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-8', 'Pending', 'Armed robbery case received', 'user-5', '2025-02-05'),
('case-8', 'For Review', 'Waiting for additional evidence', 'user-1', '2025-02-08')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-7', 'user-1', '2025-02-08', 'Specialist in serious crimes', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

-- DOCKET 8: Simple Assault
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-8', 'DK-2025-008', 2025, '2025-02-08', 'RPC Art. 266 - Simple Assault', 'Public road, Pasay', 'Pending', 'user-3', 'Assault case with minor injuries', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-9', 'docket-8', 'OCP-2025-009', '2025-02-06', 'Pending', NULL, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-17', 'Jerome Diaz', '1986-06-19', 'Male', '09201234567', 'jerome.diaz@email.com', 'Respondent', NOW()),
('person-18', 'Nicole Tan', '1994-08-11', 'Female', '09211234567', 'nicole.tan@email.com', 'Victim - complainant', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-17', 'Residential', '234 Escala St', 'Barangay 13', 'Pasay', 'Metro Manila', '1307', true, NOW()),
('person-18', 'Residential', '567 Rotonda St', 'Barangay 14', 'Pasay', 'Metro Manila', '1308', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-9', 'person-17', 'respondent', NOW()),
('case-9', 'person-18', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-9', 'RPC Art. 266', 'Simple Assault', 'Voluntary assault causing light physical injuries', 'Arresto Menor', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-9', 'vio-9', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-9', 'Pending', 'Assault case received', 'user-5', '2025-02-08')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

-- DOCKET 9: Property damage with multiple cases
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-9', 'DK-2025-009', 2025, '2025-02-10', 'Multiple violations: Trespass and Property Damage', 'Residential compound, Valenzuela', 'Filed in Court', 'user-4', 'Property trespass with damage, two related incidents', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-10', 'docket-9', 'OCP-2025-010', '2025-02-08', 'Filed in Court', 'user-4', NOW()),
('case-11', 'docket-9', 'OCP-2025-011', '2025-02-09', 'Pending', NULL, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-19', 'Leonardo Fernandez', '1987-12-03', 'Male', '09221234567', 'leonardo.fernandez@email.com', 'Respondent', NOW()),
('person-20', 'Margaret Tan', '1980-04-27', 'Female', '09231234567', 'margaret.tan@email.com', 'Property owner - complainant', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-19', 'Residential', '999 Mayor Ramon St', 'Barangay Malinta', 'Valenzuela', 'Metro Manila', '1440', true, NOW()),
('person-20', 'Residential', '111 JP Rizal Ave', 'Barangay Malinta', 'Valenzuela', 'Metro Manila', '1440', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-10', 'person-19', 'respondent', NOW()),
('case-10', 'person-20', 'complainant', NOW()),
('case-11', 'person-19', 'respondent', NOW()),
('case-11', 'person-20', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-10', 'RPC Art. 280', 'Trespass to Property', 'Unlawful entry to residential compound', 'Arresto Menor', NOW()),
('vio-11', 'RPC Art. 327', 'Property Damage', 'Destruction of property during trespass', 'Prision Correccional', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-10', 'vio-10', NOW()),
('case-10', 'vio-11', NOW()),
('case-11', 'vio-10', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-10', 'Pending', 'Trespass and property damage case received', 'user-5', '2025-02-10'),
('case-10', 'For Review', 'Evidence reviewed for prosecution', 'user-4', '2025-02-12'),
('case-10', 'Filed in Court', 'Case filed in proper court', 'user-4', '2025-02-15'),
('case-11', 'Pending', 'Related incident documented', 'user-5', '2025-02-10')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-9', 'user-4', '2025-02-12', 'Assigned for prosecution', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

-- DOCKET 10: Illegal possession of firearms
INSERT INTO public.dockets (id, docket_number, docket_year, date_received, violation_summary, place_of_commission, docket_status, assigned_prosecutor_id, remarks, created_by, created_at) VALUES
('docket-10', 'DK-2025-010', 2025, '2025-02-12', 'RA 10591 - Illegal possession of firearms and ammunition', 'Residential address, Quezon City', 'Dismissed', 'user-2', 'Case dismissed due to valid LTFRB documentation presented', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.cases (id, docket_id, case_number, date_of_incident, case_status, assigned_prosecutor_id, created_at) VALUES
('case-12', 'docket-10', 'OCP-2025-012', '2025-02-10', 'Dismissed', 'user-2', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.persons (id, full_name, date_of_birth, gender, contact_number, email, remarks, created_at) VALUES
('person-21', 'Oscar Reyes', '1978-01-14', 'Male', '09241234567', 'oscar.reyes@email.com', 'Respondent - gun owner', NOW()),
('person-22', 'Police Officer Manuel Gregorio', '1982-11-20', 'Male', '09251234567', 'manuel.gregorio@pnp.gov.ph', 'Officer who filed case', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.person_addresses (person_id, address_type, street, barangay, municipality, province, zip_code, is_primary, created_at) VALUES
('person-21', 'Residential', '789 EDSA Extension', 'Barangay Culiat', 'Quezon City', 'Metro Manila', '1108', true, NOW()),
('person-22', 'Office', 'QC Police District', 'Barangay 177', 'Quezon City', 'Metro Manila', '1117', true, NOW())
ON CONFLICT (person_id, street) DO NOTHING;

INSERT INTO public.case_participants (case_id, person_id, participant_type, created_at) VALUES
('case-12', 'person-21', 'respondent', NOW()),
('case-12', 'person-22', 'complainant', NOW())
ON CONFLICT (case_id, person_id) DO NOTHING;

INSERT INTO public.violations (id, statute_citation, category, description, penalty, created_at) VALUES
('vio-12', 'RA 10591', 'Illegal Possession of Firearm', 'Illegal possession of high-powered firearm', 'Reclusion Temporal', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.case_violations (case_id, violation_id, created_at) VALUES
('case-12', 'vio-12', NOW())
ON CONFLICT (case_id, violation_id) DO NOTHING;

INSERT INTO public.case_status_updates (case_id, status, remarks, updated_by, created_at) VALUES
('case-12', 'Pending', 'Firearm possession case received', 'user-5', '2025-02-12'),
('case-12', 'For Review', 'Valid LTFRB license found during review', 'user-2', '2025-02-18'),
('case-12', 'Dismissed', 'Case dismissed - respondent has valid firearm license', 'user-2', '2025-02-20')
ON CONFLICT (case_id, status, created_at) DO NOTHING;

INSERT INTO public.prosecutor_assignments (docket_id, prosecutor_id, assigned_date, remarks, assigned_by, created_at) VALUES
('docket-10', 'user-2', '2025-02-18', 'Assigned for case evaluation', 'user-5', NOW())
ON CONFLICT (docket_id, prosecutor_id, assigned_date) DO NOTHING;

-- =====================================================
-- Clearance Search Records
-- =====================================================

INSERT INTO public.clearance_searches (id, searched_name, search_date, searched_by, remarks, created_at) VALUES
('search-1', 'Carlos Rene Santos', '2025-02-15', 'user-5', 'Staff clearance request', NOW()),
('search-2', 'Maria Luz Garcia', '2025-02-16', 'user-5', 'Employment verification', NOW()),
('search-3', 'Rosa Pilar Fernandez', '2025-02-17', 'user-5', 'Travel clearance', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.clearance_matches (id, clearance_search_id, person_id, match_type, confidence_score, created_at) VALUES
('match-1', 'search-1', 'person-1', 'exact', 0.98, NOW()),
('match-2', 'search-1', 'person-9', 'similar_name', 0.72, NOW()),
('match-3', 'search-2', 'person-2', 'exact', 0.99, NOW()),
('match-4', 'search-3', 'person-4', 'exact', 0.97, NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.clearance_reviews (id, clearance_search_id, review_decision, staff_notes, reviewed_by, review_date, created_at) VALUES
('review-1', 'search-1', 'matched_docket_record', 'Matched to docket DK-2025-001, requires supervisor verification', 'user-1', NOW(), NOW()),
('review-2', 'search-2', 'no_record_found', 'No docket records found. Clearance approved.', 'user-3', NOW(), NOW()),
('review-3', 'search-3', 'possible_match', 'Similar match found, requires manual verification', 'user-5', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- Sync Status (Local-first system status)
-- =====================================================

INSERT INTO public.sync_status (id, system_status, last_sync, pending_uploads, last_backup, offline_ready, created_at) VALUES
('sync-1', 'connected', NOW(), 0, '2025-02-20T10:00:00Z', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- Audit Logs Sample
-- =====================================================

INSERT INTO public.audit_logs (id, docket_id, case_id, action, user_id, change_details, created_at) VALUES
('log-1', 'docket-1', 'case-1', 'CASE_STATUS_UPDATED', 'user-1', 'Status changed from Pending to Filed in Court', NOW()),
('log-2', 'docket-2', 'case-3', 'DOCKET_CREATED', 'user-5', 'New docket created for theft case', NOW()),
('log-3', 'docket-3', 'case-4', 'DOCKET_ASSIGNED', 'user-5', 'Docket assigned to prosecutor user-3', NOW()),
('log-4', 'docket-5', 'case-6', 'CASE_STATUS_UPDATED', 'user-4', 'Status changed to Dismissed', NOW())
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- Extract Drafts (AI form extraction samples)
-- =====================================================

INSERT INTO public.extraction_drafts (id, source_file_name, extraction_status, extracted_data, confidence_score, review_notes, created_by, created_at) VALUES
('extract-1', 'Form_DK-2025-013.pdf', 'pending_review', '{"docket_number": "DK-2025-013", "date_received": "2025-02-20", "complainant": "John Doe", "respondent": "Jane Smith", "violation": "Simple Assault"}', 0.87, 'High confidence extraction, ready for review', 'user-5', NOW()),
('extract-2', 'Form_DK-2025-014.pdf', 'pending_review', '{"docket_number": "DK-2025-014", "date_received": "2025-02-21", "complainant": "Robert Brown", "violation": "NEEDS_REVIEW"}', 0.64, 'Requires staff review for missing fields', 'user-5', NOW())
ON CONFLICT (id) DO NOTHING;

COMMIT;
