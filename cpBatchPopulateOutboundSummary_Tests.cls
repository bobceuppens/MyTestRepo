/*
Change: Added line
*/
/**********************************************************************
 Name:  cpBatchPopulateOutboundSummary_Tests.cls  
======================================================
Purpose: 
    Test class to test the following classes:
    1. cpBatchSetKONECareOnlineUsersOnAccount.cls
    2. cpBatchPopulateOutboundSummary.cls
    
    and the following trigger:
    1. ContactAfter.trigger
======================================================
History                                                            
-------                                                            
VERSION     AUTHOR              DATE            DETAIL                                 
    1.0     Patrick Brinksma    16/04/2012      INITIAL DEVELOPMENT
    1.1     Patrick Brinksma    29/06/2012      Added 'Closed' as status for Closed Callouts
***********************************************************************/
@isTest(SeeAllData=false)
private class cpBatchPopulateOutboundSummary_Tests {

    // Map of contact Id to User created for test purpose, use for assertion later on
    static Map<Id, User> testUsersMap;
    
    // Count of objects created, used for assertions in the methods
    final static Integer NR_OF_ACCOUNTS = 3;
    final static Integer NR_OF_EQUIPMENT_PER_BUILDING = 2;
    final static Integer NR_OF_SERVICEORDER_PER_EQUIPMENT = 3;
    final static Integer NR_OF_MAINTENANCESCHEDULE_PER_EQUIPMENT = 3;

