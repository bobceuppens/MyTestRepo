/**********************************************************************
 Name:  cpBatchPopulateOutboundSummary.cls
 Other classes used: cpPortalUtil.cls
 Tested in class:  cpBatchPopulateOutboundSummary_Tests.cls
======================================================
Purpose: 

    Batch job to create entries in the Outbound Summary object which includes the following records:
    1. 3 oldest Invoices which are not cleared
    2. Number of Closed Callouts (Service Orders) of 3 last months including current
    3. Number of Maintenance Schedules for coming 3 months including current
======================================================
History                                                            
-------                                                            
VERSION     AUTHOR              DATE            DETAIL                                 
    1.0     Patrick Brinksma	04/09/2012      INITIAL DEVELOPMENT
    1.1		Patrick Brinksma	06/06/2012		Fix added to filter on active KONE Care Online Users
    1.2		Patrick Brinksma	04/09/2012		Several changes to select the right date, make it configurable, and calculate the correct periods, nr of invoices configurable
***********************************************************************/
global class cpBatchPopulateOutboundSummary implements Database.Batchable<sObject>, Database.Stateful{
	
	// Keep track of batch number for error log 
	global Integer batchNum;
	// Parameters to construct URL
	global Map<String, String> urlParamMap = new Map<String, String>();
	// Month names to convert from Numbers
	global Map<Integer, String> monthNumToNameMap = new Map<Integer, String>();	
	// Date to use (if null, use today)
	global Date dtCalc;
	// Nr of months to span for extraction (if null, use Custom Setting 'NewsletterNrOfMonthsToExtract', otherwise 3)
	global Integer NrOfMonths;
	// Nr of Invoices to retrieve
	global Integer NrOfInvoices;
	
	global Database.Querylocator start(Database.BatchableContext BC){
		try{
			/*
			 * Get values use to extract the data for the batch
			 */
			// User batch 0 to indicate start method
			batchNum = 0;		
			// If not date is given, use today!
			if (dtCalc == null) dtCalc = Date.today();
			// Now set date to last day of the month of that date
			dtCalc = dtCalc.toStartOfMonth().addMonths(1).addDays(-1);
			// Get url parameters from Custom Settings
			urlParamMap.put('baseurl', cpPortalUtil.getPortalConfigItem('CustomerPortalBaseUrl'));
			urlParamMap.put('sourl', cpPortalUtil.getPortalConfigItem('HomeServiceOrderUrl'));
			urlParamMap.put('msurl', cpPortalUtil.getPortalConfigItem('HomeMaintenanceScheduleUrl'));
			// Get nr of months to extract
			String NrOfMonthsValue = cpPortalUtil.getPortalConfigItem('NewsletterNrOfMonthsToExtract');
			if (NrOfMonthsValue != null){
				if (NrOfMonths == null) NrOfMonths = Integer.valueOf(NrOfMonthsValue);
			}
			if (NrOfMonths == null) NrOfMonths = 3;
			// Get nr of invoices to extract
			String NrOfInvoicesValue = cpPortalUtil.getPortalConfigItem('NewsletterNrOfInvoicesToExtract');
			if (NrOfInvoicesValue != null){
				if (NrOfInvoices == null) NrOfInvoices = Integer.valueOf(NrOfMonthsValue);
			}
			if (NrOfInvoices == null) NrOfMonths = 3;
			// Get names of Months in English
			Schema.DescribeFieldResult fieldResult = Outbound_Summary__c.MonthOfYear__c.getDescribe();
			List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
			Integer i=1;
			for(Schema.PicklistEntry f : ple){
				monthNumToNameMap.put(i, f.getValue());
				i++;
			}			
			/*
			 * Select the Accounts to be processed in the batch
			 * Use a seperate selection specifically for testing
			 */			
			// Process all Accounts which have KONE Care Online users / contacts
			if (!Test.isRunningTest()){
				return Database.getQueryLocator([select 
																Id,
																Regional_Customer_of_Equipments__c, 
																Property_Manager_of_Equipments__c, 
																Partner_Function_E_of_Equipments__c,  
																Partner_Function_D_of_Equipments__c, 
																Partner_Function_C_of_Equipments__c, 
																Partner_Function_B_of_Equipments__c,  
																Partner_Function_A_of_Equipments__c, 
																Bill_To_of_Equipments__c
																from Account
														 		where Has_KONE_Care_Online_Users__c = true
												]);
			} else {
			// Process test data which has been created in the test class
				Integer j = [SELECT COUNT() from Account where Has_KONE_Care_Online_Users__c = true and (Name = 'Customer Test Without Contact' or Name like 'Test Customer AABBCC%')];
				System.debug(LoggingLevel.INFO,'ABSILOG *** Database.getQueryLocator records selected ' + j);
				return Database.getQueryLocator([select 
																Id,
																Regional_Customer_of_Equipments__c, 
																Property_Manager_of_Equipments__c, 
																Partner_Function_E_of_Equipments__c,  
																Partner_Function_D_of_Equipments__c, 
																Partner_Function_C_of_Equipments__c, 
																Partner_Function_B_of_Equipments__c,  
																Partner_Function_A_of_Equipments__c, 
																Bill_To_of_Equipments__c
																from Account
														 		where Has_KONE_Care_Online_Users__c = true and
																(Name = 'Customer Test Without Contact' or Name like 'Test Customer AABBCC%')
												]);			
			}			
		}
		catch (Exception e){
			System.debug(LoggingLevel.INFO,'ABSILOG *** Exception - Message : ' + e.getMessage() + 'Line no : ' + e.getLineNumber() + ' getStackTraceString ' + e.getStackTraceString() + '' + e.getCause());
			errorLog.Log('cpPopulateOutboundSummary', 'start', 'Error for batchNum: ' + batchNum, e);	
			return null;		
		}		
	}
	
	global void execute(Database.BatchableContext BC, List<Account> scope){
		try{
			//delete all old records in outbound summary object
			if (batchNum==0) {
				System.debug(LoggingLevel.INFO,'ABSILOG *** Deleting all Outbound_Summary__c records');
				List<Outbound_Summary__c> lstDeleteOutbound = [select id from Outbound_Summary__c];
				delete lstDeleteOutbound;
			}
			/*
			 * Get the selection data which is derived from Account
			 */			
			// Batch number
			batchNum++;
			// Put scope in a Map to work with
			Map<Id, Account> accntIdMap = new Map<Id, Account>(); 
			for (Account accnt : scope){
				accntIdMap.put(accnt.Id, accnt);
			}
			
			// We need a set of Ids of Contacts for which we create Outbound Summary to get Language and Kone Country 
			Set<Id> cntIdSet = new Set<Id>();
			
			// Get all the Contacts related to the Account for which the Newsletter_Frequency__c <> "None"
			// This means the user IS a Customer Portal user for KONE Care Online AND it wants to receive a Newsletter
			Map<Id, Contact> cntIdMap = new Map<Id, Contact>([select Id, AccountId, Account.Name from Contact where AccountId in: accntIdMap.keySet() and Newsletter_Frequency__c <> 'None']);
			// Added for 1.1 - Start
			// Determine which Contacts are actually active users
			List<User> usrActiveList = [select Id, ContactId, Profile.Name from User where ContactId in: cntIdMap.keySet() and isActive = true];
			System.debug(LoggingLevel.INFO,'ABSILOG *** usrActiveList ' + usrActiveList.size());
			List<Contact> cntList = new List<Contact>();
			for (User u : usrActiveList){
				System.debug(LoggingLevel.INFO,'ABSILOG *** u.Profile.Name ' + u.Profile.Name);
				if (cpPortalUtil.isKONECareOnlineProfile(u.Profile.Name))
					cntList.add(cntIdMap.get(u.ContactId));
			}			
			// Added for 1.1 - End
			// Store all Contacts into contact holder
			List<contactHolder> conHolderList = new List<contactHolder>();
			for (Contact cnt : cntList){
				contactHolder conHol = new contactHolder();
				conHol.ContactId = cnt.Id;
				conHol.AccountId = cnt.AccountId;
				conHol.AccountName = cnt.Account.Name;
				conHol.Role = 'Customer';
				conHol.viewInvoices = true;
				conHolderList.add(conHol);
				
				cntIdSet.add(cnt.Id);
			}
			
			/*
			// Now create a list of Partner Accounts, including Role, from the scope to determine which Partner Contacts we need
			// Create a Map of Partner Id to Partner Rol and one to View Invoice and one to Account
			Map<Id, String> partnerRoleMap = new Map<Id, String>();
			Map<Id, Boolean> partnerInvoiceMap = new Map<Id, Boolean>();
			Map<Id, Id> partnerAccountMap = new Map<Id, Id>();
			for (Account accnt : accntIdMap.values()){
				// Only process if child Customer Partner records exists
				if (accnt.Customer_Partners__r != null){
					// Loop through child Customer_Parner__c records to determine Partner role (should be one per Partner)
					for (Customer_Partner__c cp : accnt.Customer_Partners__r){
						// Determine which dominant role the partner has for the Account
						custPartnerObj cpO = new custPartnerObj(cp);
						String partRole = cpO.getPartnerRole();
						// Only add if partner actually has a role
						if (partRole <> 'None'){
							// Store values in maps
							partnerAccountMap.put(cp.Partner__c, accnt.Id);
							partnerInvoiceMap.put(cp.Partner__c, true);
							partnerRoleMap.put(cp.Partner__c, partRole);
						}
					}
				}
			} 
			*/

			// Now that we have the map of all the Partners, let's grab the Contacts for those Partners
			/*Map<Id, Contact> pcntIdMap = new Map<Id, Contact>([select Id, AccountId, Account.Name from Contact where AccountId in: partnerRoleMap.keySet() and Account.Has_KONE_Care_Online_Users__c = true and Newsletter_Frequency__c <> 'None' order by AccountId]);*/
			// Added for 1.1 - Start
			// Determine which Contacts are actually active users
			/*
			usrActiveList = [select Id, ContactId, Profile.Name from User where ContactId in: pcntIdMap.keySet() and isActive = true];
			cntList.clear();
			for (User u : usrActiveList){
				if (cpPortalUtil.isKONECareOnlineProfile(u.Profile.Name))
				 	System.debug(LoggingLevel.INFO,'ABSILOG *** u.Id ' + u.Id + ' cntIdMap.get(u.ContactId)' + pcntIdMap.get(u.ContactId));
					cntList.add(cntIdMap.get(u.ContactId));
			}
			*/		
			// Added for 1.1 - End			
			// Store all Contacts into contact holder
			/*
			for (Contact cnt : cntList){
				contactHolder conHol = new contactHolder();
				conHol.ContactId = cnt.Id;
				conHol.AccountId = partnerAccountMap.get(cnt.AccountId);
				conHol.PartnerId = cnt.AccountId;
				conHol.AccountName = cnt.Account.Name;
				conHol.Role = partnerRoleMap.get(cnt.AccountId);
				conHol.viewInvoices = partnerInvoiceMap.get(cnt.AccountId);
				conHolderList.add(conHol);
				
				cntIdSet.add(cnt.Id);
			}
			*/

			// Now we have all the Contacts (and thus Accounts) for which we can get data
			// Let first remove all unused Accounts from accntIdMap (create new Map)
			Map<Id, Account> accntIdProcMap = new Map<Id, Account>();
			Set<Id> accntProcced = new Set<Id>(); 
			for (contactHolder conHol : conHolderList){
				if (!accntProcced.contains(conHol.AccountId)){
					accntIdProcMap.put(conHol.AccountId, accntIdMap.get(conHol.AccountId));
					accntProcced.add(conHol.AccountId);
				}
			}
			// Clear old map
			accntIdMap.clear();
			
			// Now we have a full list of Contacts with their Account (customer or partner), role and who can see invoices		
			// We can now get the data for Invoices, Service Orders and Maintenance schedules and create the correct Outbound Summary records
			if (!accntIdProcMap.isEmpty()){
				// List of to be created Outbound Summary records
				List<Outbound_Summary__c> outboundList = new List<Outbound_Summary__c>();
				
				// Prepare the maps so that for every Account and each month nr of Service Orders and Maintenance Schedules is set to 0, 
				// and for each month set the year
				// For Service Orders
				Map<Id, Map<Integer, Integer>> ccPerMonthMap = new Map<Id, Map<Integer, Integer>>();
				Map<Id, Map<Integer, Integer>> ccmonthYearMap = new Map<Id, Map<Integer, Integer>>();				
				// Including this month
		        Date endDateSO = dtCalc;
		        // Extract x-1 of months to get period of x nr of months
		        Date startDateSO = dtCalc.toStartOfMonth().addMonths(-(NrOfMonths-1));			        			        
				Map<Integer, Integer> perMonthMapSO = new Map<Integer, Integer>();
				Map<Integer, Integer> monthYearMapSO = new Map<Integer, Integer>();		   
				Date startDateLoop = startDateSO;
				while(startDateLoop <= endDateSO){
					perMonthMapSO.put(startDateLoop.month(), 0);
					monthYearMapSO.put(startDateLoop.month(), startDateLoop.year());
					startDateLoop = startDateLoop.addMonths(1);
				}				     			
				// For Maintenance Schedules
				Map<Id, Map<Integer, Integer>> msPerMonthMap = new Map<Id, Map<Integer, Integer>>();
				Map<Id, Map<Integer, Integer>> msmonthYearMap = new Map<Id, Map<Integer, Integer>>();				
				// End date is month of dtCalc + 1 + x in the future
		        Date endDateMS = dtCalc.addMonths(NrOfMonths);
		        // starte date is first of dtCalc + 1 month
		        Date startDateMS = dtCalc.toStartOfMonth().addMonths(1);			        
				Map<Integer, Integer> perMonthMapMS = new Map<Integer, Integer>();
				Map<Integer, Integer> monthYearMapMS = new Map<Integer, Integer>();		   
				startDateLoop = startDateMS;
				while(startDateLoop <= endDateMS){
					perMonthMapMS.put(startDateLoop.month(), 0);
					monthYearMapMS.put(startDateLoop.month(), startDateLoop.year());
					startDateLoop = startDateLoop.addMonths(1);
				}				     			
				for (Id accntId : accntIdProcMap.keySet()){
					ccPerMonthMap.put(accntId, perMonthMapSO.clone());
					ccmonthYearMap.put(accntId, monthYearMapSO.clone());
					msPerMonthMap.put(accntId, perMonthMapMS.clone());
					msmonthYearMap.put(accntId, monthYearMapMS.clone());
				}
				
			/*
			 * Get Invoice Data
			 */
				// Get all Invoice Data, store per Id a List of x nr of oldest invoices which are not Cleared
				Map<Id, List<Invoice__c>> invoiceMap = new Map<Id, List<Invoice__c>>();
				// Query for all the accounts and invoice child data limited by x nr of oldest invoices not Cleared				
				List<Account> accntList = new List<Account>([select id, name, (select Id, Total_Amount__c, Invoice_Date__c, CurrencyIsoCode, Name From invoicecustomer__r where Transfer_to_Accounting_Status__c <> 'Cleared' order by Invoice_Date__c limit :NrOfInvoices) from Account where Id in :accntIdProcMap.keySet() order by Id]);
				for (Account accnt : accntList){
					invoiceMap.put(accnt.Id, accnt.invoicecustomer__r);
				}
	
			/*
			 * Get Service Order Data
			 */									
		        // Get aggregate of number of closed call outs per Account per Month number	
				AggregateResult[] groupedSOResults = [Select Customer__c, CALENDAR_MONTH(s.Reported_Date__c) calmonth, CALENDAR_YEAR(s.Reported_Date__c) calyear, count(Id) numofso From Service_Order__c s where Customer__c in: accntIdProcMap.keySet() and (Order_Status__c = 'Finished' or Order_Status__c = 'Closed' or Order_Status__c = 'TECO' or Order_Status__c = 'CLSD') and Reported_Date__c >=:startDateSO and Reported_Date__c <=:endDateSO AND (Maintenance__c = 'Callout' OR Maintenance__c = 'KRM Callout' OR Maintenance__c = 'Billable callout') group by Customer__c, CALENDAR_MONTH(s.Reported_Date__c), CALENDAR_YEAR(s.Reported_Date__c) order by Customer__c];
				// Now prepare to loop through the result set. For each Account store the x nr of months with total in a map, then add it to the main map with Account Id
				for (AggregateResult ar : groupedSOResults) {
					// Get customer and month from result
					Id accntId = (Id)ar.get('Customer__c');
					Integer curMonth = (Integer)ar.get('calmonth');
					// Get the prepopulated map
					Map<Integer, Integer> perMonthMap = ccPerMonthMap.get(accntId);
					// Add this month (and year) to maps
					perMonthMap.put(curMonth, (Integer)ar.get('numofso'));										
				}
				
			/*
			 * Get Maintenance Schedule Data
			 */					
		        // Get aggregate of number of maintenance schedules per Account per Month number
				AggregateResult[] groupedMSResults = [Select Customer__c, CALENDAR_MONTH(Next_Planned_Date__c) calmonth, CALENDAR_YEAR(Next_Planned_Date__c) calyear, count(Id) numofms From Maintenance_Schedule__c where Customer__c in: accntIdProcMap.keySet() and Display_Scheduling_Status__c != 'skipped' and Display_Scheduling_Status__c != 'Scheduled Locked' and Next_Planned_Date__c != null and Next_Planned_Date__c >=:startDateMS and Next_Planned_Date__c <=:endDateMS group by Customer__c, CALENDAR_MONTH(Next_Planned_Date__c), CALENDAR_YEAR(Next_Planned_Date__c) order by Customer__c];
				
				// Now prepare to loop through the result set. For each Account store the x nr of months with total in a map, then add it to the main map with Account Id
				for (AggregateResult ar : groupedMSResults) {
					// Get customer and month from result
					Id amsntId = (Id)ar.get('Customer__c');
					Integer curMonth = (Integer)ar.get('calmonth');
					// Get prepopulated map
					Map<Integer, Integer> perMonthMap = msPerMonthMap.get(amsntId);
					// Add this month (and year) to maps
					perMonthMap.put(curMonth, (Integer)ar.get('numofms'));
				}
				
				// Now we have all data, let's see which Contact gets a Outbound Summary record for this
				// Get User Language and Kone Country from User record of Contact
				Map<Id, User> cntIdUserMap = new Map<Id, User>();
				if (!cntIdSet.isEmpty()){
					List<User> usrList = [select ContactId, User_Country__c, User_Language__c, LanguageLocaleKey from User where ContactId in: cntIdSet];
					for (User usr : usrList){
						cntIdUserMap.put(usr.ContactId, usr);
					}
				}
				
				// Loop through all Contacts and
				for (contactHolder conHol : conHolderList){
					
					// Determine partner id
					String custPartId = conHol.AccountId;
					if (conHol.PartnerId <> null){
						custPartId = custPartId + conHol.PartnerId;
					}				
					// Create new Outbound Summary record 
					Outbound_Summary__c outBoundTemp = new Outbound_Summary__c( Contact__c = conHol.ContactId, 
																			Customer_Name__c = conHol.AccountName, 
																			Customer_Partner_Id__c = custPartId,
																			Partner_Function__c = conHol.Role
																			);				
					// Get User for details
					User usrCnt = cntIdUserMap.get(conHol.ContactId);
					if (usrCnt != null){
						outBoundTemp.Kone_Country__c = usrCnt.User_Country__c;
						outBoundTemp.Language__C = usrCnt.LanguageLocaleKey;
					}
					// First process Invoices
					// Only if Contact is allowed to view Invoice data
					if (conHol.viewInvoices){
						// Get list of Invoices
						List<Invoice__c> invList = invoiceMap.get(conHol.AccountId);
						// For every invoice create a Outbound Summary record
						for (Invoice__c inv : invList){
							Outbound_Summary__c outBound = outBoundTemp.clone(false, true);
							outbound.Invoice_Number__c = inv.Name;
							outBound.Amount__c = inv.Total_Amount__c;
							outBound.CurrencyIsoCode = inv.CurrencyIsoCode;
							outBound.Period_Commencing__c = inv.Invoice_Date__c;
							outBound.Type__c = 'IN';
							outBound.URL__c = urlParamMap.get('baseurl') + '/' + inv.Id;
							outboundList.add(outBound);
						}
					}	
					
					// Second process Service Orders
					Map<Integer, Integer> perMonthMap = ccPerMonthMap.get(conHol.AccountId);
					Map<Integer, Integer> monthYearMap = ccmonthYearMap.get(conHol.AccountId);
					if (perMonthMap != null && !perMonthMap.isEmpty()){
						for (Integer i : perMonthMap.keySet()){
							Outbound_Summary__c outBound = outBoundTemp.clone(false, true);
							outBound.Period_Commencing__c = date.newinstance(monthYearMap.get(i), i, 1);
							outBound.Quantity__c = perMonthMap.get(i);
							outBound.MonthOfYear__c = monthNumToNameMap.get(i);
							outBound.Year__c = String.valueOf(monthYearMap.get(i));
							outBound.Type__c = 'SO';	
							String url = urlParamMap.get('sourl');
							url = url.replace('[year]', String.valueof(outBound.Year__c));
							url = url.replace('[month]', String.valueof(i));
							outBound.URL__c = urlParamMap.get('baseurl') + '/' + url;																			
							outboundList.add(outBound);				
						}
					}
		
					// Third process Maintenance Schedules
					perMonthMap = msPerMonthMap.get(conHol.AccountId);
					monthYearMap = msmonthYearMap.get(conHol.AccountId);
					if (perMonthMap != null && !perMonthMap.isEmpty()){			
						for (Integer i : perMonthMap.keySet()){
							Outbound_Summary__c outBound = outBoundTemp.clone(false, true);
							outBound.Period_Commencing__c = date.newinstance(monthYearMap.get(i), i, 1);
							outBound.Quantity__c = perMonthMap.get(i);
							outBound.MonthOfYear__c = monthNumToNameMap.get(i);
							outBound.Year__c = String.valueOf(monthYearMap.get(i));
							outBound.Type__c = 'MS';				
							String url = urlParamMap.get('msurl');
							url = url.replace('[year]', String.valueof(outBound.Year__c));
							url = url.replace('[month]', String.valueof(i));
							outBound.URL__c = urlParamMap.get('baseurl') + '/' + url;
							outboundList.add(outBound);				
				
						}
					}						
				}		
		
				// Finally if there are records to be created, do it now!		
				if (!outboundList.isEmpty()){
					insert outboundList;
				}
			}
		}
		catch (Exception e){
			System.debug(LoggingLevel.INFO,'ABSILOG *** Exception - Message : ' + e.getMessage() + 'Line no : ' + e.getLineNumber() + ' getStackTraceString ' + e.getStackTraceString() + '' + e.getCause());
			errorLog.Log('cpBatchPopulateOutboundSummary', 'execute', 'Error for batchNum: ' + batchNum, e);			
		}
	}
		
	global void finish(Database.BatchableContext BC){

		// Query the AsyncApexJob object to retrieve the current job's information.  
     
     AsyncApexJob a = [Select Id, Status, NumberOfErrors, JobItemsProcessed,
        TotalJobItems, CreatedBy.Email
        from AsyncApexJob where Id =:BC.getJobId()];
     // Send an email to the Apex job's submitter notifying of job completion.  
      
     Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
     String[] toAddresses = new String[] {'webmaster@kone.com'};
     mail.setToAddresses(toAddresses);
     mail.setSubject('Outbound Summary Batch ' + a.Status);
     mail.setPlainTextBody
     ('The batch job processed ' + a.TotalJobItems +
     ' batches with '+ a.NumberOfErrors + ' failures.');
     Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

	}
	
	// Place holder for Contacts with some additional info
	public class contactHolder{
		public Id ContactId {get; set;}
		public Id AccountId {get; set;}
		public Id PartnerId {get; set;}
		public String AccountName {get; set;}
		public String Role {get; set;}
		public Boolean viewInvoices {get; set;}
		
		// Empty constructor 
		public contactHolder(){}
	}
	
}