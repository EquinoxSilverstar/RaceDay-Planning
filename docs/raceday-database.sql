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