    // Create test data
    static {
        // Prepare a list of customer accounts and partners
        List<Account> testCustomers = new List<Account>();
        List<Account> testPartners = new List<Account>();
        for (Integer i=1; i<=NR_OF_ACCOUNTS;i++){
            Account customer = accessKeys_sObjectFactory.getTestAccount();
            customer.Name = 'Test Customer AABBCCDD ' + i;
            customer.Has_KONE_Care_Online_Users__c = true;
            customer.KONE_City__c = 'Brooklyn';
            customer.Kone_Country__c = 'USA';
            customer.Street_1__c = 'Test Street';
            customer.KONE_Zip_Postal_Code__c = '12345';
            testCustomers.add(customer);
            Account partner = accessKeys_sObjectFactory.getTestAccount();
            partner.Name = 'Test Partner Account' + i;
            partner.KONE_City__c = 'Brooklyn';
            partner.Kone_Country__c = 'USA';
            partner.Street_1__c = 'Test Street';
            partner.KONE_Zip_Postal_Code__c = '12345';
            testPartners.add(partner);          
        }
        System.debug(LoggingLevel.INFO,'ABSILOG *** Insert testCustomers & testPartners');
        insert testCustomers;
        insert testPartners;
        
        // Customer Account without customer portal users for assertion
        Account customer = accessKeys_sObjectFactory.getTestAccount();
        customer.Name = 'Test Customer Without Contact1';
        insert customer;
        
        // Get map of Customer accounts
        Map<Id, Account> accntIdMap = new Map<Id, Account>();
        for (Account accnt : testCustomers){
            accntIdMap.put(accnt.Id, accnt);
        }
        System.debug(LoggingLevel.INFO,'ABSILOG *** accntIdMap.size() ' + accntIdMap.size());

        //Create Test Portal User for each test customer account
        testUsersMap = new Map<Id, User>();
        // Use existing Kone care online customer profile
        Profile p = [select id from profile where name = '* Kone: Overage HVCP - Customer' limit 1];
        for (Id accntId : accntIdMap.keySet()){
            // Create Contact for Portal user associated with the given Account
            Contact  portalContact = new Contact(AccountId = accntId, Newsletter_Frequency__c = 'Quarterly', lastname = 'Test LastName');
            insert portalContact;
            // Create portal user
            String testemail = 'test@test.com';
            User pu = new User(profileId = p.id, username = testemail + accntId, email = testemail,
                             emailencodingkey = 'UTF-8', localesidkey = 'en_US',
                             languagelocalekey = 'en_US', User_Country__c = 'Netherlands', timezonesidkey = 'America/Los_Angeles',
                             alias='cspu', lastname='lastname', contactId = portalContact.Id, IsPortalSelfRegistered = true);
            insert pu;    
            // Put into map for assertion       
            testUsersMap.put(portalContact.Id, pu);
        }        
        System.debug(LoggingLevel.INFO,'ABSILOG *** testUsersMap ' + testUsersMap.size());

        // for each Test Customer Account, create a Building
        Map<Id, Building__c> accntIdToB = new Map<Id, Building__c>();
        List<Building__c> bList = new List<Building__c>();
        for (Id accntId : accntIdMap.keySet()){
            Building__c building = accessKeys_sObjectFactory.getTestBuildingWithParents(accntId);
            building.customer__c = accntId;
            accntIdToB.put(accntId, building);
            bList.add(building);
        }
        System.debug('****************** Inserting test buildings: ' + bList.size());
        insert bList;
        
        // Create Equipments for each Building
        Integer i = 0;
        List<Equipment__c> eList = new List<Equipment__c>();
        Map<Id, List<Equipment__c>> accntIdToEq = new Map<Id, List<Equipment__c>>();
        for (Id accntId : accntIdMap.keySet()){
            List<Equipment__c> equipments = accessKeys_sObjectFactory.getTestEquipmentList(NR_OF_EQUIPMENT_PER_BUILDING, accntId, bList[i].Id);
            accntIdToEq.put(accntId, equipments);
            eList.addAll(equipments);
            i++;
        }
        System.debug('****************** Inserting test equipments: ' + eList.size());
        insert eList;
        
        // prepare dates for Service Orders
        Date sodateOne = Date.today();
        Date sodateTwo = Date.today().addMonths(-1);
        Date sodateThree = Date.today().addMonths(-2);  
        Integer j = 0;     
        i=0; 
        
        // for each account for each equipment create service orders
        List<Service_Order__c> serviceOrders = new List<Service_Order__c>();
        for (Id accntId : accntIdToEq.keySet()){
            List<Equipment__c> equipments = accntIdToEq.get(accntId);
            for(Equipment__c equipment:equipments){
                
                List<Service_Order__c> soList = accessKeys_sObjectFactory.getTestServiceOrderList(NR_OF_SERVICEORDER_PER_EQUIPMENT, accntId, accntIdToB.get(accntId).Id, equipment.Id);
                for(Service_Order__c serviceOrder:soList){            
                    
                    serviceOrder.Customer__c = accntId;
                    serviceOrder.Service_Request_Type__c = 'Uncontrollable';
                    if (j == 0) serviceOrder.Reported_Date__c = sodateOne;
                    if (j == 1) serviceOrder.Reported_Date__c = sodateTwo;
                    if (j == 2) serviceOrder.Reported_Date__c = sodateThree;
                    j++;
                    if (j > 2) j = 0;                
                    serviceOrder.Maintenance__c = 'Callout';
                    if (j == 0 || j == 1) serviceOrder.Order_Status__c = 'Finished';
                    if (j == 2) serviceOrder.Order_Status__c = 'Closed';
                }
                serviceOrders.addAll(soList);
            }
        }
        System.debug('****************** Inserting test Service Orders: ' + serviceOrders.size());
        insert serviceOrders;      
        
        // Create for account each equipment create maintenance schedules
        Date msdateOne = Date.today().addMonths(1);
        Date msdateTwo = Date.today().toStartOfMonth().addMonths(2);
        Date msdateThree = Date.today().toStartOfMonth().addMonths(3);
        j = 0;

        List<Maintenance_Schedule__c> maintenanceSchedules = new List<Maintenance_Schedule__c>();
        for (Id accntId : accntIdToEq.keySet()){
            List<Equipment__c> equipments = accntIdToEq.get(accntId);
            for(Equipment__c equipment:equipments){
                
                List<Maintenance_Schedule__c> msList = accessKeys_sObjectFactory.getTestMScheduleList(NR_OF_MAINTENANCESCHEDULE_PER_EQUIPMENT, accntId, accntIdToB.get(accntId).Id, equipment.Id);
                for(Maintenance_Schedule__c ms:msList){  
                    ms.Display_Scheduling_Status__c = 'Scheduled Called';       
                    ms.Customer__c = accntId;   
                    if (j == 0) ms.Next_Planned_Date__c = msdateOne;
                    if (j == 1) ms.Next_Planned_Date__c = msdateTwo;
                    if (j == 2) ms.Next_Planned_Date__c = msdateThree;
                    j++;
                    if (j > 2) j = 0;               
                }
                maintenanceSchedules.addAll(msList);
            }
        }
        System.debug('****************** Inserting test Maintenance Schedules: ' + maintenanceSchedules.size());
        insert maintenanceSchedules;        
        
        // Insert one invoice for each Service Order
        List<Invoice__c> invList = new List<Invoice__c>();
        i = 0;
        for (Service_Order__c so : serviceOrders){
            Invoice__c inv = new Invoice__c(Total_Amount__c = 100, 
                                            Name = 'Test_Invoice_' + String.valueof(i),
                                            Invoice_Date__c = Date.today(),
                                            currencyIsoCode = 'AUD', 
                                            Transfer_to_Accounting_Status__c = 'Not Cleared', 
                                            Customer__c = so.Customer__c, 
                                            Service_Order__c = so.Id);
            invList.add(inv);
            System.debug('************** Inserting invoice for customer: ' + so.Customer__c);
        }           
        System.debug('****************** Inserting test Invoices: ' + invList.size());
        insert invList;
        
        cpPortalUtil_Test portalTest = new cpPortalUtil_Test();
        
    }

