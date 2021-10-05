/**
 * Test class for CPQXL_QuoteApprovalXLControllerTest
 * Created : 05.18.2020 : Kevin Antonioli
 * TODO: need to write assertion statements.
 */
@IsTest
private class CPQXL_QuoteApprovalXLControllerTest {
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
    static void test_standard() {
        Map<String, CPQU_UtilitySetting__mdt> utilitySettings = CPQU_ApexUtils.groupSettingsByDeveloperName(
            [SELECT DeveloperName, Label, BooleanValue__c, NumberValue__c, TextValue__c
            FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]);

         utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_FLATTEN_LINE_GRID_SIZE).NumberValue__c = 120;
         utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_SUBMIT_LARGE_QUOTE_FOR_APPROVAL_THRESHOLD).NumberValue__c = 1;
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c = 1;
        //upsert utilitySettings.values();

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        Test.startTest();
        CPQXL_QuoteApprovalXLController.onSubmitForApproval2(quote.Id);
        Test.stopTest();
    }   
}