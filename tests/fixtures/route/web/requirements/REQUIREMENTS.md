# Requirements Document

> **Project:** workshop bookings online (route fixture)

## Functional Requirements

### REQ-F-001: Customer sign-up and log in
- **Statement:** WHEN a customer signs up with email and password on the website THE system SHALL create a customer account and open a session.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test

### REQ-F-002: Staff log in with roles
- **Statement:** WHEN a staff member logs in THE system SHALL open a session with the permissions of their role (mechanic, office manager or admin).
- **Priority:** Must have
- **Needs:** N-002
- **Verification:** test

### REQ-F-003: Book a service slot
- **Statement:** WHEN a logged-in customer picks a service, a vehicle and a free slot on the booking page THE system SHALL reserve the slot for 15 minutes while the deposit is paid.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test

### REQ-F-004: Pay the deposit by card
- **Statement:** WHEN the customer confirms the booking THE system SHALL charge the deposit to their card through the payment provider and confirm the appointment only after the provider accepts the payment.
- **Priority:** Must have
- **Needs:** N-001
- **Verification:** test

### REQ-F-005: Refund on cancellation
- **Statement:** WHEN a customer cancels an appointment more than 24 hours ahead THE system SHALL refund the deposit through the payment provider.
- **Priority:** Should have
- **Needs:** N-001
- **Verification:** test

### REQ-F-006: Mechanic day view
- **Statement:** WHEN a mechanic opens the day view THE system SHALL show today's appointments of their workshop without prices or payment data.
- **Priority:** Must have
- **Needs:** N-002
- **Verification:** test

### REQ-F-007: Payments and reports for admins
- **Statement:** WHEN an admin or office manager opens the reports page THE system SHALL show deposits, refunds and appointments per day for the chosen month.
- **Priority:** Should have
- **Needs:** N-002
- **Verification:** test

### REQ-F-008: SMS reminder
- **Statement:** WHEN an appointment starts in 24 hours THE system SHALL send an SMS reminder to the customer's phone through the SMS provider's API.
- **Priority:** Must have
- **Needs:** N-003
- **Verification:** test

### REQ-F-009: Customer records
- **Statement:** WHEN an office manager edits a customer THE system SHALL store name, phone, address and vehicle plates and record who changed them.
- **Priority:** Must have
- **Needs:** N-004
- **Verification:** test

### REQ-F-010: Personal data export and erasure
- **Statement:** WHEN a customer asks for their personal data or its erasure THE system SHALL export it or erase it within 30 days as data protection law requires.
- **Priority:** Must have
- **Needs:** N-004
- **Verification:** demo

## Nonfunctional Requirements

### REQ-NF-001: Payment page response
- **Statement:** THE system SHALL render the booking and payment pages in less than 2 seconds at the 95th percentile.
- **Priority:** Should have
- **Needs:** N-001
- **Verification:** measurement

### REQ-NF-002: Card data never stored
- **Statement:** THE system SHALL never store card numbers; card entry happens on the payment provider's hosted form.
- **Priority:** Must have
- **Needs:** N-004
- **Verification:** inspection

## Constraints

### REQ-C-001: Multi-workshop ready
- **Statement:** Every record belongs to one workshop so that a second workshop can be added without migrating data.
- **Needs:** N-005
- **Verification:** inspection
