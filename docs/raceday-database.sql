-- Create database
CREATE DATABASE RaceDayDb;
GO

USE RaceDayDb;
GO

-- All app users
CREATE TABLE Users
(
    UserId       INT IDENTITY(1,1) PRIMARY KEY,
    Email        NVARCHAR(254) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    FirstName    NVARCHAR(80) NOT NULL,
    LastName     NVARCHAR(80) NOT NULL,
    PhoneNumber  NVARCHAR(20) NULL,
    Role         VARCHAR(20) NOT NULL,          -- Organiser or Participant
    IsActive     BIT NOT NULL DEFAULT 1,
    CreatedAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Participant-only details
CREATE TABLE ParticipantProfiles
(
    ParticipantProfileId INT IDENTITY(1,1) PRIMARY KEY,
    UserId                INT NOT NULL UNIQUE REFERENCES Users(UserId),   -- links to Users
    DateOfBirth           DATE NOT NULL,
    Gender                VARCHAR(20) NOT NULL,
    EmergencyContactName  NVARCHAR(160) NOT NULL,
    EmergencyContactPhone NVARCHAR(20) NOT NULL,
    ClubName              NVARCHAR(120) NULL
);
GO

-- Races created by organisers
CREATE TABLE Events
(
    EventId       INT IDENTITY(1,1) PRIMARY KEY,
    OrganiserId   INT NOT NULL REFERENCES Users(UserId),    -- links to Users
    Name          NVARCHAR(160) NOT NULL,
    Description   NVARCHAR(2000) NOT NULL,
    EventType     VARCHAR(20) NOT NULL,          -- Running, Walking, Cycling
    StartDateTime DATETIME2 NOT NULL,
    EndDateTime   DATETIME2 NOT NULL,
    VenueName     NVARCHAR(160) NOT NULL,
    City          NVARCHAR(100) NOT NULL,
    Status        VARCHAR(20) NOT NULL DEFAULT 'Draft'   -- current stage
);
GO

-- Distance options per event
CREATE TABLE Categories
(
    CategoryId INT IDENTITY(1,1) PRIMARY KEY,
    EventId    INT NOT NULL REFERENCES Events(EventId),   -- links to Events
    Name       NVARCHAR(100) NOT NULL,
    DistanceKm DECIMAL(7,2) NOT NULL,
    EntryFee   DECIMAL(10,2) NOT NULL,
    Capacity   INT NOT NULL
);
GO

-- Participant signups
CREATE TABLE EventEnrollments
(
    EnrollmentId  INT IDENTITY(1,1) PRIMARY KEY,
    EventId       INT NOT NULL REFERENCES Events(EventId),         -- links to Events
    CategoryId    INT NOT NULL REFERENCES Categories(CategoryId),  -- links to Categories
    ParticipantId INT NOT NULL REFERENCES Users(UserId),           -- links to Users
    BibNumber     NVARCHAR(20) NULL,
    Status        VARCHAR(20) NOT NULL DEFAULT 'Pending',    -- signup state
    FeePaid       DECIMAL(10,2) NOT NULL,
    EnrolledAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- Race outcomes
CREATE TABLE Results
(
    ResultId              INT IDENTITY(1,1) PRIMARY KEY,
    EnrollmentId          INT NOT NULL UNIQUE REFERENCES EventEnrollments(EnrollmentId),  -- links to EventEnrollments
    RecordedByOrganiserId INT NOT NULL REFERENCES Users(UserId),  -- links to Users
    ResultStatus          VARCHAR(10) NOT NULL,   -- Finished, DNF, DNS, DSQ
    DurationMilliseconds  BIGINT NULL,
    OverallPosition       INT NULL,
    RecordedAtUtc         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

--  sample users
INSERT INTO Users (Email, PasswordHash, FirstName, LastName, Role)
VALUES
    ('lerato@jozievents.co.za', 'hash1', 'Lerato', 'Mokoena', 'Organiser'),
    ('nomsa@example.co.za', 'hash2', 'Nomsa', 'Mthembu', 'Participant');

-- participant profile
INSERT INTO ParticipantProfiles (UserId, DateOfBirth, Gender, EmergencyContactName, EmergencyContactPhone)
SELECT UserId, '1992-04-18', 'Female', 'Sipho Mthembu', '+27 73 555 1313'
FROM Users WHERE Email = 'nomsa@example.co.za';

-- Added event
INSERT INTO Events (OrganiserId, Name, Description, EventType, StartDateTime, EndDateTime, VenueName, City, Status)
SELECT UserId, 'Jozi Heritage Run 2026', 'A city road race through Johannesburg.', 'Running',
       '2026-03-21T06:00:00', '2026-03-21T12:00:00', 'Old Parktonian Sports Club', 'Johannesburg', 'Published'
FROM Users WHERE Email = 'lerato@jozievents.co.za';

-- category
INSERT INTO Categories (EventId, Name, DistanceKm, EntryFee, Capacity)
SELECT EventId, '10 km Road Race', 10.00, 220.00, 1000
FROM Events WHERE Name = 'Jozi Heritage Run 2026';

--  sample enrollment
INSERT INTO EventEnrollments (EventId, CategoryId, ParticipantId, Status, FeePaid)
SELECT e.EventId, c.CategoryId, u.UserId, 'Confirmed', 220.00
FROM Events e
JOIN Categories c ON c.EventId = e.EventId
JOIN Users u ON u.Email = 'nomsa@example.co.za'
WHERE e.Name = 'Jozi Heritage Run 2026';

-- Verified inserted data
SELECT * FROM Users;
SELECT * FROM Events;
SELECT * FROM Categories;
SELECT * FROM EventEnrollments;
