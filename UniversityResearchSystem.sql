USE [UniversityResearchSystem];
GO

SET NOCOUNT ON;
GO

-- Q1: Researchers and projects, including researchers with no project

SELECT r.ResearcherId, r.FirstName, r.LastName, p.ProjectId, p.Title AS ProjectTitle
FROM dbo.Researcher AS r
LEFT JOIN dbo.WorksOn AS w ON w.ResearcherId = r.ResearcherId
LEFT JOIN dbo.ResearchProject AS p ON p.ProjectId = w.ProjectId;
GO

-- Q2: Projects with leader full name/email, only projects having >= 1 grant

SELECT p.ProjectId, p.Title,
       CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS LeaderFullName,
       r.Email
FROM dbo.ResearchProject AS p
JOIN dbo.Researcher AS r ON r.ResearcherId = p.LeadResearcherId
WHERE EXISTS (SELECT 1 FROM dbo.Grants AS g WHERE g.ProjectId = p.ProjectId);
GO

-- Q3: Every possible researcher/publication combination (CROSS JOIN).

SELECT r.ResearcherId, r.FirstName, r.LastName, p.PublicationId, p.Title
FROM dbo.Researcher AS r
CROSS JOIN dbo.Publication AS p;
GO

-- Q4: Supervisors and supervised researchers with date and role.

SELECT sup.ResearcherId AS SupervisorId,
       CONCAT_WS(' ', sup.FirstName, sup.LastName) AS SupervisorName,
       sub.ResearcherId AS SupervisedResearcherId,
       CONCAT_WS(' ', sub.FirstName, sub.LastName) AS SupervisedName,
       s.StartDate, s.Role
FROM dbo.Supervision AS s
JOIN dbo.Researcher AS sup ON sup.ResearcherId = s.SupervisorId
JOIN dbo.Researcher AS sub ON sub.ResearcherId = s.ResearcherId;
GO

-- Q5: Published researchers not currently working on an Active project

SELECT r.ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher AS r
WHERE EXISTS (SELECT 1 FROM dbo.ResearcherPublication rp
              WHERE rp.ResearcherId = r.ResearcherId)
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.WorksOn w
      JOIN dbo.ResearchProject p ON p.ProjectId = w.ProjectId
      WHERE w.ResearcherId = r.ResearcherId AND p.Status = 'Active'
  );
GO

-- Q6: Top five citation levels, including ties with the fifth-highest citation count

SELECT TOP (5) WITH TIES PublicationId, Title, PublicationType, CitationCount
FROM dbo.Publication
ORDER BY CitationCount DESC;
GO

-- Q7: Page 2, 10 researchers per page

SELECT ResearcherId, FirstName, LastName, Email
FROM dbo.Researcher
ORDER BY LastName, FirstName, ResearcherId
OFFSET 10 ROWS FETCH NEXT 10 ROWS ONLY;
GO

-- Q8: TOP vs OFFSET-FETCH

SELECT TOP (3) * FROM dbo.Researcher ORDER BY LastName, ResearcherId;
SELECT * FROM dbo.Researcher ORDER BY LastName, ResearcherId
OFFSET 0 ROWS FETCH NEXT 3 ROWS ONLY;
GO

-- Q9: Sequential index per building, oldest to youngest

SELECT ResearcherId, FirstName, LastName, Building, DOB,
       ROW_NUMBER() OVER (PARTITION BY Building ORDER BY DOB ASC, ResearcherId) AS BuildingRowNumber
FROM dbo.Researcher;
GO

-- Q10: Rank publications within publication type

SELECT Title, PublicationType, CitationCount,
       RANK() OVER (PARTITION BY PublicationType ORDER BY CitationCount DESC) AS CitationRank
FROM dbo.Publication;
GO

-- Q11: Project budget ranking by status.

SELECT ProjectId, Title, Status, Budget,
       RANK() OVER (PARTITION BY Status ORDER BY Budget DESC) AS BudgetRankWithGaps,
       DENSE_RANK() OVER (PARTITION BY Status ORDER BY Budget DESC) AS BudgetRankWithoutGaps
FROM dbo.ResearchProject;
GO

