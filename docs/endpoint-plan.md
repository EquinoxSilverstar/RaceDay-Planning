# RaceDay REST API Endpoint Plan

## 1. Purpose and scope

This document is the implementation contract for the RaceDay REST API planned for Part 2. It covers authentication, user profiles, events, categories, event enrolments, and race results. Every route begins with `/api`, uses JSON, and is designed around the entities in `raceday-database.sql`.

## 2. API conventions

- **Authentication:** protected routes require `Authorization: Bearer <JWT>`.
- **Roles:** `Participant` and `Organiser` are encoded as claims in the authenticated identity. “Owner” means the current user owns the profile, enrolment, or event being changed.
- **Dates:** API timestamps use ISO 8601. UTC fields end in `Utc`; event-local fields include the event's `timeZoneId`.
- **Identifiers:** route IDs are positive integers. An invalid format returns `400 Bad Request`; a well-formed ID that does not exist returns `404 Not Found`.
- **Validation errors:** `400 Bad Request` returns RFC 7807 `application/problem+json` with a field-level `errors` object.
- **Authentication errors:** missing/invalid credentials return `401 Unauthorized`; a valid user without the required role or ownership returns `403 Forbidden`.
- **Pagination:** list routes accept `page` (default `1`) and `pageSize` (default `20`, maximum `100`) and return `{ items, page, pageSize, totalCount }`.
- **Deletion:** event/category deletion returns `409 Conflict` when dependent enrolments make deletion unsafe. The API should prefer lifecycle status changes once registrations exist.
- **Naming:** JSON uses camelCase; database-to-API mapping is explicit in the Part 2 implementation.

## 3. Shared response shapes

- **User summary:** `{ userId, email, firstName, lastName, phoneNumber, role, isActive }`
- **Event summary:** `{ eventId, name, eventType, startDateTime, timeZoneId, venueName, city, province, status }`
- **Category:** `{ categoryId, eventId, name, description, distanceKm, entryFee, capacity, minimumAge, maximumAge, categoryStartTime, isActive }`
- **Enrolment:** `{ enrollmentId, event, category, participant, bibNumber, status, paymentStatus, feePaid, enrolledAtUtc }`
- **Result:** `{ resultId, enrollmentId, event, category, participant, resultStatus, durationMilliseconds, formattedDuration, overallPosition, categoryPosition, notes, recordedAtUtc }`

The endpoint tables below are authoritative. Request bodies show required fields unless a field is marked optional.

## 4. Authentication endpoints

| HTTP method | Route | Description | Role required | Request body | Expected response |
|---|---|---|---|---|---|
| `POST` | `/api/auth/register` | Creates a participant account and its participant profile in one transaction. Email is normalised and must be unique. | None (public) | `{ email, password, firstName, lastName, phoneNumber?, dateOfBirth, gender, emergencyContactName, emergencyContactPhone, medicalNotes?, clubName? }` | `201 Created` with user summary and `Location`; `400` validation; `409` email already registered. |
| `POST` | `/api/auth/login` | Validates credentials and returns an access token containing user ID and role claims. | None (public) | `{ email, password }` | `200 OK` with `{ accessToken, expiresAtUtc, user }`; `400` validation; `401` invalid credentials or inactive account. |

Organiser accounts are provisioned by an authorised administrator or database deployment process; public registration deliberately creates participants only. This prevents privilege escalation by choosing an organiser role in a public request.

## 5. User profile endpoints

| HTTP method | Route | Description | Role required | Request body | Expected response |
|---|---|---|---|---|---|
| `GET` | `/api/profile` | Returns the current user's account data and, for a participant, the linked participant profile. | Any authenticated user | None | `200 OK` with `{ user, participantProfile? }`; `401` unauthenticated. |
| `PUT` | `/api/profile` | Replaces editable current-user details. Participant-only fields update the linked profile in the same transaction. Role, email, and active status cannot be changed here. | Any authenticated user (self) | `{ firstName, lastName, phoneNumber?, participantProfile?: { dateOfBirth, gender, emergencyContactName, emergencyContactPhone, medicalNotes?, clubName? } }` | `200 OK` with updated profile; `400` validation; `401` unauthenticated. |
| `PUT` | `/api/profile/email` | Changes the current user's sign-in email after password confirmation. | Any authenticated user (self) | `{ newEmail, currentPassword }` | `200 OK` with updated user summary; `400` validation; `401` password invalid; `409` email already registered. |
| `PUT` | `/api/profile/password` | Changes the current user's password and stores only a new secure password hash. | Any authenticated user (self) | `{ currentPassword, newPassword }` | `204 No Content`; `400` password policy failure; `401` current password invalid. |

