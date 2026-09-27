# Requirements Document

> **Project:** workshop bookings (plan-vertical fixture)

## Functional Requirements

### REQ-F-001: Log in
- **Statement:** WHEN a staff member submits valid credentials THE system SHALL open a session for their role.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN an active staff account WHEN they submit the right password THEN the customer list opens
  - GIVEN any account WHEN the password is wrong THEN the message `Invalid email or password` is shown and no session opens

### REQ-F-002: Register and list customers
- **Statement:** WHEN a staff member registers a customer THE system SHALL store it and show it in the customer list.
- **Priority:** Must have
- **Needs:** N-002
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN a logged-in staff member WHEN they register Ana Ruiz with phone 600111222 THEN Ana Ruiz appears in the list after a reload
  - GIVEN a logged-in staff member WHEN the name is empty THEN `Name is required` is shown
  - GIVEN no session WHEN the customer list is requested THEN the login page opens

### REQ-F-003: Edit and delete customers
- **Statement:** WHEN a staff member edits or deletes a customer THE system SHALL update the stored customer.
- **Priority:** Must have
- **Needs:** N-002
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN customer Ana Ruiz WHEN her phone is changed to 600333444 THEN the list shows 600333444
  - GIVEN a customer without vehicles WHEN it is deleted THEN it leaves the list

### REQ-F-004: Manage vehicles
- **Statement:** WHEN a staff member adds, edits or removes a vehicle of a customer THE system SHALL keep the customer's vehicle list.
- **Priority:** Must have
- **Needs:** N-003
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN customer Ana Ruiz WHEN plate 1234-ABC is added THEN it appears in her vehicles
  - GIVEN plate 1234-ABC exists WHEN it is added again THEN `Plate already registered` is shown

### REQ-F-005: Manage appointments
- **Statement:** WHEN a staff member books, moves or cancels an appointment for a vehicle THE system SHALL keep the workshop calendar.
- **Priority:** Must have
- **Needs:** N-004
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN vehicle 1234-ABC WHEN an appointment is booked for 2026-10-05 09:00 THEN it appears in the calendar
  - GIVEN a booked slot WHEN another appointment is booked in it THEN `Slot taken` is shown
  - GIVEN an appointment WHEN it is cancelled THEN the slot is free

### REQ-F-006: Monthly report for admins
- **Statement:** WHEN an admin opens the monthly report THE system SHALL show appointments per day for the month.
- **Priority:** Should have
- **Needs:** N-005
- **Verification:** test
- **Acceptance criteria:**
  - GIVEN 3 appointments on 2026-10-05 WHEN an admin opens October THEN day 5 shows 3
  - GIVEN a staff member without the admin role WHEN they open the report THEN access is denied

## Nonfunctional Requirements

### REQ-NF-001: Appointment list latency
- **Statement:** THE system SHALL render the appointment list with 10,000 appointments in under 300 ms p95.
- **Priority:** Should have
- **Needs:** N-004
- **Verification:** measurement
- **Acceptance criteria:**
  - GIVEN 10,000 appointments WHEN the list is loaded 50 times THEN p95 is under 300 ms

## Constraints

### REQ-C-001: Runtime
- **Statement:** The system runs on Rails 8 with SQLite.
- **Needs:** — (team)
- **Verification:** inspection
