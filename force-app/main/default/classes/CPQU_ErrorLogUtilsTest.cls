/**
 * Test class for CPQU_ErrorLogUtilsTest
 * Created : 05/08/2020 : Kevin Antonioli
 */
@IsTest
private class CPQU_ErrorLogUtilsTest {

    @TestSetup
    static void testSetup() {
        CPQU_Features__c features = new CPQU_Features__c(SetupOwnerId = UserInfo.getOrganizationId(), AllTriggerHandlersDisabled__c = false);
        insert features;
    }

    @IsTest
    static void testCreateErrorLogException() {
        Account account = new Account(Name = 'Test Account ABC123');
        insert account;
        StringException ex = new StringException();
        ex.setMessage('Placeholder error message');

        String errorSource = 'CPQU_ErrorLogUtilsTest.test_standard';
        Test.startTest();
        CPQU_ErrorLogUtils.createErrorLog(ex, 'TestClass', errorSource, account.Id);
        CPQU_ErrorLogUtils.processErrorLogs(new Set<Id>{account.Id}, new Set<String>{errorSource});
        Test.stopTest();

        List<CPQU_ErrorLog__c> errorLogs = [SELECT Id FROM CPQU_ErrorLog__c WHERE CPQU_ErrorSource__c = :errorSource];
        System.assertEquals(errorLogs.isEmpty(), false);
    }

    @IsTest
    static void testCreateErrorLogContextDbLogged() {
        Account account = new Account(Name = 'Test Account ABC123');
        account.AccountNumber = '12345678901234567890123456789012345678901234567890';

        String errorSource = 'CPQU_ErrorLogUtilsTest.test_standard';
        Test.startTest();

        List<Database.SaveResult> saveResults = Database.insert(new List<Account>{account}, false);
        for(Database.SaveResult saveResult: saveResults) {
            System.debug('test_DatabaseErrorLogLogging ' + saveResult.isSuccess());
            if(!saveResult.isSuccess()) {
                CPQU_ErrorLogUtils.createErrorLog('TestClass', errorSource, saveResult.getErrors(), account.Id);
            } else {
                System.assert(false);
            }
        }

        Test.stopTest();

        List<CPQU_ErrorLog__c> errorLogs = [SELECT Id FROM CPQU_ErrorLog__c WHERE CPQU_ErrorSource__c = :errorSource];
        System.assertEquals(errorLogs.isEmpty(), false);
    }

    @IsTest
    static void testCreateErrorLogContextDbNothingLogged() {
        Account account = new Account(Name = 'Test Account ABC123');
        account.AccountNumber = '12345678901234567890123456';

        String errorSource = 'CPQU_ErrorLogUtilsTest.test_standard';
        Test.startTest();

        List<Database.SaveResult> saveResults = Database.insert(new List<Account>{account}, false);
        for(Database.SaveResult saveResult: saveResults) {
            System.debug('test_DatabaseErrorLogLogging ' + saveResult.isSuccess());
            if(!saveResult.isSuccess()) {
                CPQU_ErrorLogUtils.createErrorLog('TestClass', errorSource, saveResult.getErrors(), account.Id);
            }
        }
        Test.stopTest();

        List<CPQU_ErrorLog__c> errorLogs = [SELECT Id FROM CPQU_ErrorLog__c WHERE CPQU_ErrorSource__c = :errorSource];
        System.assertEquals(errorLogs.isEmpty(), true);
    }
}