-- Q12: Four groups based on publication count

WITH PublicationCounts AS (
    SELECT r.ResearcherId, r.FirstName, r.LastName,
           COUNT(rp.PublicationId) AS PublicationCount
    FROM dbo.Researcher r
    LEFT JOIN dbo.ResearcherPublication rp ON rp.ResearcherId = r.ResearcherId
    GROUP BY r.ResearcherId, r.FirstName, r.LastName
)
SELECT ResearcherId, CONCAT_WS(' ', FirstName, LastName) AS ResearcherName,
       PublicationCount,
       NTILE(4) OVER (ORDER BY PublicationCount, ResearcherId) AS GroupNumber
FROM PublicationCounts;
GO

-- Q13: Logical order (conceptual):

GO

-- Q14: Aggregate aliases cannot be used in WHERE. Use HAVING.

SELECT ResearcherId, COUNT(*) AS ProjectCount
FROM dbo.WorksOn
GROUP BY ResearcherId
HAVING COUNT(*) > 2;
GO

-- Q15: Full name, lowercase email, age in years

SELECT CONCAT_WS(' ', FirstName, MiddleName, LastName) AS FullName,
       LOWER(Email) AS LowercaseEmail,
       DATEDIFF(YEAR, DOB, GETDATE())
         - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, DOB, GETDATE()), DOB) > GETDATE()
                THEN 1 ELSE 0 END AS AgeYears
FROM dbo.Researcher;
GO

-- Q16: Project duration in days; start month/year

SELECT ProjectId, Title,
       DATEDIFF(DAY, StartDate, COALESCE(EndDate, CAST(GETDATE() AS date))) AS DurationDays,
       MONTH(StartDate) AS StartMonth,
       YEAR(StartDate) AS StartYear
FROM dbo.ResearchProject;
GO

-- Q17: Email domain

SELECT *
FROM dbo.Researcher
WHERE LOWER(SUBSTRING(Email, CHARINDEX('@', Email) + 1, LEN(Email))) = 'university.edu';
GO

-- Q18: Replace missing MiddleName / RoomNumber with N/A

SELECT ResearcherId, FirstName,
       COALESCE(NULLIF(MiddleName, ''), 'N/A') AS MiddleName,
       LastName, Email,
       COALESCE(CONVERT(varchar(50), RoomNumber), 'N/A') AS RoomNumber
FROM dbo.Researcher;
GO

-- Q19: Budget categories

SELECT ProjectId, Title, Budget,
       CASE WHEN Budget < 50000 THEN 'Small'
            WHEN Budget <= 150000 THEN 'Medium'
            ELSE 'Large' END AS BudgetCategory
FROM dbo.ResearchProject;
GO

-- Q20: Total budget per researcher leading at least one project

SELECT r.ResearcherId, CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS FullName,
       SUM(p.Budget) AS TotalBudget
FROM dbo.Researcher r
JOIN dbo.ResearchProject p ON p.LeadResearcherId = r.ResearcherId
GROUP BY r.ResearcherId, r.FirstName, r.MiddleName, r.LastName;
GO

-- Q21: Buildings with more than 3 researchers

SELECT Building, COUNT(*) AS ResearcherCount
FROM dbo.Researcher
GROUP BY Building
HAVING COUNT(*) > 3;
GO

-- Q22: Stats by publication type, average > 50

SELECT PublicationType, AVG(CAST(CitationCount AS decimal(18,2))) AS AverageCitations,
       SUM(CitationCount) AS TotalCitations, COUNT(*) AS PublicationCount
FROM dbo.Publication
GROUP BY PublicationType
HAVING AVG(CAST(CitationCount AS decimal(18,2))) > 50;
GO

-- Q23: More than 2 projects AND more than 60 total weekly hours

SELECT ResearcherId, COUNT(*) AS ProjectCount, SUM(HoursPerWeek) AS TotalHours
FROM dbo.WorksOn
GROUP BY ResearcherId
HAVING COUNT(*) > 2 AND SUM(HoursPerWeek) > 60;
GO

-- Q24: Projects above average budget

