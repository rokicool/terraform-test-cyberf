 # Create OU for placing SQL Servers
 New-ADOrganizationalUnit -Name "SQLServers" -Path "DC=ALWAYSON,DC=AZURE"

 Move-ADObject -Identity "CN=win-one-sql,CN=Computers,DC=alwayson,DC=azure" -TargetPath "OU=SQLServers,DC=alwayson,DC=azure" 
 Move-ADObject -Identity "CN=win-two-sql,CN=Computers,DC=alwayson,DC=azure" -TargetPath "OU=SQLServers,DC=alwayson,DC=azure" 

# add users for SQL servers

$pw = ConvertTo-SecureString "MXLhuxCtkpP5HTGEPZQu" -AsPlainText -Force 
New-ADUser -Name "sqlserver-one" -AccountPassword $pw -Description "SQL server one" -Enabled $True -PasswordNeverExpires $True


$pw = ConvertTo-SecureString "bmL2ErzThrhIVBwks2vD" -AsPlainText -Force
New-ADUser -Name "sqlserver-two" -AccountPassword $pw -Description "SQL server two" -Enabled $True -PasswordNeverExpires $True


# setup Windows Failover Cluster

just setup a cluster 

dont forget to pin ip addresses to particular server


#https://blog.sqlserveronline.com/2018/01/12/sql-server-target-principal-name-incorrect-cannot-generate-sspi-context/

#on SQL ONE
setspn -A MSSQLSvc/win-one-sql:1433 ALWAYSON\sqlserver-one
setspn -D MSSQLSvc/win-one-sql.alwayson.azure:1433 win-one-sql
setspn -A MSSQLSvc/win-one-sql.alwayson.azure:1433 ALWAYSON\sqlserver-one

#on SQL TWO
setspn -A MSSQLSvc/win-two-sql:1433 ALWAYSON\sqlserver-two
setspn -D MSSQLSvc/win-two-sql.alwayson.azure:1433 win-two-sql
setspn -A MSSQLSvc/win-two-sql.alwayson.azure:1433 ALWAYSON\sqlserver-two


# make SQL server services running under these users

???

# Add "Always On High Availability" on SQL Server 
https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/enable-and-disable-always-on-availability-groups-sql-server?view=sql-server-ver15

SELECT SERVERPROPERTY ('IsHadrEnabled'); 

SQL Server Configuration Manager 

 SQL Server services
  SQL Server (MSSQLSERVER)
    Properties 
      Enable Always On Availability Group

      or 

#Enable-SqlAlwaysOn -Path SQLSERVER:\SQL\Computer\Instance  
Enable-SqlAlwaysOn -Path SQLSERVER:\SQL\localhost\MSSQLSERVER  

# on both SQL Servers
CREATE LOGIN  [ALWAYSON\Abstract] FROM WINDOWS;
ALTER SERVER ROLE sysadmin ADD MEMBER [ALWAYSON\Abstract];  


# Create AO Availability Group
GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM];
GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM];
GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM];


# just a test New-NetFirewallRule -DisplayName "Allow TCP 12345 and 5000-5020 over Teredo" -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow -Protocol TCP -LocalPort 12345,5000-5020 -Program "C:\Program Files (x86)\TestIPv6App.exe"
New-NetFirewallRule -DisplayName "Al TCP 5022 SQL Server Endpoint" -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow -Protocol TCP -LocalPort 5022 -RemoteAddress 10.51.2.0/24 -Group "SQL Server Always On"
New-NetFirewallRule -DisplayName "Al TCP 5022 SQL Server Endpoint" -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow -Protocol TCP -LocalPort 5022 -RemoteAddress 10.50.2.0/24 -Group "SQL Server Always On"

# win-one-sql
New-NetFirewallRule -DisplayName "Al All for 10.51.2.0 (UGLY)" -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow  -RemoteAddress 10.51.2.0/24 -Group "SQL Server Always On"
# win-two-sql
New-NetFirewallRule -DisplayName "Al All for 10.50.2.0 (UGLY)" -Direction Inbound -Action Allow -EdgeTraversalPolicy Allow  -RemoteAddress 10.50.2.0/24 -Group "SQL Server Always On"


# Create users from AD 

CREATE LOGIN  [ALWAYSON\sqlserver-two] FROM WINDOWS;
ALTER SERVER ROLE [sysadmin] ADD MEMBER [ALWAYSON\sqlserver-two]

CREATE LOGIN  [ALWAYSON\sqlserver-one] FROM WINDOWS;
ALTER SERVER ROLE [sysadmin] ADD MEMBER [ALWAYSON\sqlserver-one]

CREATE LOGIN  [ALWAYSON\Abstract] FROM WINDOWS;
ALTER SERVER ROLE [sysadmin] ADD MEMBER [ALWAYSON\Abstract]


# Allow these users to connect "the other endpoint"

# on win-one-sql:

CREATE LOGIN  [ALWAYSON\sqlserver-two] FROM WINDOWS;
GRANT CONNECT ON ENDPOINT::Hadr_Endpoint TO [ALWAYSON\sqlserver-two] 

# on win-two-sql:

CREATE LOGIN  [ALWAYSON\sqlserver-one] FROM WINDOWS;
GRANT CONNECT ON ENDPOINT::Hadr_Endpoint TO [ALWAYSON\sqlserver-one] 

# optional since we dont use clustered listener
https://docs.microsoft.com/en-us/windows-server/failover-clustering/prestage-cluster-adds


