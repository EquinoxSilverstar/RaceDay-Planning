/*
    RaceDay database schema and sample data
    Target: Microsoft SQL Server 2019 or later

    Run this file in SQL Server Management Studio while connected to a clean
    SQL Server instance. The script creates the RaceDayDb database and all
    objects/data required for the Part 1 submission.
*/

USE [master];
GO

IF DB_ID(N'RaceDayDb') IS NOT NULL
BEGIN
    THROW 50001, 'RaceDayDb already exists. Run this script on a clean SQL Server instance or remove the existing database first.', 1;
END;
GO

CREATE DATABASE [RaceDayDb];
GO

ALTER DATABASE [RaceDayDb] SET RECOVERY SIMPLE;
GO

USE [RaceDayDb];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

CREATE TABLE dbo.Users
(
    UserId          INT IDENTITY(1,1) NOT NULL,
    Email           NVARCHAR(254) NOT NULL,
    PasswordHash    NVARCHAR(255) NOT NULL,
    FirstName       NVARCHAR(80) NOT NULL,
    LastName        NVARCHAR(80) NOT NULL,
    PhoneNumber     NVARCHAR(20) NULL,
    Role            VARCHAR(20) NOT NULL,
    IsActive        BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CreatedAtUtc    DATETIME2(0) NOT NULL CONSTRAINT DF_Users_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    UpdatedAtUtc    DATETIME2(0) NULL,
    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Email_Format CHECK (Email LIKE N'%_@_%._%'),
    CONSTRAINT CK_Users_Role CHECK (Role IN ('Organiser', 'Participant'))
);
GO

CREATE TABLE dbo.ParticipantProfiles
(
    ParticipantProfileId INT IDENTITY(1,1) NOT NULL,
    UserId                INT NOT NULL,
    DateOfBirth           DATE NOT NULL,
    Gender                VARCHAR(20) NOT NULL,
    EmergencyContactName  NVARCHAR(160) NOT NULL,
    EmergencyContactPhone NVARCHAR(20) NOT NULL,
    MedicalNotes          NVARCHAR(500) NULL,
    ClubName              NVARCHAR(120) NULL,
    CONSTRAINT PK_ParticipantProfiles PRIMARY KEY CLUSTERED (ParticipantProfileId),
    CONSTRAINT UQ_ParticipantProfiles_UserId UNIQUE (UserId),
    CONSTRAINT CK_ParticipantProfiles_Gender CHECK (Gender IN ('Female', 'Male', 'Non-binary', 'Prefer not to say')),
    CONSTRAINT FK_ParticipantProfiles_Users FOREIGN KEY (UserId)
        REFERENCES dbo.Users (UserId)
);
GO

CREATE TABLE dbo.Events
(
    EventId               INT IDENTITY(1,1) NOT NULL,
    OrganiserId           INT NOT NULL,
    Name                  NVARCHAR(160) NOT NULL,
    Description           NVARCHAR(2000) NOT NULL,
    EventType             VARCHAR(20) NOT NULL,
    StartDateTime         DATETIME2(0) NOT NULL,
    EndDateTime           DATETIME2(0) NOT NULL,
    TimeZoneId            NVARCHAR(64) NOT NULL CONSTRAINT DF_Events_TimeZoneId DEFAULT (N'South Africa Standard Time'),
    VenueName             NVARCHAR(160) NOT NULL,
    AddressLine1          NVARCHAR(160) NOT NULL,
    City                  NVARCHAR(100) NOT NULL,
    Province              VARCHAR(30) NOT NULL,
    PostalCode            VARCHAR(10) NULL,
    RegistrationOpenUtc   DATETIME2(0) NOT NULL,
    RegistrationCloseUtc  DATETIME2(0) NOT NULL,
    Status                VARCHAR(20) NOT NULL CONSTRAINT DF_Events_Status DEFAULT ('Draft'),
    CreatedAtUtc          DATETIME2(0) NOT NULL CONSTRAINT DF_Events_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    UpdatedAtUtc          DATETIME2(0) NULL,
    CONSTRAINT PK_Events PRIMARY KEY CLUSTERED (EventId),
    CONSTRAINT CK_Events_EventType CHECK (EventType IN ('Running', 'Walking', 'Cycling')),
    CONSTRAINT CK_Events_Province CHECK (Province IN ('Eastern Cape', 'Free State', 'Gauteng', 'KwaZulu-Natal', 'Limpopo', 'Mpumalanga', 'Northern Cape', 'North West', 'Western Cape')),
    CONSTRAINT CK_Events_Status CHECK (Status IN ('Draft', 'Published', 'Completed', 'Cancelled')),
    CONSTRAINT CK_Events_DateRange CHECK (EndDateTime > StartDateTime),
    CONSTRAINT CK_Events_RegistrationRange CHECK (RegistrationCloseUtc > RegistrationOpenUtc),
    CONSTRAINT FK_Events_Organiser FOREIGN KEY (OrganiserId)
        REFERENCES dbo.Users (UserId)
);
GO