SELECT ProjectId, Title, Budget
FROM dbo.ResearchProject
WHERE Budget > (SELECT AVG(Budget) FROM dbo.ResearchProject);
GO

-- Q25: Researchers with more publications than average for their own building

WITH ResearcherPubCount AS (
    SELECT r.ResearcherId, r.FirstName, r.LastName, r.Building,
           COUNT(rp.PublicationId) AS PubCount
    FROM dbo.Researcher r
    LEFT JOIN dbo.ResearcherPublication rp ON rp.ResearcherId = r.ResearcherId
    GROUP BY r.ResearcherId, r.FirstName, r.LastName, r.Building
)
SELECT rpc.*
FROM ResearcherPubCount rpc
WHERE rpc.PubCount > (
    SELECT AVG(CAST(other.PubCount AS decimal(18,2)))
    FROM ResearcherPubCount other
    WHERE (other.Building = rpc.Building)
       OR (other.Building IS NULL AND rpc.Building IS NULL)
);
GO

-- Q26: Researchers supervising at least one other researcher

SELECT r.ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher r
WHERE EXISTS (SELECT 1 FROM dbo.Researcher sub WHERE sub.SupervisorId = r.ResearcherId);
GO

-- Q27: Each project and number of researchers

SELECT p.ProjectId, p.Title,
       (SELECT COUNT(*) FROM dbo.WorksOn w WHERE w.ProjectId = p.ProjectId) AS ResearcherCount
FROM dbo.ResearchProject p;
GO

-- Q28: Second-highest DISTINCT budget, without OFFSET or ranking

SELECT MAX(Budget) AS SecondHighestBudget
FROM dbo.ResearchProject
WHERE Budget < (SELECT MAX(Budget) FROM dbo.ResearchProject);
GO

-- Q29: Combine researcher emails and grant funding agencies

SELECT Email AS [Contact Information] FROM dbo.Researcher
UNION
SELECT FundingAgency AS [Contact Information] FROM dbo.Grants;
GO

-- Q30: Researchers involved in projects who have not authored publications

SELECT DISTINCT r.ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher r
JOIN dbo.WorksOn w ON w.ResearcherId = r.ResearcherId
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.ResearcherPublication rp
    WHERE rp.ResearcherId = r.ResearcherId
);
GO

-- Q31: Researchers who supervise others and lead projects

SELECT DISTINCT r.ResearcherId, r.FirstName, r.LastName
FROM dbo.Researcher r
WHERE EXISTS (SELECT 1 FROM dbo.Researcher sub WHERE sub.SupervisorId = r.ResearcherId)
  AND EXISTS (SELECT 1 FROM dbo.ResearchProject p WHERE p.LeadResearcherId = r.ResearcherId);
GO

-- Q32: CTE total weekly hours > 40

WITH ResearcherHours AS (
    SELECT ResearcherId, SUM(HoursPerWeek) AS TotalHoursPerWeek
    FROM dbo.WorksOn
    GROUP BY ResearcherId
)
SELECT r.ResearcherId, r.FirstName, r.LastName, h.TotalHoursPerWeek
FROM ResearcherHours h
JOIN dbo.Researcher r ON r.ResearcherId = h.ResearcherId
WHERE h.TotalHoursPerWeek > 40;
GO

-- Q33: Multiple CTEs: lead budget > 100000 and at least 3 publications

WITH LeadBudgets AS (
    SELECT LeadResearcherId AS ResearcherId, SUM(Budget) AS TotalBudget
    FROM dbo.ResearchProject
    GROUP BY LeadResearcherId
),
PublicationCounts AS (
    SELECT r.ResearcherId, COUNT(rp.PublicationId) AS PublicationCount
    FROM dbo.Researcher r
    LEFT JOIN dbo.ResearcherPublication rp ON rp.ResearcherId = r.ResearcherId
    GROUP BY r.ResearcherId
)
SELECT r.ResearcherId, CONCAT_WS(' ', r.FirstName, r.MiddleName, r.LastName) AS FullName,
       lb.TotalBudget, pc.PublicationCount
FROM LeadBudgets lb
JOIN PublicationCounts pc ON pc.ResearcherId = lb.ResearcherId
JOIN dbo.Researcher r ON r.ResearcherId = lb.ResearcherId
WHERE lb.TotalBudget > 100000 AND pc.PublicationCount >= 3;
GO

