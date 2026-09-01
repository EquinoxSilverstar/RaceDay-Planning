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