CREATE INDEX IX_Events_Status_StartDateTime
    ON dbo.Events (Status, StartDateTime)
    INCLUDE (Name, EventType, City, Province);
GO

CREATE TABLE dbo.Categories
(
    CategoryId       INT IDENTITY(1,1) NOT NULL,
    EventId          INT NOT NULL,
    Name             NVARCHAR(100) NOT NULL,
    Description      NVARCHAR(500) NULL,
    DistanceKm       DECIMAL(7,2) NOT NULL,
    EntryFee         DECIMAL(10,2) NOT NULL,
    Capacity         INT NOT NULL,
    MinimumAge       TINYINT NULL,
    MaximumAge       TINYINT NULL,
    CategoryStartTime TIME(0) NULL,
    IsActive         BIT NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT (1),
    CONSTRAINT PK_Categories PRIMARY KEY CLUSTERED (CategoryId),
    CONSTRAINT UQ_Categories_Event_Name UNIQUE (EventId, Name),
    CONSTRAINT UQ_Categories_Event_Category UNIQUE (EventId, CategoryId),
    CONSTRAINT CK_Categories_DistanceKm CHECK (DistanceKm > 0),
    CONSTRAINT CK_Categories_EntryFee CHECK (EntryFee >= 0),
    CONSTRAINT CK_Categories_Capacity CHECK (Capacity > 0),
    CONSTRAINT CK_Categories_MinimumAge CHECK (MinimumAge IS NULL OR MinimumAge BETWEEN 5 AND 100),
    CONSTRAINT CK_Categories_MaximumAge CHECK (MaximumAge IS NULL OR MaximumAge BETWEEN 5 AND 100),
    CONSTRAINT CK_Categories_AgeRange CHECK (MinimumAge IS NULL OR MaximumAge IS NULL OR MaximumAge >= MinimumAge),
    CONSTRAINT FK_Categories_Events FOREIGN KEY (EventId)
        REFERENCES dbo.Events (EventId)
);
GO

CREATE INDEX IX_Categories_EventId_IsActive
    ON dbo.Categories (EventId, IsActive);
GO

CREATE TABLE dbo.EventEnrollments
(
    EnrollmentId       INT IDENTITY(1,1) NOT NULL,
    EventId            INT NOT NULL,
    CategoryId         INT NOT NULL,
    ParticipantId      INT NOT NULL,
    BibNumber          NVARCHAR(20) NULL,
    Status             VARCHAR(20) NOT NULL CONSTRAINT DF_EventEnrollments_Status DEFAULT ('Pending'),
    PaymentStatus      VARCHAR(20) NOT NULL CONSTRAINT DF_EventEnrollments_PaymentStatus DEFAULT ('Pending'),
    FeePaid            DECIMAL(10,2) NOT NULL,
    EmergencyConsent   BIT NOT NULL,
    EnrolledAtUtc      DATETIME2(0) NOT NULL CONSTRAINT DF_EventEnrollments_EnrolledAtUtc DEFAULT (SYSUTCDATETIME()),
    UpdatedAtUtc       DATETIME2(0) NULL,
    CONSTRAINT PK_EventEnrollments PRIMARY KEY CLUSTERED (EnrollmentId),
    CONSTRAINT UQ_EventEnrollments_Event_Participant UNIQUE (EventId, ParticipantId),
    CONSTRAINT CK_EventEnrollments_Status CHECK (Status IN ('Pending', 'Confirmed', 'Withdrawn', 'Completed')),
    CONSTRAINT CK_EventEnrollments_PaymentStatus CHECK (PaymentStatus IN ('Pending', 'Paid', 'Waived', 'Refunded')),
    CONSTRAINT CK_EventEnrollments_FeePaid CHECK (FeePaid >= 0),
    CONSTRAINT CK_EventEnrollments_Consent CHECK (EmergencyConsent = 1),
    CONSTRAINT FK_EventEnrollments_Events FOREIGN KEY (EventId)
        REFERENCES dbo.Events (EventId),
    CONSTRAINT FK_EventEnrollments_Categories FOREIGN KEY (EventId, CategoryId)
        REFERENCES dbo.Categories (EventId, CategoryId),
    CONSTRAINT FK_EventEnrollments_Participants FOREIGN KEY (ParticipantId)
        REFERENCES dbo.Users (UserId)
);
GO

