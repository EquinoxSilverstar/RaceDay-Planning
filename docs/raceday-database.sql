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