-- Question 34: Project active days function

CREATE OR ALTER FUNCTION dbo.fn_ProjectActiveDays (@ProjectId varchar(50))
RETURNS int
AS
BEGIN
    DECLARE @Days int;
    SELECT @Days = DATEDIFF(DAY, StartDate, COALESCE(EndDate, CAST(GETDATE() AS date)))
    FROM dbo.ResearchProject
    WHERE ProjectId = @ProjectId;
    RETURN @Days;
END;
GO

-- Question 34: Researcher projects function

CREATE OR ALTER FUNCTION dbo.fn_ResearcherProjects (@ResearcherId int)
RETURNS TABLE
AS
RETURN
(
    SELECT p.ProjectId, p.Title AS ProjectTitle, w.Role, w.HoursPerWeek
    FROM dbo.WorksOn w
    JOIN dbo.ResearchProject p ON p.ProjectId = w.ProjectId
    WHERE w.ResearcherId = @ResearcherId
);
GO

-- Question 34: Researcher summary function

CREATE OR ALTER FUNCTION dbo.fn_ResearcherSummary (@ResearcherId int)
RETURNS TABLE
AS
RETURN
(
    SELECT r.ResearcherId,
           (SELECT COUNT(*) FROM dbo.WorksOn w WHERE w.ResearcherId = r.ResearcherId) AS TotalProjects,
           (SELECT COUNT(*) FROM dbo.ResearcherPublication rp WHERE rp.ResearcherId = r.ResearcherId) AS TotalPublications,
           COALESCE((SELECT SUM(w.HoursPerWeek) FROM dbo.WorksOn w WHERE w.ResearcherId = r.ResearcherId), 0) AS TotalHoursPerWeek,
           (SELECT AVG(CAST(p.CitationCount AS decimal(18,2)))
            FROM dbo.ResearcherPublication rp
            JOIN dbo.Publication p ON p.PublicationId = rp.PublicationId
            WHERE rp.ResearcherId = r.ResearcherId) AS AverageCitationsPerPublication
    FROM dbo.Researcher r
    WHERE r.ResearcherId = @ResearcherId
);
GO

-- Question 35: Nonclustered index on ResearchProject

CREATE NONCLUSTERED INDEX IX_ResearchProject_Status_StartDate
ON dbo.ResearchProject (Status, StartDate DESC)
INCLUDE (ProjectId, Title, LeadResearcherId, Budget, EndDate);
GO

-- Question 36: Covering index on Researcher Email

CREATE NONCLUSTERED INDEX IX_Researcher_Email_Covering
ON dbo.Researcher (Email)
INCLUDE (FirstName, LastName);
GO

-- Question 37: ActiveProjectSummary view

CREATE OR ALTER VIEW dbo.ActiveProjectSummary
AS
SELECT p.ProjectId, p.Title AS ProjectTitle,
       CONCAT_WS(' ', leader.FirstName, leader.LastName) AS LeaderName,
       COUNT(DISTINCT w.ResearcherId) AS TeamMemberCount,
       COALESCE(SUM(w.HoursPerWeek), 0) AS TotalHoursPerWeek,
       p.Budget AS TotalBudget
FROM dbo.ResearchProject p
JOIN dbo.Researcher leader ON leader.ResearcherId = p.LeadResearcherId
LEFT JOIN dbo.WorksOn w ON w.ProjectId = p.ProjectId
WHERE p.Status = 'Active'
GROUP BY p.ProjectId, p.Title, leader.FirstName, leader.LastName, p.Budget;
GO

-- Question 38: ResearcherPublicationStats indexed view

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
SET NUMERIC_ROUNDABORT OFF;
GO

CREATE OR ALTER VIEW dbo.ResearcherPublicationStats
WITH SCHEMABINDING
AS
SELECT r.ResearcherId,
       COUNT_BIG(*) AS PublicationCount
FROM dbo.Researcher AS r
JOIN dbo.ResearcherPublication AS rp ON rp.ResearcherId = r.ResearcherId
GROUP BY r.ResearcherId;
GO

