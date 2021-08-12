USE [ReportServer]
GO

create schema Emailer
GO

CREATE TABLE [Emailer].[EmailListRecipients](
	[ListId] [int] IDENTITY(1,1) NOT NULL,
	[EventType] [nvarchar](260) NULL,
	[RecipientList] [nvarchar](512) NULL,
	[LastStatusTypeLike] [nvarchar](260) NULL,
	[EmailProfileName] [nvarchar](260) NULL,
	[EmailTemplate] [nvarchar](4000) NULL,
	[DateAdd] [datetime] NULL,
 CONSTRAINT [PK_EmailListRecipients] PRIMARY KEY CLUSTERED 
(
	[ListId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TABLE [Emailer].[SubscriptionsLog](
	[SubscriptionLogId] [int] IDENTITY(1,1) NOT NULL,
	[SubscriptionID] [uniqueidentifier] NOT NULL,
	[OwnerID] [uniqueidentifier] NOT NULL,
	[Report_OID] [uniqueidentifier] NOT NULL,
	[ReportName] [nvarchar](512) NULL,
	[Locale] [nvarchar](128) NOT NULL,
	[InactiveFlags] [int] NOT NULL,
	[ModifiedByID] [uniqueidentifier] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
	[Description] [nvarchar](512) NULL,
	[LastStatus] [nvarchar](260) NULL,
	[EventType] [nvarchar](260) NOT NULL,
	[LastRunTime] [datetime] NULL,
	[DeliveryExtension] [nvarchar](260) NULL,
	[Version] [int] NOT NULL,
	[ReportZone] [int] NOT NULL,
	[DateAdd] [datetime] NULL,
	[MailStatus] [nvarchar](256) NULL,
 CONSTRAINT [PK_SubscriptionsLog] PRIMARY KEY CLUSTERED 
(
	[SubscriptionLogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE PROCEDURE [Emailer].[SendNotificationEmails]
 
AS
 
/*set up variables outer loop*/
declare @ListId int 
declare @EventType nvarchar(260)
declare @RecipientList nvarchar(512)
declare @LastStatusTypeLike nvarchar(260)
declare @EmailProfileName nvarchar(260)
declare @EmailTemplate nvarchar(4000)


/*set up variables inner loop*/
declare @SubscriptionLogId	int 
declare @ReportName			nvarchar(260)
declare @Description		nvarchar(512)
declare @LastStatus			nvarchar(260)
declare @LastRunTime		datetime
declare @DateAdd			datetime

/*set up BatchJob Table*/

  Select [ListId], 
		[EventType], 
		[RecipientList],  
		[LastStatusTypeLike], 
		[EmailProfileName],
		[EmailTemplate]
  into #BatchJob 
  from Emailer.EmailListRecipients with (nolock)


  /*End set up BatchJob Table*/

  /*outer cursor for different email types*/
  declare  csr_BatchJob cursor
  for select	[ListId],
				[EventType], 
				[RecipientList],  
				[LastStatusTypeLike],
				[EmailProfileName],
				[EmailTemplate]
  from #BatchJob with (nolock)
  OPEN csr_BatchJob  

	FETCH NEXT FROM csr_BatchJob   
	INTO @ListId,@EventType,@RecipientList,@LastStatusTypeLike,@EmailProfileName,@EmailTemplate

		WHILE @@FETCH_STATUS = 0  
		BEGIN  

		/*Inner cursor for messages*/
		Select  SubscriptionLogId, 
				ReportName, 
				[Description],
				LastStatus,  
				LastRunTime,
				[DateAdd] 
				into #MessageGroup 
				from Emailer.SubscriptionsLog with (nolock)
				where MailStatus = 'NEW'
				and EventType=@EventType
				and LastStatus like '%' + @LastStatusTypeLike + '%'
				order by DATEADD asc 

				
		  declare  csr_MessageGroup cursor
	      for select	
				SubscriptionLogId, 
				ReportName, 
				[Description],
				LastStatus,  
				LastRunTime,
				DATEADD
			from #MessageGroup with (nolock)
			OPEN csr_MessageGroup  

	Declare @EmailBody nvarchar(max)
	set @EmailBody=''

	Declare @EmailSubject nvarchar(max)
	set @EmailSubject= 'Power BI Report Server reports ' + cast((select count(*) from #MessageGroup) as nvarchar(10)) + ' Results for ' + @LastStatusTypeLike
	 
	FETCH NEXT FROM csr_MessageGroup   
	INTO  @SubscriptionLogId,@ReportName,@Description,@LastStatus,@LastRunTime,@DateAdd	
	WHILE @@FETCH_STATUS = 0  
		BEGIN  

			Declare @EmailRow nvarchar(4000) 
			Set @EmailRow = @EmailTemplate
			Set @EmailRow  = replace(@EmailRow,'[SubscriptionLogId]',@SubscriptionLogId)
			Set @EmailRow  = replace(@EmailRow,'[ReportName]',@ReportName)
			Set @EmailRow  = replace(@EmailRow,'[Description]',@Description)
			Set @EmailRow  = replace(@EmailRow,'[LastStatus]',@LastStatus)
			Set @EmailRow  = replace(@EmailRow,'[LastRunTime]',@LastRunTime)
			Set @EmailRow  = replace(@EmailRow,'[DateAdd]',@DATEADD)


			set @EmailBody = @EmailBody + @EmailRow + '<br/>' 

		


		FETCH NEXT FROM csr_MessageGroup   
		INTO  @SubscriptionLogId,@ReportName,@Description,@LastStatus,@LastRunTime,@DateAdd	
		END  

		/*Send Email*/

		EXEC msdb.dbo.sp_send_dbmail 
				 @profile_name = @EmailProfileName,
				@recipients=@RecipientList,  
				@subject = @EmailSubject,  
				@body = @EmailBody,  
				@body_format = 'HTML' ;  

		/*End Send Email*/

		/*update records*/
		Update Emailer.SubscriptionsLog
		set MailStatus = 'SENT'
		from Emailer.SubscriptionsLog, #MessageGroup
		where Emailer.SubscriptionsLog.SubscriptionLogId = #MessageGroup.SubscriptionLogId


		CLOSE csr_MessageGroup;  
DEALLOCATE csr_MessageGroup;  

		drop table #MessageGroup

		/*End Inner cursor for messages*/

	FETCH NEXT FROM csr_BatchJob   
	INTO @ListId,@EventType,@RecipientList,@LastStatusTypeLike,@EmailProfileName,@EmailTemplate
		END  
		

CLOSE csr_BatchJob;  
DEALLOCATE csr_BatchJob;  


  --@ListId=ListId, @EventType=EventType,@RecipientList=RecipientList,@LastStatusType=LastStatusType

  /*drop table #BatchJob Table*/
  drop table #BatchJob

GO


CREATE TRIGGER [dbo].[Subscriptions_Update]  
ON [dbo].[Subscriptions]  
AFTER UPDATE   
AS 

insert into Emailer.SubscriptionsLog(
SubscriptionID,
OwnerID,
Report_OID,
Locale,
InactiveFlags,
ModifiedByID,
ModifiedDate,
Description,
LastStatus,
EventType,
LastRunTime,
DeliveryExtension,
Version,
ReportZone,
DateAdd,
MailStatus,
ReportName)



select 
inserted.SubscriptionID,
inserted.OwnerID,
inserted.Report_OID,
inserted.Locale,
inserted.InactiveFlags,
inserted.ModifiedByID,
inserted.ModifiedDate,
inserted.Description,
inserted.LastStatus,
inserted.EventType,
inserted.LastRunTime,
inserted.DeliveryExtension,
inserted.Version,
inserted.ReportZone,
GetDate(),
'NEW',
Catalog.Name

from inserted left outer join Catalog
on inserted.Report_OID = Catalog.ItemID
GO
ALTER TABLE [dbo].[Subscriptions] ENABLE TRIGGER [Subscriptions_Update]
GO
