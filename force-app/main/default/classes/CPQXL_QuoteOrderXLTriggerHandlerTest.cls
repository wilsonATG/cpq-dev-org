/**
 * 
 * CPQXL_QuoteOrderXLTriggerHandlerTest class
 *
 * Versioning: 
 *   3/22/21 : Steve Lohrenz : File Created
 */

@IsTest
private class CPQXL_QuoteOrderXLTriggerHandlerTest {
    @IsTest
    static void testGenerateLargeOrderTriggerHandler() {
        CPQU_TestUtils cpqTestUtils = new CPQU_TestUtils();
        CPQU_TestUtilsBilling cpqTestUtilsBilling = new CPQU_TestUtilsBilling();
        Account testAccount1 = cpqTestUtils.createAccount('Independent Retailer', false);

        Account testAccount = cpqTestUtils.createAccount('Distributor', false);
        insert new List<Account> {testAccount, testAccount1};

        System.assertNotEquals(null, testAccount.Id);

        Contract aContract = new Contract();
        aContract.Name = 'Test Contract';
        aContract.AccountId = testAccount.Id;
        insert aContract;

        Contact con = cpqTestUtils.createContact(testAccount, true);
        //Id PRODUCTSANDSERVRTYPE = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Products and Services').getRecordTypeId();

        Opportunity opp = cpqTestUtils.createOpportunity('Connecting Opp', testAccount, con, false);
        //opp.RecordTypeId = PRODUCTSANDSERVRTYPE;
        opp.StageName = 'Pre-Commit';
        opp.ForecastCategoryName = 'Commit';
        System.debug('@opp'+opp);
        insert opp;

        Product2 testProduct2 = new Product2();
        testProduct2.Name = 'Test Product';
        testProduct2.ProductCode = 'TestProduct';
        testProduct2.SBQQ__ChargeType__c = 'Recurring';
        testProduct2.SBQQ__BillingType__c = 'Advance';
        testProduct2.SBQQ__BillingFrequency__c = 'Monthly';
        testProduct2.blng__BillingRule__c = cpqTestUtilsBilling.createBillingRule(true).Id;
        testProduct2.blng__TaxRule__c = cpqTestUtilsBilling.createTaxRule(true).Id;
        testProduct2.blng__RevenueRecognitionRule__c = cpqTestUtilsBilling.createRevRecRule(true).Id;
        insert testProduct2;
        System.assertNotEquals(null, testProduct2.Id);

        Product2 testProduct = new Product2();
        testProduct.Name = 'Test Product1';
        testProduct.ProductCode = 'TestProduct1';
        testProduct.SBQQ__ChargeType__c = 'Recurring';
        testProduct.SBQQ__BillingType__c = 'Advance';
        testProduct.SBQQ__BillingFrequency__c = 'Monthly';
        insert testProduct;


        PricebookEntry testPricebookEntry = new PricebookEntry();
        testPricebookEntry.Product2Id = testProduct2.Id;
        testPricebookEntry.Pricebook2Id = Test.getStandardPricebookId();
        testPricebookEntry.UnitPrice = 1.00;
        insert testPricebookEntry;
        System.assertNotEquals(null, testPricebookEntry.Id);

        SBQQ__Quote__c renewalQuote = cpqTestUtils.createQuote(testAccount, opp, true, true, true);
        SBQQ__Quote__c quoteObj = new SBQQ__Quote__c();
        quoteObj.SBQQ__Status__c = 'Approved';
        quoteObj.SBQQ__Primary__c = true;
        quoteObj.SBQQ__StartDate__c = Date.today();
        quoteObj.SBQQ__EndDate__c = Date.today().addMonths(1);
        quoteObj.SBQQ__Opportunity2__c = opp.Id;
        quoteObj.SBQQ__SubscriptionTerm__c = 12;
        quoteObj.SBQQ__ExpirationDate__c = Date.today() + 30;
        quoteObj.SBQQ__Account__c = testAccount == null ? null : testAccount.Id;
        quoteObj.SBQQ__Type__c = 'Quote';
        quoteObj.SBQQ__PriceBook__c = Test.getStandardPricebookId();
        quoteObj.SBQQ__PricebookId__c = Test.getStandardPricebookId();
        insert quoteObj;

        /*SBQQ__Subscription__c testSubscription = new SBQQ__Subscription__c();
        testSubscription.SBQQ__Quantity__c = 1;
        //testSubscription.SBQQ__QuoteLine__c = qlObject.Id;
        testSubscription.SBQQ__Contract__c = aContract.Id;
        testSubscription.SBQQ__Quantity__c = 1;
        testSubscription.SBQQ__Product__c = testProduct2.Id;
        //testSubscription.Create_Software__c = true;
        insert testSubscription;
        Asset assetRec = IB_TestDataFactory.createAsset(testProduct2.Id,testAccount.Id);
        assetRec.Quantity = 1;
        update assetRec;*/

        SBQQ__QuoteLine__c qlObject = new SBQQ__QuoteLine__c();
        qlObject.SBQQ__Quote__c = quoteObj.Id;
        qlObject.SBQQ__Product__c = testProduct2.Id;
        qlObject.SBQQ__PricingMethod__c = testProduct2.SBQQ__PricingMethod__c;
        qlObject.SBQQ__StartDate__c = Date.today();
        qlObject.SBQQ__ListPrice__c = 100;

        qlObject.SBQQ__Quantity__c = 1;
        qlObject.SBQQ__RegularPrice__c = 100;
        qlObject.SBQQ__NetPrice__c = 100;
        qlObject.SBQQ__Number__c = 1;
        qlObject.SBQQ__ProrateMultiplier__c = 1;
        qlObject.SBQQ__SubscriptionPricing__c = testProduct2.SBQQ__SubscriptionPricing__c;
        qlObject.SBQQ__SubscriptionScope__c = 'Quote';
        qlObject.SBQQ__DefaultSubscriptionTerm__c = 1;
        qlObject.SBQQ__ChargeType__c = testProduct2.SBQQ__ChargeType__c;
        qlObject.SBQQ__BillingType__c = testProduct2.SBQQ__BillingType__c;
        qlObject.SBQQ__BillingFrequency__c = testProduct2.SBQQ__BillingFrequency__c;
        //qlObject.SBQQ__RenewedSubscription__c = testSubscription2.Id;
        //qlObject.SBQQ__UpgradedSubscription__c = testSubscription.Id;
        //qlObject.SBQQ__UpgradedAsset__c = assetRec.Id;

        insert qlObject;


        //testSubscription.SBQQ__QuoteLine__c = qlObject.Id;

        //update testSubscription;

        //Id OrderRecordTypeId = Schema.SObjectType.Order.getRecordTypeInfosByName().get('RMA Order').getRecordTypeId();
        Test.startTest();
        Order testOrder = new Order();
        //testOrder.RecordTypeId = OrderRecordTypeId;
        testOrder.AccountId = testAccount.Id;
        testOrder.OpportunityId = opp.Id;
        testOrder.Type = 'Return to stock for credit';
        testOrder.Status = 'Draft';
        testOrder.EffectiveDate = System.today();
        testOrder.Pricebook2Id = Test.getStandardPricebookId();
        testOrder.blng__BillingDayOfMonth__c = '1';
        insert testOrder;
        System.assertNotEquals(null, testOrder.Id);

        OrderItem testOrderItem = new OrderItem();
        testOrderItem.OrderId = testOrder.Id;
        testOrderItem.Quantity = 1;
        testOrderItem.UnitPrice = 1.00;
        testOrderItem.PricebookEntryId = testPricebookEntry.Id;
        //testOrderItem.Defective_Serial_Number__c = '234098';
        //testOrderItem.Fulfillment_Status__c = 'Fulfillment Complete';
        testOrderItem.SBQQ__QuoteLine__c = qlObject.Id;
        testOrderItem.SBQQ__ChargeType__c = testProduct2.SBQQ__ChargeType__c;
        testOrderItem.SBQQ__BillingType__c = testProduct2.SBQQ__BillingType__c;
        testOrderItem.SBQQ__BillingFrequency__c = testProduct2.SBQQ__BillingFrequency__c;
        testOrderItem.blng__BillingRule__c = testProduct2.blng__BillingRule__c;
        testOrderItem.blng__TaxRule__c = testProduct2.blng__TaxRule__c;
        testOrderItem.blng__RevenueRecognitionRule__c =  testProduct2.blng__RevenueRecognitionRule__c;
        insert testOrderItem;

        System.assertNotEquals(null, testOrderItem.Id);

        Test.stopTest();
        Set<Id> setRemainingQuoteIds = new Set<Id>{renewalQuote.Id};
        String remainingSubSetQuoteIdsJSON = JSON.serialize(setRemainingQuoteIds);
        Set<Id> setSubsetOrderIds = new Set<Id>{testOrder.Id};
        String subsetOrderIdsCreatedJSON = JSON.serialize(setSubsetOrderIds);

        List<CPQXL_GenerateLargeOrderEvent__e> listShipmentDetails = new List<CPQXL_GenerateLargeOrderEvent__e>();
        CPQXL_GenerateLargeOrderEvent__e shipDetailsEvent = new CPQXL_GenerateLargeOrderEvent__e(CPQXL_SourceQuoteId__c = quoteObj.Id,
            CPQXL_SourceContext__c = 'Opportunity', CPQXL_OpportunityId__c = opp.Id,CPQXL_RemainingSubsetQuoteIds__c=remainingSubSetQuoteIdsJSON);
        listShipmentDetails.add(shipDetailsEvent);
        EventBus.publish(listShipmentDetails);
        Test.getEventBus().deliver();

        List<CPQXL_GenerateLargeOrderEvent__e> listShipmentDetails1 = new List<CPQXL_GenerateLargeOrderEvent__e>();
        CPQXL_GenerateLargeOrderEvent__e shipDetailsEvent1 = new CPQXL_GenerateLargeOrderEvent__e(CPQXL_SourceQuoteId__c = quoteObj.Id,
            CPQXL_SourceContext__c = 'Opportunity', CPQXL_OpportunityId__c = opp.Id,CPQXL_RemainingSubsetQuoteIds__c='');
        listShipmentDetails1.add(shipDetailsEvent1);
        EventBus.publish(listShipmentDetails1);
        Test.getEventBus().deliver();
    }
}