CREATE UNIQUE CLUSTERED INDEX CIX_ResearcherPublicationStats
ON dbo.ResearcherPublicationStats (ResearcherId);
GO

GO

-- Question 39: AddResearcherToProject stored procedure

CREATE OR ALTER PROCEDURE dbo.AddResearcherToProject
    @ResearcherId int,
    @ProjectId varchar(50),
    @JoinDate date,
    @Role varchar(50),
    @HoursPerWeek decimal(6,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Researcher WHERE ResearcherId = @ResearcherId)
            THROW 50001, 'Researcher does not exist.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.ResearchProject WHERE ProjectId = @ProjectId)
            THROW 50002, 'Project does not exist.', 1;
        IF EXISTS (SELECT 1 FROM dbo.WorksOn WHERE ResearcherId = @ResearcherId AND ProjectId = @ProjectId)
            THROW 50003, 'Researcher is already assigned to this project.', 1;

        INSERT INTO dbo.WorksOn (ResearcherId, ProjectId, JoinDate, Role, HoursPerWeek)
        VALUES (@ResearcherId, @ProjectId, @JoinDate, @Role, @HoursPerWeek);
        RETURN 0;
    END TRY
    BEGIN CATCH
        RETURN -1;
    END CATCH
END;
GO

-- Question 40: UpdateProjectStatus stored procedure

CREATE OR ALTER PROCEDURE dbo.UpdateProjectStatus
    @ProjectId varchar(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1 FROM dbo.ResearchProject
            WHERE ProjectId = @ProjectId AND Status = 'Pending'
        )
            THROW 50010, 'Project does not exist or is not Pending.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.WorksOn WHERE ProjectId = @ProjectId)
            THROW 50011, 'Project must have at least one researcher assigned.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Grants WHERE ProjectId = @ProjectId)
            THROW 50012, 'Project must have at least one grant.', 1;

        UPDATE dbo.ResearchProject
        SET Status = 'Active'
        WHERE ProjectId = @ProjectId AND Status = 'Pending';
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Question 41: Researcher statistics procedure with OUTPUT parameters

