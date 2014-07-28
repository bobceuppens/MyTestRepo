/*
Added line
*/
@isTest
public class cpPortalUtil_Test
{
    private static User u_1, u_2;
    private static Account a_1;
    private static Contact c_1, c_2;
    
    static {
     
        List<CustomerPortalProfileSwitch__c> lsCustomerPortalProfiles = new List<CustomerPortalProfileSwitch__c>();
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchBillTo', Profile_Name__c = '* Kone: Overage HVCP - Bill To', Field_Name__c = 'Bill_To_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchCustomer', Profile_Name__c = '* Kone: Overage HVCP - Customer', Field_Name__c = 'Customer_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchPartnerFuncA', Profile_Name__c = '* Kone: Overage HVCP - Partner Func A', Field_Name__c = 'Partner_Function_A_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchPartnerFuncB', Profile_Name__c = '* Kone: Overage HVCP - Partner Func B', Field_Name__c = 'Partner_Function_B_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchPartnerFuncC', Profile_Name__c = '* Kone: Overage HVCP - Partner Func C', Field_Name__c = 'Partner_Function_C_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchPartnerFuncD', Profile_Name__c = '* Kone: Overage HVCP - Partner Func D', Field_Name__c = 'Partner_Function_D_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchPartnerFuncE', Profile_Name__c = '* Kone: Overage HVCP - Partner Func E', Field_Name__c = 'Partner_Function_E_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchPartnerPropertyManager', Profile_Name__c = '* Kone: Overage HVCP - Property Manager', Field_Name__c = 'Property_Manager_of_Equipments__c'));
        lsCustomerPortalProfiles.add(new CustomerPortalProfileSwitch__c(Name = 'cpProfileSwitchPartnerRegionalCustomer', Profile_Name__c = '* Kone: Overage HVCP - Regional Customer', Field_Name__c = 'Regional_Customer_of_Equipments__c'));    
        insert lsCustomerPortalProfiles;
        
        List<CustomerPortalConfig__c> lsPortalConfig = new List<CustomerPortalConfig__c>();
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'EmailDisplayName', Value__c = 'Kone Care Online'));
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'EmailReplyTo', Value__c = 'noreply@kone.com'));
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'ForgotPasswordEmailTemplate', Value__c = 'cpForgotPasswordEmailVF'));
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'CustomerPortalBaseUrl', Value__c = 'DUMMY'));
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'HomeServiceOrderUrl', Value__c = 'DUMMY'));
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'HomeMaintenanceScheduleUrl', Value__c = 'DUMMY'));
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'NewsletterNrOfMonthsToExtract', Value__c = '6'));
        lsPortalConfig.add(new CustomerPortalConfig__c(Name = 'NewsletterNrOfInvoicesToExtract', Value__c = '3'));
		insert lsPortalConfig;
		
        //Insert countries to prevent an error when you create an account
        List<Country_List__c> countries = new List<Country_List__c>();
        countries.add(new Country_List__c(Name = 'Finland',Value__c = 'Finland',Area__c = 'CNE'));
        countries.add(new Country_List__c(Name = 'Brazil',Value__c = 'Finland',Area__c = 'CNE'));
        countries.add(new Country_List__c(Name = 'USA',Value__c = 'USA',Area__c = 'ENA'));
        countries.add(new Country_List__c(Name = 'France',Value__c = 'France',Area__c = 'ENA'));
        countries.add(new Country_List__c(Name = 'Belgium',Value__c = 'Belgium',Area__c = 'NNA'));
        insert countries;

        //  get a user that can be used as the account owner
        u_1 = TestFactory.getStandardUser();        
        
        //  this is the account associated to the customer portal user
        a_1 = TestFactory.createAccount(u_1.Id);
        a_1.Kone_Country__c = 'USA';
        insert a_1;
        // contact associated to account
        c_1 = TestFactory.createContact(a_1.Id);
        insert c_1;
        //  create portal user
        u_2 = TestFactory.createHVCPCustomerUser(c_1.Id);
        insert u_2;

        // contact associated to account
        c_2 = TestFactory.createContact(a_1.Id);
        insert c_2;
        
    }
    
    static TestMethod void testIsKONECareOnlineProfile(){
     	
     	Test.startTest();
        Boolean result = cpPortalUtil.isKONECareOnlineProfile('* Kone: Overage HVCP - Bill To');
        result = cpPortalUtil.isKONECareOnlineProfile('* Kone: Overage HVCP - Customer');
        result = cpPortalUtil.isKONECareOnlineProfile('* Kone: Overage HVCP - Bill To');
        result = cpPortalUtil.isKONECareOnlineProfile('* Kone: Overage HVCP - Partner Func A');
        result = cpPortalUtil.isKONECareOnlineProfile('* Kone: Overage HVCP - Partner Func B');
        Test.stopTest();
        
    }
    
    static TestMethod void getPortalConfigItem(){
        
        Test.startTest();
        String result = cpPortalUtil.getPortalConfigItem('EmailDisplayName');
        result = cpPortalUtil.getPortalConfigItem('EmailReplyTo');
        result = cpPortalUtil.getPortalConfigItem('ForgotPasswordEmailTemplate');
        Test.stopTest();
        
    }
    
    static TestMethod void createUser()
    {
        EmailTemplate templ = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1];

        CustomerPortalConfig__c cusPorConfig;
        List<CustomerPortalConfig__c> lsConfigs = [SELECT Value__c FROM CustomerPortalConfig__c WHERE Name = 'EmailDisplayName' LIMIT 1];
        if(lsConfigs.size() < 1)
        {
            cusPorConfig = new CustomerPortalConfig__c();
            cusPorConfig.Name = 'EmailDisplayName';
            cusPorConfig.Value__c = 'EmailDisplayName';
            insert cusPorConfig;    
        }   
        else cusPorConfig = lsConfigs[0];

        CustomerPortalConfig__c cusPorConfig2;
        List<CustomerPortalConfig__c> lsConfigs2 = [SELECT Value__c FROM CustomerPortalConfig__c WHERE Name = 'EmailReplyTo' LIMIT 1];
        if(lsConfigs2.size() < 1)
        {
            cusPorConfig2 = new CustomerPortalConfig__c();
            cusPorConfig2.Name = 'EmailReplyTo';
            cusPorConfig2.Value__c = 'test@test.com';
            insert cusPorConfig2;    
        }   
        else cusPorConfig2 = lsConfigs2[0];

        CustomerPortalConfig__c cusPorConfig3;
        List<CustomerPortalConfig__c> lsConfigs3 = [SELECT Value__c FROM CustomerPortalConfig__c WHERE Name = 'RegisterEmailTemplate' LIMIT 1];
        if(lsConfigs3.size() < 1)
        {
            cusPorConfig3 = new CustomerPortalConfig__c();
            cusPorConfig3.Name = 'RegisterEmailTemplate';
            cusPorConfig3.Value__c = templ.DeveloperName;
            insert cusPorConfig3;    
        }   
        else cusPorConfig3 = lsConfigs3[0];
    	
        Test.startTest();
    	
    	
    	cpPortalUtil.CreateUser('00e20000001QKDi', 'test', 'testName', 'test@kone.com', 'noreply@kone.com', 'en_US', 'en_US', 'Europe/Brussels', c_2.Id, 'EUR', 'Belgium');
    	Test.stopTest();
    	
    }

    static TestMethod void sendEmailWithTemplate()
    {
        EmailTemplate templ = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1];
        Test.startTest();
        cpPortalUtil.sendEmailWithTemplate(u_1.Id, 'DisplayName', 'test@test.com', 'Highest', templ.DeveloperName);
        Test.stopTest();        
    }
    
    static TestMethod void resetPassword()
    {
        EmailTemplate templ = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName = 'cpForgotPasswordEmailVF' LIMIT 1];

        CustomerPortalConfig__c cusPorConfig;
        List<CustomerPortalConfig__c> lsConfigs = [SELECT Value__c FROM CustomerPortalConfig__c WHERE Name = 'EmailDisplayName' LIMIT 1];
        if(lsConfigs.size() < 1)
        {
            cusPorConfig = new CustomerPortalConfig__c();
            cusPorConfig.Name = 'EmailDisplayName';
            cusPorConfig.Value__c = 'EmailDisplayName';
            insert cusPorConfig;    
        }   
        else cusPorConfig = lsConfigs[0];

        CustomerPortalConfig__c cusPorConfig2;
        List<CustomerPortalConfig__c> lsConfigs2 = [SELECT Value__c FROM CustomerPortalConfig__c WHERE Name = 'EmailReplyTo' LIMIT 1];
        if(lsConfigs2.size() < 1)
        {
            cusPorConfig2 = new CustomerPortalConfig__c();
            cusPorConfig2.Name = 'EmailReplyTo';
            cusPorConfig2.Value__c = 'test@test.com';
            insert cusPorConfig2;    
        }   
        else cusPorConfig2 = lsConfigs2[0];

        CustomerPortalConfig__c cusPorConfig3;
        List<CustomerPortalConfig__c> lsConfigs3 = [SELECT Value__c FROM CustomerPortalConfig__c WHERE Name =:templ.DeveloperName LIMIT 1];
        if(lsConfigs3.size() < 1)
        {
            cusPorConfig3 = new CustomerPortalConfig__c();
            cusPorConfig3.Name = templ.DeveloperName;
            cusPorConfig3.Value__c = templ.DeveloperName;
            insert cusPorConfig3;    
        }   
        else cusPorConfig3 = lsConfigs3[0];
        
        Test.startTest();
        cpPortalUtil.resetPassword(u_1.Id, c_1.Id, true, templ.DeveloperName);
        Test.stopTest();        
    }

    static TestMethod void resetHasKONECareOnlineFlagOnAccount()
    {
        Test.startTest();
        
        Map<Id, Boolean> mapAccounts = new Map<Id, Boolean>();
        mapAccounts.put(a_1.Id, true);
        cpPortalUtil.resetHasKONECareOnlineFlagOnAccount(mapAccounts);

        Test.stopTest();

        System.assertEquals(false, a_1.Has_Kone_Care_Online_Users__c);
    }
}