/**
 * Test class for CPQXL_QuoteCloneXLController
 * Created : 03/12/2020 : Kevin Antonioli
 * TODO: need to write assertion statements.
 */
@IsTest
private class CPQXL_QuoteCloneXLControllerTest {
    // set up common data:
    @TestSetup
    private static void dataSetup() {
        CPQU_BundleStructureUtils.signalToQueryAllLineFields();
        CPQU_TestsCache.bulkRecordSize = 5;
        CPQU_TestsCache.initialSetup();
        
        Test.startTest(); // gain an extra set of governor limits within the context of the test class
        CPQU_TestsCache.setupQuotesAndQuoteLines(
            false,   // Boolean quoteStartTests
            false,   // Boolean quoteStopTests
            false,   // Boolean quoteLineStartTests
            false    // Boolean quoteLineStopTests
        );
        Test.stopTest();
    }

    @IsTest
    static void test_CPQXL_QuoteCloneXLController() {
        Map<String, CPQU_UtilitySetting__mdt> utilitySettings = CPQU_ApexUtils.groupSettingsByDeveloperName(
            [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
            FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]);
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c = 1;
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c = 1;
        //upsert utilitySettings;

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Test.startTest();
        Map<String, CPQU_UtilitySetting__mdt> cpqxlSettingsRead = CPQXL_QuoteCloneXLController.cpqxlSettings();
        CPQXL_QuoteCloneXLController.cloneRecords(quote.Id, new List<String>());
        CPQXL_QuoteCloneXLController.AsyncProcessProperties app = new CPQXL_QuoteCloneXLController.AsyncProcessProperties();
        CPQXL_QuoteCloneXLController.getCloneStatus(quote.Id, quote.Id, new List<String>(), app);
        Test.stopTest();
    }
}