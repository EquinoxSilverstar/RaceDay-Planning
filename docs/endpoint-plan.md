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

## 6. Event endpoints

| HTTP method | Route | Description | Role required | Request body | Expected response |
|---|---|---|---|---|---|
| `GET` | `/api/events` | Browses events. Supports `search`, `eventType`, `province`, `city`, `from`, `to`, `status`, `page`, and `pageSize`. Anonymous users see published/completed events only. | None (public) | None | `200 OK` with paginated event summaries; `400` invalid filter or date range. |
| `GET` | `/api/events/{eventId}` | Returns full event details, category links, registration state, and available places. Draft events are visible only to their organiser. | Public for published/completed events; owning Organiser for drafts | None | `200 OK` with event detail; `403` inaccessible draft; `404` event not found. |
| `GET` | `/api/organiser/events` | Lists all events owned by the current organiser, including drafts and cancelled events. Supports status and pagination filters. | Organiser | None | `200 OK` with paginated event summaries; `401`; `403`. |
| `POST` | `/api/events` | Creates an event owned by the current organiser. It starts as `Draft`; categories are added separately. | Organiser | `{ name, description, eventType, startDateTime, endDateTime, timeZoneId, venueName, addressLine1, city, province, postalCode?, registrationOpenUtc, registrationCloseUtc }` | `201 Created` with event detail and `Location`; `400` validation; `401`; `403`. |
| `PUT` | `/api/events/{eventId}` | Replaces editable event details. A completed or cancelled event cannot be edited. | Organiser (event owner) | Same fields as event creation | `200 OK` with updated event; `400` validation; `403` not owner; `404`; `409` invalid lifecycle state. |
| `PATCH` | `/api/events/{eventId}/status` | Performs a valid lifecycle transition: Draft → Published, Published → Completed/Cancelled. Publishing requires at least one active category. | Organiser (event owner) | `{ status }` | `200 OK` with updated event; `400` unsupported status; `403`; `404`; `409` invalid transition or no category. |
| `DELETE` | `/api/events/{eventId}` | Deletes an unneeded draft only when it has no enrolments. | Organiser (event owner) | None | `204 No Content`; `403`; `404`; `409` not a draft or has enrolments. |

## 7. Category endpoints

| HTTP method | Route | Description | Role required | Request body | Expected response |
|---|---|---|---|---|---|
| `GET` | `/api/events/{eventId}/categories` | Lists active categories for an event; the owner may include inactive categories with `includeInactive=true`. | Public; Organiser owner for inactive records | None | `200 OK` with category array; `403` inaccessible draft/inactive data; `404` event not found. |
| `GET` | `/api/categories/{categoryId}` | Returns one category and current capacity availability. | Public when parent event is visible | None | `200 OK` with category; `403` inaccessible parent event; `404` category not found. |
| `POST` | `/api/events/{eventId}/categories` | Adds a category to a draft or published event. | Organiser (event owner) | `{ name, description?, distanceKm, entryFee, capacity, minimumAge?, maximumAge?, categoryStartTime?, isActive }` | `201 Created` with category and `Location`; `400` validation; `403`; `404` event; `409` duplicate name or completed/cancelled event. |
| `PUT` | `/api/categories/{categoryId}` | Replaces category details. Capacity cannot be reduced below confirmed enrolments. | Organiser (event owner) | Same fields as category creation | `200 OK` with updated category; `400`; `403`; `404`; `409` capacity/lifecycle conflict. |
| `DELETE` | `/api/categories/{categoryId}` | Deletes a category only when it has no enrolments; otherwise it can be deactivated using `PUT`. | Organiser (event owner) | None | `204 No Content`; `403`; `404`; `409` category has enrolments. |

## 8. Event enrolment endpoints