    static testMethod void testSetKONECareOnlineUsersOnAccount() {
        // Test Batch Apex Job cpBatchSetKONECareOnlineUsersOnAccount which sets the flag Has_KONE_Care_Online_Users__c if Account has active KONE Care Online Portal Users
        Test.startTest();
        cpBatchSetKONECareOnlineUsersOnAccount cpb = new cpBatchSetKONECareOnlineUsersOnAccount();
        Database.executeBatch(cpb);
        Test.stopTest();
        
        // Let's validate results
        List<Account> accntList = [select Id, Has_KONE_Care_Online_Users__c from Account where Name LIKE 'Test Customer AABBCCDD%' OR Name = 'Test Customer Without Contact1' order by Name];
        // Assert total nr of records
        System.assertEquals(NR_OF_ACCOUNTS + 1, accntList.size());
        // Assert field
        Integer i=0;
        for (i=0; i < accntList.size() - 1; i++){
            System.assertEquals(true, accntList[i].Has_KONE_Care_Online_Users__c);
        }        
        // Last account does not have a active portal user, so false
        System.assertEquals(false, accntList[i].Has_KONE_Care_Online_Users__c);
    }
   
    static testMethod void testBatchPopulateOutboundSummary() {
        // Test Batch Apex Job cpBatchPopulateOutboundSummary which populates Outbound_Summary__c with summary records for extract to Exact Target 
        List<Account> accntList = [select Id, Has_KONE_Care_Online_Users__c from Account where Name LIKE 'Test Customer AABBCCDD%'];
        System.debug(LoggingLevel.INFO,'ABSILOG *** accntList.size() ' + accntList.size());
        for (Account accnt : accntList){
            accnt.Has_KONE_Care_Online_Users__c = true;
        }
        update accntList;

            // Run batch job
        Test.startTest();
        System.debug(LoggingLevel.INFO,'ABSILOG *** Start Test for testBatchPopulateOutboundSummary');
        Integer j = [SELECT COUNT() from Account where Has_KONE_Care_Online_Users__c = true and (Name = 'Customer Test Without Contact' or Name like 'Test Customer AABBCC%')];
        System.debug(LoggingLevel.INFO,'ABSILOG *** Database.getQueryLocator records selected ' + j);
        cpBatchPopulateOutboundSummary cpB = new cpBatchPopulateOutboundSummary();
        cpB.NrOfMonths = 3;
        cpB.NrOfInvoices = 3;
        System.debug(LoggingLevel.INFO,'ABSILOG *** Launching Database.executeBatch(cpB)');
        Database.executeBatch(cpB);
        System.debug(LoggingLevel.INFO,'ABSILOG *** Stop Test for testBatchPopulateOutboundSummary');
        test.stopTest();
        
        System.debug(LoggingLevel.INFO,'ABSILOG ***  Start Assertions for testBatchPopulateOutboundSummary');
        // Let's validate results
        System.assertEquals(NR_OF_ACCOUNTS, testUsersMap.size());
        for (AggregateResult results : [select Type__c, count(Id) NrOfRec from Outbound_Summary__c where Contact__c in : testUsersMap.keySet() group by Type__c]){
            System.debug(LoggingLevel.INFO,'ABSILOG *** accntIdMap.size() ' + (Integer)results.get('NrOfRec'));
            if ((String)results.get('Type__c') == 'IN'){
                //System.assertEquals(NR_OF_ACCOUNTS, (Integer)results.get('NrOfRec'));
            }
            if ((String)results.get('Type__c') == 'SO'){
                //System.assertEquals(NR_OF_ACCOUNTS, (Integer)results.get('NrOfRec'));
            }
            if ((String)results.get('Type__c') == 'MS'){
                //System.assertEquals(NR_OF_ACCOUNTS, (Integer)results.get('NrOfRec'));
            }
        }
    }

    static testmethod void schedulerTest(){
        test.startTest();
            cpBatchPopulateOutboundSummaryScheduler sched = new cpBatchPopulateOutboundSummaryScheduler();
            sched.execute(null);
            
        test.stopTest();
    
    }

}