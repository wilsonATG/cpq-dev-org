/**
 * Test class for CPQXL_QuoteCloneXLInitializer
 * Created : 03/12/2020 : Kevin Antonioli
 * TODO: need to write assertion statements.
 */
@IsTest
private class CPQXL_QuoteCloneXLInitializerTest {
    // set up common data:
    @TestSetup
    private static void dataSetup() {
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
    static void test_CloneLargeQuoteInitializer_smallQuoteClone() {
        Map<String, CPQU_UtilitySetting__mdt> utilitySettings = CPQU_ApexUtils.groupSettingsByDeveloperName(
            [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
            FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]);
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c = 1000;
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c = 1000;
        //upsert utilitySettings;

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Test.startTest();
        new CPQXL_QuoteCloneXLInitializer(quote.Id, null);
        Test.stopTest();
    }

    @IsTest
    static void test_CloneLargeQuoteInitializer_largeQuoteClone() {
        Map<String, CPQU_UtilitySetting__mdt> utilitySettings = CPQU_ApexUtils.groupSettingsByDeveloperName(
            [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
            FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]);
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c = 1;
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c = 1;
        //upsert utilitySettings;

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Test.startTest();
        new CPQXL_QuoteCloneXLInitializer(quote.Id, null);
        Test.stopTest();
    }
}