| HTTP method | Route | Description | Role required | Request body | Expected response |
|---|---|---|---|---|---|
| `POST` | `/api/events/{eventId}/enrollments` | Enters the current participant in one category. The API checks registration dates, event/category status, age eligibility, capacity, and the one-enrolment-per-event rule. The category's current fee is copied to `feePaid`. | Participant | `{ categoryId, emergencyConsent }` | `201 Created` with enrolment and `Location`; `400` eligibility/consent validation; `401`; `403`; `404`; `409` already entered or category full. |
| `GET` | `/api/enrollments/me` | Lists the current participant's upcoming and past enrolments. Supports `status`, `from`, `to`, and pagination. | Participant | None | `200 OK` with paginated enrolments; `400` invalid filters; `401`; `403`. |
| `GET` | `/api/enrollments/{enrollmentId}` | Returns one enrolment. Participants may view their own; the event owner may view any enrolment in that event. | Participant (self) or Organiser (event owner) | None | `200 OK` with enrolment; `403` not owner; `404` not found. |
| `PATCH` | `/api/enrollments/{enrollmentId}/withdraw` | Withdraws the current participant before registration closes. A completed or already withdrawn entry cannot be changed. | Participant (self) | `{ reason? }` | `200 OK` with status `Withdrawn`; `403` not owner; `404`; `409` deadline/lifecycle conflict. |
| `GET` | `/api/events/{eventId}/enrollments` | Lists all event enrolments for administration. Supports `categoryId`, `status`, `paymentStatus`, `search`, and pagination. | Organiser (event owner) | None | `200 OK` with paginated enrolments; `400` filters; `403`; `404` event. |
| `PATCH` | `/api/enrollments/{enrollmentId}` | Updates organiser-controlled fields such as bib number, enrolment status, and payment status. | Organiser (event owner) | `{ bibNumber?, status?, paymentStatus? }` | `200 OK` with updated enrolment; `400`; `403`; `404`; `409` duplicate bib or invalid transition. |

## 9. Result endpoints

| HTTP method | Route | Description | Role required | Request body | Expected response |
|---|---|---|---|---|---|
| `GET` | `/api/events/{eventId}/results` | Lists official event results. Supports `categoryId`, `resultStatus`, participant search, and pagination; defaults to finishers ordered by duration. | None (public for completed events) | None | `200 OK` with paginated results; `400` filters; `403` event results not public; `404` event. |
| `GET` | `/api/results/{resultId}` | Returns one official result with participant, event, and category summaries. | None (public for completed events) | None | `200 OK` with result; `403` not public; `404` result. |
| `GET` | `/api/results/me` | Returns the current participant's personal performance history across completed events. | Participant | None | `200 OK` with paginated results; `401`; `403`. |
| `POST` | `/api/enrollments/{enrollmentId}/result` | Captures the sole official result for an event enrolment. Finished results require duration and both positions; DNF/DNS/DSQ results may omit them. | Organiser (event owner) | `{ resultStatus, durationMilliseconds?, overallPosition?, categoryPosition?, notes? }` | `201 Created` with result and `Location`; `400` inconsistent result fields; `403`; `404` enrolment; `409` result already exists or event not completed. |
| `PUT` | `/api/results/{resultId}` | Replaces an official result while preserving its enrolment link and recording organiser. | Organiser (event owner) | `{ resultStatus, durationMilliseconds?, overallPosition?, categoryPosition?, notes? }` | `200 OK` with updated result; `400`; `403`; `404`; `409` locked event. |
| `DELETE` | `/api/results/{resultId}` | Removes an incorrectly captured result during the organiser's correction window. | Organiser (event owner) | None | `204 No Content`; `403`; `404`; `409` correction window closed. |

## 10. Cross-cutting business rules

1. A `Participant` user must have exactly one participant profile; an `Organiser` must not use participant enrolment routes.
2. An organiser can mutate only events they own and the categories, enrolments, and results beneath those events.
3. An event can be published only with valid dates and at least one active category.
4. A participant may enter an event once. Their selected category must belong to that event.
5. The accepted entry fee is copied from the category when the enrolment is created, preserving a historical amount if the category price later changes.
6. Database constraints provide the final defence for unique emails, event/category ownership, duplicate event entry, duplicate bibs, and one result per enrolment.
7. API deletion rules intentionally avoid cascading deletes so assessed and operational history is not lost accidentally.