SELECT AGS.NAME AS AGGroupName
    ,AR.replica_server_name AS InstanceName
    ,HARS.role_desc
    ,DRS.synchronization_state_desc AS SyncState
    ,DRS.last_hardened_time
    ,DRS.last_redone_time
    ,((DRS.log_send_queue_size)/8)/1024 QueueSize_MB
	,datediff(MINUTE, last_redone_time, last_hardened_time) as Latency_Minutes
FROM sys.dm_hadr_database_replica_states DRS
LEFT JOIN sys.availability_replicas AR ON DRS.replica_id = AR.replica_id
LEFT JOIN sys.availability_groups AGS ON AR.group_id = AGS.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id
    AND AR.replica_id = HARS.replica_id

select * from sys.dm_hadr_availability_replica_states



:Connect win-two-sql

RESTORE DATABASE [wadb] FROM  DISK = N'D:\wadb.bak' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5

GO
:Connect win-two-sql

RESTORE LOG [wadb] FROM  DISK = N'D:\wadb.trn' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5


ALTER DATABASE [wadb] SET HADR AVAILABILITY GROUP = fff;  



------ --------------------------------------------------------------------------- 
--- YOU MUST EXECUTE THE FOLLOWING SCRIPT IN SQLCMD MODE.
:Connect win-one-sql

IF (SELECT state FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END


GO

use [master]

GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [ALWAYSON\sqlserver-two]

GO

:Connect win-one-sql

IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END

GO

:Connect win-two-sql

IF (SELECT state FROM sys.endpoints WHERE name = N'Hadr_endpoint') <> 0
BEGIN
	ALTER ENDPOINT [Hadr_endpoint] STATE = STARTED
END


GO

use [master]

GO

GRANT CONNECT ON ENDPOINT::[Hadr_endpoint] TO [ALWAYSON\sqlserver-one]

GO

:Connect win-two-sql

IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER WITH (STARTUP_STATE=ON);
END
IF NOT EXISTS(SELECT * FROM sys.dm_xe_sessions WHERE name='AlwaysOn_health')
BEGIN
  ALTER EVENT SESSION [AlwaysOn_health] ON SERVER STATE=START;
END

GO

:Connect win-one-sql

USE [master]

GO

CREATE AVAILABILITY GROUP [fff]
WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY_ONLY,
DB_FAILOVER = OFF,
DTC_SUPPORT = NONE,
REQUIRED_SYNCHRONIZED_SECONDARIES_TO_COMMIT = 0)
FOR DATABASE [wadb]
REPLICA ON N'win-one-sql' WITH (ENDPOINT_URL = N'TCP://win-one-sql.alwayson.azure:5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SEEDING_MODE = MANUAL, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO)),
	N'win-two-sql' WITH (ENDPOINT_URL = N'TCP://win-two-sql.alwayson.azure:5022', FAILOVER_MODE = AUTOMATIC, AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, BACKUP_PRIORITY = 50, SEEDING_MODE = MANUAL, SECONDARY_ROLE(ALLOW_CONNECTIONS = NO));

GO

:Connect win-two-sql

ALTER AVAILABILITY GROUP [fff] JOIN;

GO

:Connect win-one-sql

BACKUP DATABASE [wadb] TO  DISK = N'\\win-one-sql.alwayson.azure\backup\wadb.bak' WITH  COPY_ONLY, FORMAT, INIT, SKIP, REWIND, NOUNLOAD, COMPRESSION,  STATS = 5

GO

:Connect win-two-sql

RESTORE DATABASE [wadb] FROM  DISK = N'\\win-one-sql.alwayson.azure\backup\wadb.bak' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5

GO

:Connect win-one-sql

BACKUP LOG [wadb] TO  DISK = N'\\win-one-sql.alwayson.azure\backup\wadb.trn' WITH NOFORMAT, INIT, NOSKIP, REWIND, NOUNLOAD, COMPRESSION,  STATS = 5

GO

:Connect win-two-sql

RESTORE LOG [wadb] FROM  DISK = N'\\win-one-sql.alwayson.azure\backup\wadb.trn' WITH  NORECOVERY,  NOUNLOAD,  STATS = 5

GO


GO



---------------------------------------------------------------------------

TITLE: Microsoft SQL Server Management Studio
------------------------------

Force Failover failed  (Microsoft.SqlServer.Management.HadrTasks)

------------------------------
ADDITIONAL INFORMATION:

Failed to perform a forced failover of the availability group 'wadbag' to server instance 'win-two-sql'. (Microsoft.SqlServer.Management.HadrModel)

For help, click: https://go.microsoft.com/fwlink?ProdName=Microsoft+SQL+Server&ProdVer=16.100.41011.9+(SqlManagementObjects-master-APPLOCAL)&EvtSrc=Microsoft.SqlServer.Management.Smo.ExceptionTemplates.FailedOperationExceptionText&LinkId=20476

------------------------------

An exception occurred while executing a Transact-SQL statement or batch. (Microsoft.SqlServer.ConnectionInfo)

------------------------------

Failed to bring availability group 'wadbag' online.  The operation timed out. If this is a Windows Server Failover Clustering (WSFC) availability group, verify that the local WSFC node is online. Then verify that the availability group resource exists in the WSFC cluster. If the problem persists, you might need to drop the availability group and create it again. (Microsoft SQL Server, Error: 41131)

For help, click: http://go.microsoft.com/fwlink?ProdName=Microsoft%20SQL%20Server&ProdVer=14.00.3335&EvtSrc=MSSQLServer&EvtID=41131&LinkId=20476

------------------------------
BUTTONS:

OK
------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------

https://support.microsoft.com/en-us/help/2847723/cannot-create-a-high-availability-group-in-microsoft-sql-server-2012

GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM];
GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM];
GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM];
