/**
 * Test class for CPQXL_QuoteCloneXLTriggerHandler
 * TODO: need to finish this class.
 */
@IsTest
private class CPQXL_QuoteCloneXLTriggerHandlerTest {
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

        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
        String scenarioType = CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO;
        String extendedId = quote.Id + '::' + scenarioType;
        insert new SBQQ__RecordJob__c(SBQQ__RecordId__c = extendedId, SBQQ__JobStatus__c = 'Queued', CPQXL_PercentComplete__c = 0);
    }

    @IsTest
    static void test_oneAggregation() {
        Map<String, CPQU_UtilitySetting__mdt> utilitySettings = CPQU_ApexUtils.groupSettingsByDeveloperName(
            [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
            FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]);
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c = 150;
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c = 150;
        //upsert utilitySettings.values();

        prepareAndFirePlatformEvents(utilitySettings);
    }

    @IsTest
    static void test_multipleAggregations() {
        Map<String, CPQU_UtilitySetting__mdt> utilitySettings = CPQU_ApexUtils.groupSettingsByDeveloperName(
            [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
            FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]);
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c = 1;
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c = 1;
        //upsert utilitySettings.values();

        prepareAndFirePlatformEvents(utilitySettings);
    }
    @IsTest
    static void test_multipleAggregations1() {
        Map<String, CPQU_UtilitySetting__mdt> utilitySettings = CPQU_ApexUtils.groupSettingsByDeveloperName(
            [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
            FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]);
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c = 1;
        utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c = 1;
        //upsert utilitySettings.values();

        prepareAndFirePlatformEvents1(utilitySettings);
    }

    static void prepareAndFirePlatformEvents(Map<String, CPQU_UtilitySetting__mdt> utilitySettings) {
        SBQQ__Quote__c sourceQuote = [
            SELECT Id,
            (SELECT Id FROM SBQQ__LineItems__r WHERE SBQQ__RequiredBy__c = NULL)
            FROM SBQQ__Quote__c LIMIT 1
        ];
        Id sourceQuoteId = sourceQuote.Id;
        SBQQ__Quote__c targetQuote = (SBQQ__Quote__c) CPQU_BundleStructureUtils.cloneXObjectHeader(sourceQuoteId, false /* setCloneAsPrimary */, true /*doInsert*/);
        Id targetQuoteId = targetQuote.Id;

        Set<String> bundlesToExclude = new Set<String>();
        Map<Integer, Set<Id>> bundleAggregationsMap = CPQU_BundleStructureUtils.getBundleAggregations(sourceQuoteId, Integer.valueOf(utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c));
        Map<Integer, Set<Id>> bundleAggregationsMapExtended =  CPQU_BundleStructureUtils.getBundleAggregationsExtended(
            sourceQuoteId, Integer.valueOf(utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c), bundlesToExclude, true
        );
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(Name = 'Test Opp 1', AccountId = account.Id, StageName = 'Prospecting', CloseDate = System.today());
        insert opp;

        Test.startTest();
        List<CPQXL_CloneLargeQuoteEvent__e> cloneLargeQuoteEvents = new List<CPQXL_CloneLargeQuoteEvent__e>();
        CPQXL_CloneLargeQuoteEvent__e cloneLargeQuoteEvent = new CPQXL_CloneLargeQuoteEvent__e(
            CPQXL_SourceQuoteId__c = sourceQuoteId, // static
            CPQXL_SourceQuoteNumberOfBundles__c = sourceQuote.SBQQ__LineItems__r.size(), // static
            CPQXL_TargetQuoteId__c = targetQuoteId, // static
            CPQXL_OpportunityId__c = opp.Id,
            CPQXL_ScenarioType__c = CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO,
            CPQXL_BundleAggregationsJSON__c = JSON.serialize(bundleAggregationsMap), // static
            CPQXL_BundleAggregationsExtendedJSON__c = JSON.serialize(bundleAggregationsMapExtended), // static
            CPQXL_AggregationNumberToProcess__c = 1 // store which aggregation number to process in the next thread.
        );
                
        cloneLargeQuoteEvents.add(cloneLargeQuoteEvent);
        if(!cloneLargeQuoteEvents.isEmpty()) {
            List<Database.SaveResult> sr = EventBus.publish(cloneLargeQuoteEvents);
            System.assertEquals(true, sr.get(0).isSuccess());
        }
        
        CPQXL_CloneLargeQuoteEvent__e cloneLargeQuoteEvent1 = new CPQXL_CloneLargeQuoteEvent__e(
            CPQXL_SourceQuoteId__c = sourceQuoteId, // static
            CPQXL_SourceQuoteNumberOfBundles__c = sourceQuote.SBQQ__LineItems__r.size(), // static
            CPQXL_TargetQuoteId__c = targetQuoteId, // static
            CPQXL_OpportunityId__c = opp.Id,
            CPQXL_ScenarioType__c = CPQXL_Constants.LARGE_ORDER_SCENARIO,
            CPQXL_BundleAggregationsJSON__c = JSON.serialize(bundleAggregationsMap), // static
            CPQXL_BundleAggregationsExtendedJSON__c = JSON.serialize(bundleAggregationsMapExtended), // static
            CPQXL_AggregationNumberToProcess__c = 1 // store which aggregation number to process in the next thread.
        );
		EventBus.publish(new List<CPQXL_CloneLargeQuoteEvent__e>{cloneLargeQuoteEvent1});

        Test.stopTest();

        // List<SBQQ__Quote__c> targetQuotes = [
        //     SELECT Id, (SELECT Id FROM SBQQ__LineItems__r) FROM SBQQ__Quote__c WHERE SBQQ__Source__c = :sourceQuote.Id LIMIT 1
        // ];

        // // verify that the target quote got created with quote lines:
        // System.assertEquals(!targetQuotes.isEmpty(), true);
        // System.assertEquals(!targetQuotes[0].SBQQ__LineItems__r.isEmpty(), true);
    }
    
    static void prepareAndFirePlatformEvents1(Map<String, CPQU_UtilitySetting__mdt> utilitySettings) {
        SBQQ__Quote__c sourceQuote = [
            SELECT Id,
            (SELECT Id FROM SBQQ__LineItems__r WHERE SBQQ__RequiredBy__c = NULL)
            FROM SBQQ__Quote__c LIMIT 1
        ];
        Id sourceQuoteId = sourceQuote.Id;
        SBQQ__Quote__c targetQuote = (SBQQ__Quote__c) CPQU_BundleStructureUtils.cloneXObjectHeader(sourceQuoteId, false /* setCloneAsPrimary */, true /*doInsert*/);
        Id targetQuoteId = targetQuote.Id;

        Set<String> bundlesToExclude = new Set<String>();
        Map<Integer, Set<Id>> bundleAggregationsMap = CPQU_BundleStructureUtils.getBundleAggregations(sourceQuoteId, Integer.valueOf(utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c));
        Map<Integer, Set<Id>> bundleAggregationsMapExtended =  CPQU_BundleStructureUtils.getBundleAggregationsExtended(
            sourceQuoteId, Integer.valueOf(utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c), bundlesToExclude, true
        );
        Account account = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(Name = 'Test Opp 1', AccountId = account.Id, StageName = 'Prospecting', CloseDate = System.today());
        insert opp;

        Test.startTest();
        List<CPQXL_CloneLargeQuoteEvent__e> cloneLargeQuoteEvents = new List<CPQXL_CloneLargeQuoteEvent__e>();
        CPQXL_CloneLargeQuoteEvent__e cloneLargeQuoteEvent = new CPQXL_CloneLargeQuoteEvent__e(
            CPQXL_SourceQuoteId__c = sourceQuoteId, // static
            CPQXL_SourceQuoteNumberOfBundles__c = sourceQuote.SBQQ__LineItems__r.size(), // static
            CPQXL_TargetQuoteId__c = targetQuoteId, // static
            CPQXL_OpportunityId__c = opp.Id,
            CPQXL_ScenarioType__c = CPQXL_Constants.LARGE_ORDER_SCENARIO,
            CPQXL_BundleAggregationsJSON__c = JSON.serialize(bundleAggregationsMap), // static
            CPQXL_BundleAggregationsExtendedJSON__c = JSON.serialize(bundleAggregationsMapExtended), // static
            CPQXL_AggregationNumberToProcess__c = 1 // store which aggregation number to process in the next thread.
        );
                
        cloneLargeQuoteEvents.add(cloneLargeQuoteEvent);
        if(!cloneLargeQuoteEvents.isEmpty()) {
            List<Database.SaveResult> sr = EventBus.publish(cloneLargeQuoteEvents);
            System.assertEquals(true, sr.get(0).isSuccess());
        }
        
        Test.stopTest();

        // List<SBQQ__Quote__c> targetQuotes = [
        //     SELECT Id, (SELECT Id FROM SBQQ__LineItems__r) FROM SBQQ__Quote__c WHERE SBQQ__Source__c = :sourceQuote.Id LIMIT 1
        // ];

        // // verify that the target quote got created with quote lines:
        // System.assertEquals(!targetQuotes.isEmpty(), true);
        // System.assertEquals(!targetQuotes[0].SBQQ__LineItems__r.isEmpty(), true);
    }
}