CREATE UNIQUE INDEX UX_EventEnrollments_Event_BibNumber
    ON dbo.EventEnrollments (EventId, BibNumber)
    WHERE BibNumber IS NOT NULL;
GO

CREATE INDEX IX_EventEnrollments_Participant_Status
    ON dbo.EventEnrollments (ParticipantId, Status)
    INCLUDE (EventId, CategoryId, BibNumber, EnrolledAtUtc);
GO

CREATE TABLE dbo.Results
(
    ResultId             INT IDENTITY(1,1) NOT NULL,
    EnrollmentId         INT NOT NULL,
    RecordedByOrganiserId INT NOT NULL,
    ResultStatus         VARCHAR(10) NOT NULL,
    DurationMilliseconds BIGINT NULL,
    OverallPosition      INT NULL,
    CategoryPosition     INT NULL,
    Notes                NVARCHAR(500) NULL,
    RecordedAtUtc        DATETIME2(0) NOT NULL CONSTRAINT DF_Results_RecordedAtUtc DEFAULT (SYSUTCDATETIME()),
    UpdatedAtUtc         DATETIME2(0) NULL,
    CONSTRAINT PK_Results PRIMARY KEY CLUSTERED (ResultId),
    CONSTRAINT UQ_Results_EnrollmentId UNIQUE (EnrollmentId),
    CONSTRAINT CK_Results_Status CHECK (ResultStatus IN ('Finished', 'DNF', 'DNS', 'DSQ')),
    CONSTRAINT CK_Results_Duration CHECK (DurationMilliseconds IS NULL OR DurationMilliseconds > 0),
    CONSTRAINT CK_Results_OverallPosition CHECK (OverallPosition IS NULL OR OverallPosition > 0),
    CONSTRAINT CK_Results_CategoryPosition CHECK (CategoryPosition IS NULL OR CategoryPosition > 0),
    CONSTRAINT CK_Results_FinishedValues CHECK
    (
        ResultStatus <> 'Finished'
        OR (DurationMilliseconds IS NOT NULL AND OverallPosition IS NOT NULL AND CategoryPosition IS NOT NULL)
    ),
    CONSTRAINT FK_Results_Enrollments FOREIGN KEY (EnrollmentId)
        REFERENCES dbo.EventEnrollments (EnrollmentId),
    CONSTRAINT FK_Results_RecordedByOrganiser FOREIGN KEY (RecordedByOrganiserId)
        REFERENCES dbo.Users (UserId)
);
GO

CREATE INDEX IX_Results_Status_Duration
    ON dbo.Results (ResultStatus, DurationMilliseconds)
    INCLUDE (EnrollmentId, OverallPosition, CategoryPosition);
GO

