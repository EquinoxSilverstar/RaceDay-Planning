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
