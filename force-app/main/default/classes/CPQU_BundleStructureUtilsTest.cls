/**
 * Created by Kevin Antonioli on 03.22.19
 * Tests the following classes:
 *    CPQU_BundleStructureUtils.cls
 *
 *
 * 03.22.19 : Kevin Antonioli : Created
 */
@IsTest
public class CPQU_BundleStructureUtilsTest { 

    public static final Integer numOfSubscriptionProducts = 10;
    public static final Integer numOfAssetProducts = 10;
    public static final Integer numOfContracts = 1;

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

        // setup common data:
      CPQU_TestUtils cpqTestUtils = new CPQU_TestUtils();
      cpqTestUtils.setupTestData_contractRenewalRelated(numOfSubscriptionProducts, numOfAssetProducts, numOfContracts);
    }

	@IsTest
    static void test_XObjectData_forContract() {
    	Test.startTest();
        // query contracts:
        List<Contract> createdContracts = [SELECT Id FROM Contract];
        List<CPQU_BundleStructureUtils.XObjectData> contractDataList = new List<CPQU_BundleStructureUtils.XObjectData>();

        for(Contract contract : createdContracts) {
        	// build an extended data structure for each contract:
        	CPQU_BundleStructureUtils.XObjectData contractData = new CPQU_BundleStructureUtils.XObjectData(contract.Id);
			CPQU_BundleStructureUtils.lineNumberSequencer(contract.Id);
            CPQU_BundleStructureUtils.getBundleAggregationsExtended(contract.Id,1);
            CPQU_BundleStructureUtils.getAllLineIdsInAggregation(1,contract.Id);
            CPQU_BundleStructureUtils.cloneXObjectHeader(contract.Id,false);
            System.assertNotEquals(contractData.subscriptions.size(), 0);
            System.assertNotEquals(contractData.assets.size(), 0);
            System.assertNotEquals(contractData.yObjectsList.size(), 0);
        }
        Test.stopTest();
    }

    @IsTest
    static void test_patchLineNumbersOnXobject_contract() {
    	Test.startTest();
        // query contracts:
        List<Contract> createdContracts = [SELECT Id FROM Contract];
        Set<Id> contractIdSet = new Set<Id>();
        for(Contract c : createdContracts) {
            contractIdSet.add(c.Id);
        }

        CPQU_BundleStructureUtils.patchLineNumbersOnXobject(contractIdSet);

        System.assertNotEquals(CPQU_BundleStructureUtils.xObjectIdTo_xObjectDataMap.values().size(), 0);
        Test.stopTest();
    }

    @IsTest
    static void test_patchLineNumbersOnXobject_quote() {
    	Test.startTest();
    	Map<Id, SBQQ__Quote__c> quoteMap = new Map<Id, SBQQ__Quote__c>([SELECT Id FROM SBQQ__Quote__c]);
    	System.debug('quoteMap: ' + quoteMap);

    	Set<Id> quoteIdSet = quoteMap.keySet();

        CPQU_BundleStructureUtils.patchLineNumbersOnXobject(quoteIdSet);
        System.assertNotEquals(CPQU_BundleStructureUtils.xObjectIdTo_xObjectDataMap.values().size(), 0);
        Test.stopTest();
    }

    @IsTest
    static void test_rootIdSetter_Contract() {
        Id contractId = [SELECT Id FROM Contract LIMIT 1].Id;
    	Test.startTest();
        // Set root Id on the contract's subscriptions/assets:
        CPQU_BundleStructureUtils.rootIdSetter(contractId);
        Test.stopTest();

        List<SBQQ__Subscription__c> contractSubs = [SELECT Id, SBQQ__RootId__c FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c = :contractId];
        for(SBQQ__Subscription__c subscription : contractSubs) {
            // verify that root id got set on the contract's subscriptions:
            System.assertNotEquals(subscription.SBQQ__RootId__c, null);
        }
    }

    @IsTest
    static void test_cloneBundlesAssets() {
        Test.startTest();
        CPQU_BundleStructureUtils.signalToQueryAllLineFields();
        // query contracts:
        String sourceContractQuery = 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('Contract') + ' FROM Contract LIMIT 1';
        Contract sourceContract = Database.query(sourceContractQuery);
        Contract targetContract = sourceContract.clone(false, false);
        insert targetContract;

        Asset sourceUltimateAsset = [
            SELECT Id FROM Asset 
            WHERE SBQQ__RequiredById__c = NULL AND AccountId = :sourceContract.AccountId LIMIT 1
        ];

        // clone a bundle from source contract to target contract:
        Map<Id, SObject> lineClones = CPQU_BundleStructureUtils.cloneBundles(sourceContract.Id, targetContract.Id, sourceContract.AccountId, sourceUltimateAsset.Id);
        Test.stopTest();

        System.assertNotEquals(lineClones.size(), 0);
        System.assertNotEquals(lineClones.size(), null);
    }

    @IsTest
    static void test_moveContractBundles() {
        Id contractId = [SELECT Id FROM Contract LIMIT 1].Id;
        // setup another Contract:
        Account account2 = new Account(Name = 'Test Account2');
        insert account2;

        CPQU_TestUtils cpqTestUtils = new CPQU_TestUtils();
        Contract c = cpqTestUtils.createContract(account2, false);
        c.AccountId = account2.Id;
        c.Status = 'Draft';
        insert c;
        
        Test.startTest();
        // Set root Id on the contract's subscriptions/assets:
        Map<Id, SObject> sObjectMap = CPQU_BundleStructureUtils.moveContractBundles(contractId, c.Id);
        Test.stopTest();

        System.assertNotEquals(sObjectMap.size(), 0);
    }

    @IsTest
    static void test_TriggerEnableDisable() {
        Set<String> setHandlerNames = new Set<String>();
        setHandlerNames.add('TestHandler');

        Test.startTest();
        CPQU_BundleStructureUtils bsu = new CPQU_BundleStructureUtils();
        CPQU_BundleStructureUtils.disableTriggers(true, setHandlerNames);

        System.assertEquals(true, CPQU_TriggerHandler.isBypassed('TestHandler'));
        
        CPQU_BundleStructureUtils.enableTriggers(true, setHandlerNames);
        
        System.assertEquals(false, CPQU_TriggerHandler.isBypassed('TestHandler'));

        Test.stopTest();
    }

    @IsTest
    static void test_DynamicOrderProductQuery() {
        
        Test.startTest();
        String sReturn = CPQU_BundleStructureUtils.getDynamicOrderProductQueryString(true);
        Test.stopTest();

        System.assertEquals(true, sReturn.startsWith('SELECT Id, SBQQ__BundleRoot__c, SBQQ__RequiredBy__c'));
     }
    
    @IsTest
    static void test_PageRef() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
    	
        String sCompareString = 'quote/le?qId=' + quote.Id;
        Test.startTest();
        PageReference pageRefReturn = CPQU_BundleStructureUtils.quoteLineEditorPageRef(quote.Id);
        Test.stopTest();

        //https://infobloxinc--DEV--sbqq.cs12.visual.force.com/apex/sb?id=a0lV0000001lS98IAE&scontrolCaching=1#quote/le?qId=a0lV0000001lS98IAE
        System.assertEquals(true, pageRefReturn.getUrl().endsWith(sCompareString));
    }

    @IsTest
    static void test_hasLineNumberSequencingIssues() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
    	
        Test.startTest();
        Boolean bReturn = CPQU_BundleStructureUtils.hasLineNumberSequencingIssues(quote.Id);
        Test.stopTest();

        System.assertEquals(true, bReturn);
    }

    @IsTest
    static void test_getBundleAggregations() {
        SBQQ__Quote__c quote = [SELECT Id FROM SBQQ__Quote__c LIMIT 1];
    	
        Test.startTest();
        Map<Integer, Set<Id>> returnMap = CPQU_BundleStructureUtils.getBundleAggregations(quote.Id, 10);
        Test.stopTest();

        System.assertEquals(true, returnMap.size() > 0);
    }

    @IsTest
    static void testPotentiallyCloneQuoteLineGroups() {
        Test.startTest();
        CPQU_BundleStructureUtils.signalToQueryAllLineFields();
        // query contracts:
        String sourceQuoteQuery = 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('SBQQ__Quote__c') + ' FROM SBQQ__Quote__c LIMIT 1';
        SBQQ__Quote__c sourceQuote = Database.query(sourceQuoteQuery);
        SBQQ__Quote__c targetQuote = sourceQuote.clone(false, false);
        insert targetQuote;

        SBQQ__QuoteLine__c sourceUltimateQuoteLine = [
                SELECT Id FROM SBQQ__QuoteLine__c
                WHERE SBQQ__RequiredBy__c = NULL AND SBQQ__Quote__r.SBQQ__Account__c = :sourceQuote.SBQQ__Account__c LIMIT 1
        ];

        Product2 subProduct = [SELECT Id FROM Product2 WHERE SBQQ__SubscriptionBase__c = 'List' LIMIT 1];

        SBQQ__QuoteLine__c newQuoteLine = new SBQQ__QuoteLine__c(SBQQ__Quote__c = sourceQuote.Id,
                SBQQ__RequiredBy__c = sourceUltimateQuoteLine.Id,
                SBQQ__Product__c = subProduct.Id);
        insert newQuoteLine;

        SBQQ__QuoteLineGroup__c quoteLineGroup = new SBQQ__QuoteLineGroup__c(SBQQ__Account__c = sourceQuote.SBQQ__Account__c,
                SBQQ__Quote__c = sourceQuote.Id, Name = 'Test Group');
        insert quoteLineGroup;

        sourceUltimateQuoteLine.SBQQ__Group__c = quoteLineGroup.Id;
        update sourceUltimateQuoteLine;

        // clone a bundle from source contract to target contract:
        Map<Id, SObject> lineClones = CPQU_BundleStructureUtils.cloneBundles(sourceQuote.Id, targetQuote.Id, sourceQuote.SBQQ__Account__c, sourceUltimateQuoteLine.Id);
        Test.stopTest();

        System.assertNotEquals(lineClones.size(), 0);
        System.assertNotEquals(lineClones.size(), null);
    }

    @IsTest
    static void testCloneXObjectHeader() {
        Id sourceQuoteId = [SELECT Id FROM SBQQ__Quote__c LIMIT 1].Id;
        Map<Integer, Set<Id>> bundleAggregationsMap = CPQU_BundleStructureUtils.getBundleAggregations(
                sourceQuoteId, 2, new Set<String>()
        );

        List<SBQQ__Quote__c> subSetQuotes = (List<SBQQ__Quote__c>) CPQU_BundleStructureUtils.cloneXObjectHeader(sourceQuoteId, null, bundleAggregationsMap.size(), false);
    }

    @IsTest
    static void testGetTierNumberBasicLvl1QL() {
        SBQQ__QuoteLine__c aQuoteLine = [SELECT Id, SBQQ__RequiredBy__c, SBQQ__RequiredBy__r.SBQQ__RequiredBy__c FROM SBQQ__QuoteLine__c WHERE SBQQ__RequiredBy__c = NULL LIMIT 1];
        System.assert(aQuoteLine != null);
        Integer result = CPQU_BundleStructureUtils.getTierNumBasic(aQuoteLine);
        System.assertEquals(1, result);
    }
 
}