BEGIN TRY
    BEGIN TRANSACTION;

    SET IDENTITY_INSERT dbo.Users ON;

    INSERT INTO dbo.Users
        (UserId, Email, PasswordHash, FirstName, LastName, PhoneNumber, Role, IsActive)
    VALUES
        (1, N'lerato@jozievents.co.za', N'$2b$12$8JmA4mvvVZmW5sVQGJpYIuYRWXASfROVU9Yj5O6XqQ8jzL5sA1Cye', N'Lerato', N'Mokoena', N'+27 82 555 0101', 'Organiser', 1),
        (2, N'johan@capecycle.co.za', N'$2b$12$N8Lc7a0uXq4EwS1vJr6hYeKfAqWmUBG5Tz9Pn2DxCiV3oR7sH0Fke', N'Johan', N'van Wyk', N'+27 83 555 0202', 'Organiser', 1),
        (3, N'nomsa.mthembu@example.co.za', N'$2b$12$4aQzK7mL9xV2bN6sP1cDeuF0YhJgT8rW5oUiE3pAqS7dZkC2vB9Xm', N'Nomsa', N'Mthembu', N'+27 71 555 0303', 'Participant', 1),
        (4, N'ethan.jacobs@example.co.za', N'$2b$12$Z3wP8eR1tY6uI2oA9sDfGhJkL4cVbN7mQ0xC5zS6aW8dE1rT9yUiO', N'Ethan', N'Jacobs', N'+27 72 555 0404', 'Participant', 1);

    SET IDENTITY_INSERT dbo.Users OFF;

    SET IDENTITY_INSERT dbo.ParticipantProfiles ON;

    INSERT INTO dbo.ParticipantProfiles
        (ParticipantProfileId, UserId, DateOfBirth, Gender, EmergencyContactName, EmergencyContactPhone, MedicalNotes, ClubName)
    VALUES
        (1, 3, '1992-04-18', 'Female', N'Sipho Mthembu', N'+27 73 555 1313', N'Mild asthma; inhaler carried during events.', N'Durban Striders'),
        (2, 4, '1987-11-02', 'Male', N'Megan Jacobs', N'+27 76 555 1414', NULL, N'Atlantic Athletic Club');

    SET IDENTITY_INSERT dbo.ParticipantProfiles OFF;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    SET IDENTITY_INSERT dbo.Categories ON;

    INSERT INTO dbo.Categories
        (CategoryId, EventId, Name, Description, DistanceKm, EntryFee, Capacity, MinimumAge, MaximumAge, CategoryStartTime, IsActive)
    VALUES
        (1, 1, N'5 km Fun Run', N'Open community run suitable for new runners and families.', 5.00, 120.00, 500, 10, NULL, '07:30:00', 1),
        (2, 1, N'10 km Road Race', N'Timed 10 km road race.', 10.00, 220.00, 1000, 15, NULL, '07:00:00', 1),
        (3, 1, N'21.1 km Half Marathon', N'Timed half-marathon for experienced runners.', 21.10, 350.00, 1200, 18, NULL, '06:00:00', 1),
        (4, 2, N'42 km Recreational Ride', N'Supported recreational route for developing cyclists.', 42.00, 450.00, 800, 15, NULL, '07:00:00', 1),
        (5, 2, N'109 km Challenge', N'Full peninsula endurance route for experienced cyclists.', 109.00, 750.00, 1500, 18, NULL, '05:30:00', 1),
        (6, 3, N'5 km Family Walk', N'Accessible family-focused coastal walk.', 5.00, 80.00, 600, 5, NULL, '08:00:00', 1),
        (7, 3, N'10 km Fitness Walk', N'Brisk timed walking category along the promenade.', 10.00, 140.00, 500, 14, NULL, '07:30:00', 1),
        (8, 3, N'20 km Endurance Walk', N'Long-distance category for conditioned walkers.', 20.00, 200.00, 300, 18, NULL, '07:00:00', 1);

    SET IDENTITY_INSERT dbo.Categories OFF;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    SET IDENTITY_INSERT dbo.Events ON;

    INSERT INTO dbo.Events
        (EventId, OrganiserId, Name, Description, EventType, StartDateTime, EndDateTime,
         VenueName, AddressLine1, City, Province, PostalCode, RegistrationOpenUtc,
         RegistrationCloseUtc, Status)
    VALUES
        (1, 1, N'Jozi Heritage Run 2027', N'A city road race through historic Johannesburg neighbourhoods with 5 km, 10 km, and half-marathon options.',
         'Running', '2027-03-21T06:00:00', '2027-03-21T12:00:00', N'Old Parktonian Sports Club', N'1 Garden Road', N'Johannesburg', 'Gauteng', '2193',
         '2026-10-01T06:00:00', '2027-03-15T21:59:59', 'Published'),
        (2, 2, N'Cape Peninsula Cycle Tour 2027', N'A supported road-cycling event along the Cape Peninsula with recreational and endurance distances.',
         'Cycling', '2027-04-11T05:30:00', '2027-04-11T16:00:00', N'Cape Town Stadium Forecourt', N'Fritz Sonnenberg Road', N'Cape Town', 'Western Cape', '8051',
         '2026-11-01T06:00:00', '2027-04-04T21:59:59', 'Published'),
        (3, 1, N'Durban Golden Mile Community Walk 2027', N'An inclusive coastal walk supporting local charities, with family and fitness categories.',
         'Walking', '2027-05-02T07:00:00', '2027-05-02T11:00:00', N'North Beach Amphitheatre', N'Snell Parade', N'Durban', 'KwaZulu-Natal', '4001',
         '2027-01-15T06:00:00', '2027-04-28T21:59:59', 'Published');

    SET IDENTITY_INSERT dbo.Events OFF;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