CREATE OR ALTER PROCEDURE dbo.GetResearcherStatistics
    @ResearcherId int,
    @TotalProjects int OUTPUT,
    @TotalPublications int OUTPUT,
    @TotalWeeklyHours decimal(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @TotalProjects = COUNT(*) FROM dbo.WorksOn WHERE ResearcherId = @ResearcherId;
    SELECT @TotalPublications = COUNT(*) FROM dbo.ResearcherPublication WHERE ResearcherId = @ResearcherId;
    SELECT @TotalWeeklyHours = COALESCE(SUM(HoursPerWeek), 0)
    FROM dbo.WorksOn WHERE ResearcherId = @ResearcherId;
END;
GO

-- Question 42: Prevent assignment to more than five projects

CREATE OR ALTER TRIGGER dbo.trg_WorksOn_MaxFiveProjects
ON dbo.WorksOn
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT i.ResearcherId
        FROM dbo.WorksOn w
        JOIN (SELECT DISTINCT ResearcherId FROM inserted) i
          ON i.ResearcherId = w.ResearcherId
        GROUP BY i.ResearcherId
        HAVING COUNT(DISTINCT w.ProjectId) > 5
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50020, 'A researcher cannot be assigned to more than five projects.', 1;
    END
END;
GO

-- Question 43: Complete projects with past EndDate

CREATE OR ALTER TRIGGER dbo.trg_ResearchProject_CompletePastEndDate
ON dbo.ResearchProject
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p
    SET Status = 'Completed'
    FROM dbo.ResearchProject p
    JOIN inserted i ON i.ProjectId = p.ProjectId
    WHERE i.EndDate < CAST(GETDATE() AS date)
      AND i.EndDate IS NOT NULL
      AND p.Status <> 'Completed';
END;
GO

-- Question 44: Audit updates to Grants

IF OBJECT_ID('dbo.GrantAudit', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.GrantAudit (
        AuditId bigint IDENTITY(1,1) PRIMARY KEY,
        GrantId int NOT NULL,
        OldAmount decimal(18,2) NULL,
        NewAmount decimal(18,2) NULL,
        ModifiedBy sysname NOT NULL,
        ModifiedDate datetime2(0) NOT NULL
    );
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Grants_AuditUpdate
ON dbo.Grants
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.GrantAudit (GrantId, OldAmount, NewAmount, ModifiedBy, ModifiedDate)
    SELECT i.GrantId, d.Amount, i.Amount, SYSTEM_USER, SYSDATETIME()
    FROM inserted i
    JOIN deleted d ON d.GrantId = i.GrantId
    WHERE ISNULL(i.Amount, -1) <> ISNULL(d.Amount, -1);
END;
GO

-- Question 45: Transaction to create and fund a project

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @NewProjectId varchar(50) = 'P_NEW_EXAMPLE';
    DECLARE @LeaderId int = 1;
    DECLARE @StartDate date = CAST(GETDATE() AS date);

    IF NOT EXISTS (SELECT 1 FROM dbo.Researcher WHERE ResearcherId = @LeaderId)
        THROW 50030, 'Leader researcher does not exist.', 1;

    INSERT INTO dbo.ResearchProject
        (ProjectId, Title, LeadResearcherId, Budget, Status, StartDate, EndDate)
    VALUES
        (@NewProjectId, 'Example Research Project', @LeaderId, 120000, 'Pending', @StartDate, NULL);

    INSERT INTO dbo.WorksOn (ResearcherId, ProjectId, JoinDate, Role, HoursPerWeek)
    VALUES (@LeaderId, @NewProjectId, @StartDate, 'Leader', 10);

    INSERT INTO dbo.Grants (GrantId, ProjectId, FundingAgency, Amount)
    VALUES (900001, @NewProjectId, 'Example Funding Agency', 50000);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Question 51: GRANT permissions

GRANT SELECT, INSERT, UPDATE, DELETE, ALTER, REFERENCES, CONTROL
ON SCHEMA::dbo TO ResearchManager;
GO

GRANT SELECT, INSERT ON dbo.Researcher TO ResearchAssistant;
GRANT SELECT, INSERT ON dbo.Publication TO ResearchAssistant;
GO

DECLARE @PermissionSql nvarchar(max) = N'';

SELECT @PermissionSql +=
    N'GRANT SELECT ON OBJECT::' + QUOTENAME(SCHEMA_NAME(v.schema_id)) + N'.' + QUOTENAME(v.name) +
    N' TO DataAnalyst;' + CHAR(10)
FROM sys.views AS v;

SELECT @PermissionSql +=
    N'DENY SELECT, INSERT, UPDATE, DELETE ON OBJECT::' +
    QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) +
    N' TO DataAnalyst;' + CHAR(10)
FROM sys.tables AS t;

EXEC sys.sp_executesql @PermissionSql;
GO

-- Q52: REVOKE permissions (does not necessarily deny access granted via another role)
REVOKE INSERT, UPDATE ON dbo.Researcher FROM ResearchAssistant;
GO

-- Q47: IN vs EXISTS.

SELECT r.*
FROM dbo.Researcher r
WHERE r.ResearcherId IN (
    SELECT w.ResearcherId FROM dbo.WorksOn w WHERE w.ProjectId = 'P001'
);

SELECT r.*
FROM dbo.Researcher r
WHERE EXISTS (
    SELECT 1 FROM dbo.WorksOn w
    WHERE w.ResearcherId = r.ResearcherId AND w.ProjectId = 'P001'
);
GO

-- Question 48: Query performance optimizations

GO

-- Q49: Top 10 cited publications and authors.

CREATE OR ALTER PROCEDURE dbo.GetTopCitedPublications
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (10) p.PublicationId, p.Title, p.CitationCount,
           r.ResearcherId, r.FirstName, r.LastName
    FROM dbo.Publication p
    LEFT JOIN dbo.ResearcherPublication rp ON rp.PublicationId = p.PublicationId
    LEFT JOIN dbo.Researcher r ON r.ResearcherId = rp.ResearcherId
    ORDER BY p.CitationCount DESC, p.PublicationId;
END;
GO
