/**
 * 
 * CPQU_TestsCache class
 *
 * Versioning: 
 *   3/26/21 : Steve Lohrenz : File Created
 */

@IsTest
public class CPQU_TestsCache {
    // by caching into static variables - this allows us to reference them without re-querying
    // only works if we do not use a 'testSetup' method
    private static CPQU_TestCacheExtendedInterface cpqTestCacheExtendedInterface;
    private static final String EXTENDED_CLASS_KEY_STRING = 'CPQ_TestCacheExtendedIntName';
    private static Map<String, Id> extendedClassObjects = new Map<String, Id>();

    static {
        List<CPQU_UtilitySetting__mdt> metaDataExtendedClassList = [SELECT DeveloperName, TextValue__c FROM CPQU_UtilitySetting__mdt WHERE DeveloperName = :EXTENDED_CLASS_KEY_STRING AND IsActive__c = TRUE LIMIT 1];
        if (metaDataExtendedClassList.isEmpty() || String.isBlank(metaDataExtendedClassList.get(0).TextValue__c)) {
            cpqTestCacheExtendedInterface = new CPQ_TestCacheExtendedDefault();
        } else {
            // Get the Type corresponding to the class name
            Type classType = Type.forName(metaDataExtendedClassList.get(0).TextValue__c);

            // Instantiate the type.
            // The type of the instantiated object
            //   is the interface.
            cpqTestCacheExtendedInterface = (CPQU_TestCacheExtendedInterface) classType.newInstance();
        }
    }

    /****************************************
    ***** Begin test data setup methods *****
    *****************************************/

    // Static high level variables:
    public static Integer bulkRecordSize = 50; // number of quotes to create. feel free to adjust
    public static Boolean printQueries = false; // Toggle to true to turn on query stat logging for dml statements
    public static List<Account> acctList;
    public static List<Opportunity> oppList;
    public static List<Product2> productList;
    public static Id standardPricebookId;
    public static Pricebook2 customPricebook;
    public static List<PricebookEntry> standardPbEntryList;
    public static List<PricebookEntry> customPbEntryList;
    public static List<SBQQ__Quote__c> quoteList;
    public static List<SBQQ__QuoteLine__c> quoteLineList;
    public static List<Contract> contractList;
    public static Order order;
    public static SBQQ__QuoteProcess__c qp;
    // populate the additionalProductsToCreate from the code calling this class, to optionally create more products:
    public static List<Product2> additionalProductsToCreate = new List<Product2>();


    // Query the Quotes and all their fields:
    private static List<SBQQ__Quote__c> queryQuotes(List<SBQQ__Quote__c> quotes) {
        return CPQU_TestUtils.queryRecordsFromIdsAndObjectName(
                (new Map<Id, SBQQ__Quote__c>(quotes)).keySet(),  // Set<Id> idSet (to bind to in where clause)
                'SBQQ__Quote__c',                               // String objectName
                'WHERE Id IN :idSet'                            // String whereClause
        );
    }

    // Query the Quote Lines and all their fields:
    private static List<SBQQ__QuoteLine__c> queryQuoteLines(List<SBQQ__QuoteLine__c> quoteLines) {
        return CPQU_TestUtils.queryRecordsFromIdsAndObjectName(
                (new Map<Id, SBQQ__QuoteLine__c>(quoteLines)).keySet(),  // Set<Id> idSet (to bind to in where clause)
                'SBQQ__QuoteLine__c',                                   // String objectName
                'WHERE Id IN :idSet'                                    // String whereClause
        );
    }

    // Setup common test data:
    public static void initialSetup() {
        initialSetup(true /*boolean createAdditionalBillingObjects*/); //#SFBILLING -> Change false to true
    }

    public static void initialSetup(Boolean createAdditionalBillingObjects) {
        // Setup all custom settings needed
        setupCustomSettings();

        // Create an Account with default values populated:
        acctList = new List<Account>();

        Account acct = new Account(Name = 'Test Account');
        // Create more accounts here if desired...

        acctList.add(acct);

        // Insert Accounts:
        insert acctList;

        // get standard pricebook:
        standardPricebookId = Test.getStandardPricebookId();
        // Create custom Pricebook:

        customPricebook = new CPQU_TestUtils().createPriceBook(
                'CPQ',      // String name
                true,       // Boolean isActive
                'USD',      // String currencyIsoCode
                true,       // Boolean populateDefaultValues
                false       // Boolean doInsert
        );

        // Insert custom Pricebook:
        insert customPricebook;

        // Create Opportunities:
        oppList = new List<Opportunity>();
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = System.today());
        opp.AccountId = acctList[0].Id;
        opp.Pricebook2Id = customPricebook.Id;
        oppList.add(opp);

        // Insert Opportunities:
        insert oppList;

        qp = new SBQQ__QuoteProcess__c();
        qp.Name = 'Test Quote Process';
        qp.SBQQ__Default__c = true;
        insert qp;

        // Create SF Billing data if applicable:
        if (createAdditionalBillingObjects) {
            extendedClassObjects = cpqTestCacheExtendedInterface.initialSetupAdditional();
        }
    }

    public static void setupProducts() {
        // Create Products:
        productList = new List<Product2>();
        // Subscription product:
        productList.add(new CPQU_TestUtils().createProduct(
                'Product ABC',              // String name
                'Subscription',             // String productType
                'GC1060',                   // String productCode
                extendedClassObjects.get('blng__BillingRule__c'), //#SFBILLING - If Billing installed, remove 'null,'' and de-comment 'Id billingRule.Id,'
                extendedClassObjects.get('blng__TaxRule__c'), //#SFBILLING - If Billing installed, remove 'null,'' and de-comment 'Id billingRule.Id,'
                extendedClassObjects.get('blng__RevenueRecognitionRule__c'), //#SFBILLING - If Billing installed, remove 'null,'' and de-comment 'Id billingRule.Id,'
                true,                       // Boolean populateDefaultValues
                false                       // Boolean doInsert
        ));
        // Non-Subscription product:
        productList.add(new CPQU_TestUtils().createProduct(
                'Product XYZ',          // String name
                'Non-Subscription',     // String productType
                'GC1020',               // String productCode
                extendedClassObjects.get('blng__BillingRule__c'), //#SFBILLING - If Billing installed, remove 'null,'' and de-comment 'Id billingRule.Id,'
                extendedClassObjects.get('blng__TaxRule__c'), //#SFBILLING - If Billing installed, remove 'null,' and de-comment 'Id taxRule.Id,'
                extendedClassObjects.get('blng__RevenueRecognitionRule__c'), //#SFBILLING - If Billing installed, remove 'null,' and de-comment 'Id revRecRuleId.Id,'
                true,                   // Boolean populateDefaultValues
                false                   // Boolean doInsert
        ));

        // If the code calling this class specified additional products to create:
        if (!additionalProductsToCreate.isEmpty()) {
            productList.addAll(additionalProductsToCreate);
        }

        // Insert Products:
        insert productList;
    }

    public static List<Product2> setupAdditionalProducts(Integer numberOfAdditionalProducts) {

        if (numberOfAdditionalProducts <= 0) {
            return new List<Product2>();
        }

        List<String> productTypes = new List<String> {'Subscription', 'Non-Subscription'};

        CPQU_TestUtils testUtils = new CPQU_TestUtils();
        List<Product2> products = new List<Product2>();

        for (Integer i = 0; i < numberOfAdditionalProducts; i++) {
            products.add(
                testUtils.createProduct(
                    'Product ' + Math.round(Math.random() * 1000000),                            // String name
                    productTypes[Math.mod(numberOfAdditionalProducts, productTypes.size())],     // String productType
                    'CODE-' + Math.round(Math.random() * 1000000),                               // String productCode
                    extendedClassObjects.get('blng__BillingRule__c'),             //#SFBILLING - If Billing installed, remove 'null,'' and de-comment 'Id billingRule.Id,'
                    extendedClassObjects.get('blng__TaxRule__c'),                 //#SFBILLING - If Billing installed, remove 'null,' and de-comment 'Id taxRule.Id,'
                    extendedClassObjects.get('blng__RevenueRecognitionRule__c'), //#SFBILLING - If Billing installed, remove 'null,' and de-comment 'Id revRecRuleId.Id,'
                    true,                   // Boolean populateDefaultValues
                    false                   // Boolean doInsert
                )
            );
        }

        if (additionalProductsToCreate == null) {
            additionalProductsToCreate = new List<Product2>();
        }

        additionalProductsToCreate.addAll(products);
        return products;
    }

    public static void setupPricebookEntries() {
        // Create Pricebook entries for each product:
        standardPbEntryList = new List<PricebookEntry>();
        customPbEntryList = new List<PricebookEntry>();
        for (Product2 p : productList) {
            // Create standard Pricebook entries for each product:
            PricebookEntry pbEntry = new CPQU_TestUtils().createPriceBookEntry(
                    p,      // Product2 product
                    null,   // Pricebook2 priceBook (Null will make it default to the Standard Pricebook)
                    true,   // Boolean populateDefaultValues
                    false   // Boolean doInsert
            );
            standardPbEntryList.add(pbEntry);

            // Create custom Pricebook entries for each product:
            PricebookEntry pbEntry2 = new CPQU_TestUtils().createPriceBookEntry(
                    p,          // Product2 product
                    customPricebook,  // Pricebook2 priceBook (CPQ pricebook)
                    true,       // Boolean populateDefaultValues
                    false       // Boolean doInsert
            );
            customPbEntryList.add(pbEntry2);
        }

        // Insert Pricebook Entries:
        List<PricebookEntry> allPbEntries = new List<PricebookEntry>();
        allPbEntries.addAll(standardPbEntryList);
        allPbEntries.addAll(customPbEntryList);
        insert allPbEntries;
    }

    // Method to create quotes:
    public static void setupQuotes(Boolean startTests, Boolean stopTests) {
        if (productList == null) {
            setupProducts();
        }
        if (standardPbEntryList == null || customPbEntryList == null) {
            setupPricebookEntries();
        }

        if (startTests) {
            Test.startTest();
        }
        // Bulk create quotes, with one of them being primary:
        quoteList = new List<SBQQ__Quote__c>();
        for (Integer i = 0; i < bulkRecordSize; i++) {
            Boolean createAsPrimary = false;
            if (i == 0) {
                // Mark one of the quotes as primary:
                createAsPrimary = true;
            }
            SBQQ__Quote__c q = new CPQU_TestUtils().createQuote(
                    null,               // Account acct,
                    oppList[0],         // Opportunity opp,
                    createAsPrimary,    // Boolean isPrimary,
                    true,               // Boolean populateDefaultValues
                    false               // Boolean doInsert
            );
            q.SBQQ__Account__c = acctList[0].Id;
            q.SBQQ__PriceBook__c = customPricebook.Id;
            q.SBQQ__PricebookId__c = customPricebook.Id;
            q.SBQQ__QuoteProcessId__c = qp.Id;
            quoteList.add(q);
        }

        // Insert Quotes:
        insert quoteList;

        if (stopTests) {
            Test.stopTest();
        }
    }

    // Method to create quote lines:
    public static void setupQuoteLines(List<SBQQ__Quote__c> quoteList, List<Product2> productList, Boolean startTests, Boolean stopTests) {
        if (startTests) {
            Test.startTest();
        }
        // Create quote lines for each quote (# of quote lines per quote = # of products created above):
        quoteLineList = new List<SBQQ__QuoteLine__c>();
        for (SBQQ__Quote__c q : quoteList) {
            for (Integer i = 0; i < productList.size(); i++) {
                // For each quote, create as many quote lines as there are products:
                SBQQ__QuoteLine__c ql = new CPQU_TestUtils().createQuoteLine(
                        productList[i],      // Product2 product,
                        customPbEntryList[i],  // PricebookEntry pbe
                        q,      // SBQQ__Quote__c quote,
                        true,   // Boolean populateDefaultValues
                        false   // Boolean doInsert
                );
                quoteLineList.add(ql);
            }
        }

        // Insert Quote Lines:
        insert quoteLineList;

        if (stopTests) {
            Test.stopTest();
        }
    }

    public static void setupQuotesAndQuoteLines() {
        setupQuotesAndQuoteLines(false, false, false, false);
    }

    // Method to setup ALL test data needed for Quotes and Quote lines:
    public static void setupQuotesAndQuoteLines(Boolean quoteStartTests, Boolean quoteStopTests, Boolean quoteLineStartTests, Boolean quoteLineStopTests) {
        // Setup test data needed for Salesforce CPQ quotes:
        setupQuotes(
                quoteStartTests,                // Boolean quoteStartTests
                quoteStopTests                  // Boolean quoteStopTests
        );

        // Setup test data needed for Salesforce CPQ quoteLines:
        setupQuoteLines(
                quoteList,              // List<SBQQ__Quote__c> quoteList
                productList,            // List<Product2> productList
                quoteLineStartTests,    // Boolean startTests
                quoteLineStopTests      // Boolean stopTests
        );

        // Query the quotes created:
        quoteList = queryQuotes(quoteList);
        // Query the quote lines created:
        quoteLineList = queryQuoteLines(quoteLineList);
    }

    // Get a contract, which resulted in contracting an opportunity, into a state where it can be marked for renewal:
    public static void setupContractForRenewal(String contractedSource) {
        // Set up all test data leading up to contracting the Opportunity:
        setupQuotesAndQuoteLines(
                false,  // Boolean quoteStartTests
                false,  // Boolean quoteStopTests
                false,  // Boolean quoteLineStartTests
                false   // Boolean quoteLineStopTests
        );

        if (contractedSource == 'Opportunity') {
            // Contract one of the Opportunities, not by marking the Opportunity 'Contracted',
            // but by manually creating the contract in apex (due to multiple asynchronous thread limitation):
            Contract con = new CPQU_TestUtils().createContract(
                    acctList[0],    // Account acct
                    customPricebook.Id,   // Id pricebookId
                    oppList[0],     // Opportunity opp
                    null,           // Order order
                    quoteList[0],   // SBQQ__Quote__c quote
                    false           // Boolean doInsert
            );

            contractList = new List<Contract>{
                    con
            };
            insert contractList;

        } else if (contractedSource == 'Order') {
            // Create the order:
            order = new CPQU_TestUtils().createAutomatedOrderFromOpportunity(oppList[0].Id);
            order.SBQQ__PriceCalcStatus__c = 'Completed';

            // Activate the Order:
            List<OrderItem> orderItems = new CPQU_TestUtils().activateOrder(order);

            // Contract the Order, not by marking the Order 'Contracted',
            // but by manually creating the contract in apex (due to multiple asynchronous thread limitation):
            Contract con = new CPQU_TestUtils().createContract(
                    acctList[0],    // Account acct
                    customPricebook.Id,   // Id pricebookId
                    null,           // Opportunity opp
                    order,          // Order order
                    quoteList[0],   // SBQQ__Quote__c quote
                    false           // Boolean doInsert
            );

            contractList = new List<Contract>{
                    con
            };
            insert contractList;
        }

        // Activate the Contract:
        contractList[0].Status = 'Activated';
        update contractList[0];
    }

    public static void setupCustomSettings() {
        setupCPQUtilitiesFeatures(true);
    }

    public static CPQU_Features__c setupCPQUtilitiesFeatures(Boolean doInsert) {
        CPQU_Features__c utilityFeatures = new CPQU_Features__c(
            AllTriggerHandlersDisabled__c = false,
            CPQU_ErrorLogEventTriggerHandler__c = false
        );

        if (doInsert) {
            insert utilityFeatures;
        }

        return utilityFeatures;
    }

    /**************************************
    ***** End test data setup methods *****
    **************************************/

    /*****************************
    ***** Begin test methods *****
    *****************************/

    // TODO: fix AUTOMATIC asset creation (might not be possible in a multiple asynchronous thread context)
    @IsTest
    public static void test_quoteAndQuoteLineCreation() {
        // Setup all test data leading up to after quotes and quote lines are created:
        initialSetup();
        setupQuotesAndQuoteLines(
                true,   // Boolean quoteStartTests
                false,  // Boolean quoteStopTests
                false,  // Boolean quoteLineStartTests
                true    // Boolean quoteLineStopTests
        );

        /*********************
        ***** Assertions *****
        *********************/

        // Verify Quotes got created:
        System.assertNotEquals(quoteList, null);
        System.assertNotEquals(quoteList.size(), 0, 'No Quotes were created.');

        // Verify PriceBook got assigned to the quotes:
        for (SBQQ__Quote__c q : quoteList) {
            System.assertEquals(q.SBQQ__PriceBook__c, customPricebook.Id);
        }

        // Verify Quote Lines got created:
        System.assertNotEquals(quoteLineList, null);
        System.assertNotEquals(quoteLineList.size(), 0, 'No Quote Lines were created.');

        // Verify PriceBook entries got assigned to the quote lines:
        for (SBQQ__QuoteLine__c ql : quoteLineList) {
            System.assertNotEquals(ql.SBQQ__PricebookEntryId__c, null, 'Quote lines have null price book entries.');
        }

        // Verify Opp products got created:
        List<OpportunityLineItem> oliList = [SELECT Id, SBQQ__QuoteLine__c FROM OpportunityLineItem];
        System.assertNotEquals(oliList.size(), 0, 'No Opportunity products were created');

    }

    /*****************************************************
    ***** Test methods related to Automated Ordering *****
    *****************************************************/

    @IsTest
    public static void test_orderingOfQuote() {
        // Set up all test data leading up to marking the Quote as 'Ordered':
        initialSetup();
        setupQuotesAndQuoteLines();

        Test.startTest();
        // quoteList[0] is already primary. Mark the quote as ordered:
        order = new CPQU_TestUtils().createAutomatedOrderFromQuote(quoteList[0].Id);
        Test.stopTest();

        /*********************
        ***** Assertions *****
        *********************/

        // Verify primary Quote Pricebook matches that of its Opportunity:
        Opportunity opp = [
                SELECT Id, Pricebook2Id
                FROM Opportunity
                WHERE SBQQ__PrimaryQuote__c = :quoteList[0].Id
        ];
        System.assertEquals(quoteList[0].SBQQ__PriceBook__c, opp.Pricebook2Id, 'Quote Pricebook does not match Opportunity Pricebook');

        // Verify Opportunity Products were automatically created:
        System.assertEquals([
                SELECT Id, OpportunityId
                FROM OpportunityLineItem
                WHERE OpportunityId = :opp.Id
        ].isEmpty(), false,
                'No Opportunity Products were created');

        // Verify that the Order was automatically created for the quote:
        System.assertEquals(order.SBQQ__Quote__c, quoteList[0].Id, 'No Orders were created.');

        // Verify that Order products were automatically created:
        System.assertEquals([
                SELECT Id
                FROM OrderItem
                WHERE OrderId = :order.Id
        ].isEmpty(), false,
                'No Order Products were created.');

    }

    @IsTest
    public static void test_orderingOfOpportunity() {
        // Set up all test data leading up to ordering the Opportunity:
        initialSetup();
        setupQuotesAndQuoteLines();

        Test.startTest();
        // oppList[0] is already associated to a primary quote
        order = new CPQU_TestUtils().createAutomatedOrderFromOpportunity(oppList[0].Id);
        Test.stopTest();

        /*********************
        ***** Assertions *****
        *********************/

        // Assert the order:
        System.assertNotEquals(order, null, 'No Orders were created.');
        System.assertEquals(order.OpportunityId, oppList[0].Id, 'Order is not associated with Opportunity.');
        System.assertEquals(order.SBQQ__Quote__c, quoteList[0].Id, 'Order is not associated with quote.');
    }

    /********************************************************
    ***** Test methods related to automated contracting *****
    ********************************************************/

    @IsTest
    public static void test_contractingOfOpportunity() {
        // Set up all test data leading up to contracting the Opportunity:
        initialSetup();
        setupQuotesAndQuoteLines();

        // Contract one of the Opportunities (oppList[0] is already associated to a primary quote):
        contractList = new CPQU_TestUtils().contractOpportunity(
                oppList[0],     // Opportunity opp
                true,           // Boolean startTests
                true            // Boolean stopTests
        );

        /*********************
        ***** Assertions *****
        *********************/

        // Assert contracts:
        System.assertNotEquals(contractList.isEmpty(), true, 'No contracts were created when Opportunity was contracted.');
        System.assertEquals(contractList[0].SBQQ__Opportunity__c, oppList[0].Id, 'Contract was not associated to opportunity.');
        System.assertEquals(contractList[0].SBQQ__Quote__c, quoteList[0].Id, 'Contract was not associated to primary quote.');

        // Verify Contracts got automatically created:
        System.assertNotEquals(contractList.isEmpty(), true, 'No contracts were created when Opportunity was contracted.');
        for (Contract c : contractList) {
            System.assertEquals(c.SBQQ__Opportunity__c, oppList[0].Id, 'Contract was not associated to Opportunity');
            for (SBQQ__Subscription__c sub : c.SBQQ__Subscriptions__r) {
                // Verify Subscriptions got associated to Contract:
                System.assertEquals(sub.SBQQ__Contract__c, c.Id, 'Subscriptions were not associated to Contract.');
            }
        }
    }

    @IsTest
    public static void test_contractingOfOrderCreatedFromOpportunity() {
        // Set up all test data leading up to creating automated Order from Opportunity
        initialSetup();
        setupQuotesAndQuoteLines();

        // Create order from opportunity (oppList[0] is already associated to a primary quote):
        order = new CPQU_TestUtils().createAutomatedOrderFromOpportunity(oppList[0].Id);
        order.SBQQ__PriceCalcStatus__c = 'Completed';

        // Activate the Order:
        List<OrderItem> orderItems = new CPQU_TestUtils().activateOrder(order);

        // Contract the Order:
        contractList = new CPQU_TestUtils().contractOrder(
                order,  // Order order
                true,   // Boolean startTests
                true    // Boolean stopTests
        );

        /*********************
        ***** Assertions *****
        *********************/

        // Verify contracts got automatically created and assigned to the correct quote:
        System.assertNotEquals(contractList.isEmpty(), true, 'No contracts were created when the Order (created from Opportunity) was Contracted.');
        System.assertEquals(contractList[0].SBQQ__Quote__c, quoteList[0].Id);

        // Verify orderItems got created for the order:
        System.assertNotEquals(orderItems, null, 'Order products were not created when the order (created from Opportunity) was contracted.');
        for (OrderItem oi : orderItems) {
            System.assertEquals(oi.OrderId, order.Id, 'Order products did not get assigned to order.');
        }
    }

    @IsTest
    public static void test_contractingOfOrderCreatedFromQuote() {
        // Set up all test data leading up to creating automated Order from Quote:
        initialSetup();
        setupQuotesAndQuoteLines();

        // Create order from quote (quoteList[0] is already primary):
        order = new CPQU_TestUtils().createAutomatedOrderFromQuote(quoteList[0].Id);
        order.SBQQ__PriceCalcStatus__c = 'Completed';

        // Activate the Order:
        List<OrderItem> orderItems = new CPQU_TestUtils().activateOrder(order);

        // Contract the Order:
        contractList = new CPQU_TestUtils().contractOrder(order,
                true,   // Boolean startTests;
                true    // Boolean stopTests;
        );

        /*********************
        ***** Assertions *****
        *********************/

        // Verify Contracts got automatically created:
        System.assertNotEquals(contractList.isEmpty(), true, 'No contracts were created when the Order (created from Quote) was Contracted.');
        for (Contract c : contractList) {
            System.assertEquals(c.SBQQ__Order__c, order.Id, 'Contract was not associated to Order');
            for (SBQQ__Subscription__c sub : c.SBQQ__Subscriptions__r) {
                // Verify Subscriptions got associated to Contract:
                System.assertEquals(sub.SBQQ__Contract__c, c.Id, 'Subscriptions were not associated to Contract.');
            }
        }
    }

    @IsTest
    public static void test_assetAndSubscriptionGenerationFromContractedOpp() {
        // Set up all test data leading up to contracting the Opportunity:
        initialSetup();
        setupQuotesAndQuoteLines();

        // Query the Contract (oppList[0] is already associated to a primary quote):
        contractList = new CPQU_TestUtils().contractOpportunity(
                oppList[0],     // Opportunity opp
                true,           // Boolean startTests
                true            // Boolean stopTests
        );

        // Create new asset records for each account
        // (TODO: contracting an opp generates a contract, but no assets - this might be because contracting
        // an opp queues up 2 asynchronous threads - 1 to generate the contract, and 1 to generate the assets.
        Asset asset = new CPQU_TestUtils().createAsset(
                acctList[0], //Account acct
                productList[0],       // Product2 product
                quoteLineList[0], //SBQQ__QuoteLine__c quoteLine
                true,   // Boolean populateDefaultValues
                true    // Boolean doInsert
        );

        /*********************
        ***** Assertions *****`
        *********************/

        // Verify Asset got created on Account:
        // TODO: fix assets not getting created automatically :
        List<Asset> assetList = [SELECT Id FROM Asset WHERE AccountId = :acctList[0].Id];
        System.assertNotEquals(assetList.size(), 0, 'Assets were not created on Account.');

        // Verify Subscriptions got created for the Contract:
        List<SBQQ__Subscription__c> subscriptionList = [
                SELECT Id
                FROM SBQQ__Subscription__c
                WHERE SBQQ__Account__c = :acctList[0].Id
                AND SBQQ__Contract__c = :contractList[0].Id
        ];
        System.assertNotEquals(subscriptionList.isEmpty(), true, 'Subscriptions were not created on Account.');
    }

    /***************************************************
   ***** Test methods related to contract renewals *****
   *****************************************************/


    @IsTest
    // public static void test_renewalForecast_contractedFromOpp() {
    //     // Set up all test data leading up to just after contracting the Opportunity:
    //     initialSetup();
    //     setupContractForRenewal('Opportunity');

    //     Test.startTest();
    //     System.debug('CPQU_TestsCache.test_renewalForecast_contractedFromOpp just before updating contract');
    //     contractList[0].SBQQ__MasterContract__c = true; // this is apparently required if you don't want the test method marked with (SeeAllData=true)
    //     // Mark Renewal Forecast on the Contract:
    //     contractList[0].SBQQ__RenewalForecast__c = true;
    //     update contractList[0];
    //     Test.stopTest();

    //     /*********************
    //     ***** Assertions *****
    //     *********************/

    //     // Verify that a renewal Opportunity was automatically created for the Contract:
    //     Contract queriedContract = [SELECT Id, SBQQ__RenewalOpportunity__c FROM Contract WHERE Id = :contractList[0].Id];
    //     System.assertNotEquals(queriedContract, null);
    //     System.assertNotEquals(queriedContract.SBQQ__RenewalOpportunity__c, null, 'Renewal Opportunity not generated for Contract.');

    // }

    public static void test_renewalQuoted_contractedFromOpp() {
        // Set up all test data leading up to just after contracting the Opportunity:
        initialSetup();
        setupContractForRenewal('Opportunity');

        Test.startTest();
        contractList[0].SBQQ__MasterContract__c = true; // this is apparently required if you don't want the test method marked with (SeeAllData=true)
        // Mark Renewal Quoted on the Contract:
        contractList[0].SBQQ__RenewalQuoted__c = true;
        update contractList[0];
        Test.stopTest();

        /*********************
        ***** Assertions *****
        *********************/

        // Verify that a renewal Opportunity was automatically created for the Contract:
        contractList = [SELECT Id, SBQQ__RenewalOpportunity__c, SBQQ__Opportunity__c FROM Contract WHERE Id = :contractList[0].Id];
        System.assertNotEquals(contractList[0].SBQQ__RenewalOpportunity__c, null, 'Renewal Opportunity not generated for Contract.');

        for (Contract c : contractList) {
            // Verify Contracts got associated to Opportunity:
            System.assertEquals(c.SBQQ__Opportunity__c, oppList[0].Id, 'Contract was not associated to Opportunity');
            for (SBQQ__Subscription__c sub : c.SBQQ__Subscriptions__r) {
                // Verify Subscriptions got associated to Contract:
                System.assertEquals(sub.SBQQ__Contract__c, c.Id, 'Subscriptions were not associated to Contract.');
            }
        }

        // Verify that a renewal Quote was automatically created for the Contract:
        SBQQ__Quote__c renewalQuote = [SELECT Id, SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c = :contractList[0].SBQQ__RenewalOpportunity__c];
        System.assertNotEquals(renewalQuote.SBQQ__Opportunity2__c, null, 'Renewal Quote not generated for Contract.');
    }

    public static void test_renewalForecast_contractedFromOrder() {
        // Set up all test data leading up to just after contracting the Order:
        initialSetup();
        setupContractForRenewal('Order');

        Test.startTest();
        contractList[0].SBQQ__MasterContract__c = true; // this is apparently required if you don't want the test method marked with (SeeAllData=true)
        // Mark Renewal Forecast on the Contract:
        contractList[0].SBQQ__RenewalForecast__c = true;
        update contractList[0];
        Test.stopTest();

        /*********************
        ***** Assertions *****
        *********************/

        // Verify that a renewal Opportunity was automatically created for the Contract (we need to re-query the contract due to automation within the package):
        contractList = [SELECT Id, SBQQ__RenewalOpportunity__c, SBQQ__Order__c FROM Contract WHERE Id = :contractList[0].Id];
        System.assertNotEquals(contractList[0].SBQQ__RenewalOpportunity__c, null, 'Renewal Opportunity not generated for Contract.');

        for (Contract c : contractList) {
            // Verify Contracts got associated to Order:
            System.assertEquals(c.SBQQ__Order__c, order.Id, 'Contract was not associated to Order');
            for (SBQQ__Subscription__c sub : c.SBQQ__Subscriptions__r) {
                // Verify Subscriptions got associated to Contract:
                System.assertEquals(sub.SBQQ__Contract__c, c.Id, 'Subscriptions were not associated to Contract.');
            }
        }
    }

    public static void test_renewalQuoted_contractedFromOrder() {
        // Set up all test data leading up to just after contracting the Order:
        initialSetup();
        setupContractForRenewal('Order');

        Test.startTest();
        contractList[0].SBQQ__MasterContract__c = true; // this is apparently required if you don't want the test method marked with (SeeAllData=true)
        // Mark Renewal Quoted on the Contract:
        contractList[0].SBQQ__RenewalQuoted__c = true;
        update contractList[0];
        Test.stopTest();

        /*********************
        ***** Assertions *****
        *********************/

        // Verify that a renewal Opportunity was automatically created for the Contract:
        contractList = [SELECT Id, SBQQ__RenewalOpportunity__c, SBQQ__Order__c FROM Contract WHERE Id = :contractList[0].Id];
        System.assertNotEquals(contractList[0].SBQQ__RenewalOpportunity__c, null, 'Renewal Opportunity not generated for Contract.');

        for (Contract c : contractList) {
            // Verify Contracts got associated to Order:
            System.assertEquals(c.SBQQ__Order__c, order.Id, 'Contract was not associated to Order');
            for (SBQQ__Subscription__c sub : c.SBQQ__Subscriptions__r) {
                // Verify Subscriptions got associated to Contract:
                System.assertEquals(sub.SBQQ__Contract__c, c.Id, 'Subscriptions were not associated to Contract.');
            }
        }

        // Verify that a renewal Quote was automatically created for the Contract:
        SBQQ__Quote__c renewalQuote = [SELECT Id, SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c = :contractList[0].SBQQ__RenewalOpportunity__c];
        System.assertNotEquals(renewalQuote.SBQQ__Opportunity2__c, null, 'Renewal Quote not generated for Contract.');
    }

    /***************************
    ***** End test methods *****
    ***************************/

    public interface CPQU_TestCacheExtendedInterface {
        Map<String, Id> initialSetupAdditional();
    }

    public class CPQ_TestCacheExtendedDefault implements CPQU_TestCacheExtendedInterface {
        public Map<String, Id> initialSetupAdditional() {

            CPQU_TestUtils testUtils = new CPQU_TestUtils();

            return new Map<String, Id> {
                'blng__BillingRule__c' => createBillingRule(true).Id,
                'blng__RevenueRecognitionRule__c' => createRevRecRule(true).Id,
                'blng__TaxRule__c' => createTaxRule(true).Id
            };
        }

        private blng__BillingRule__c createBillingRule(Boolean doInsert) {
            blng__BillingRule__c obj = new blng__BillingRule__c();
            obj.Name ='Generate Invoice - Separate Partial Period';
            obj.blng__Active__c = true;
            obj.blng__GenerateInvoices__c = 'Yes';
            obj.blng__InitialBillingTrigger__c = 'Order Product Activation Date';
            obj.blng__PartialPeriodTreatment__c = 'Separate';
            //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
            if (doInsert) { insert obj; }
            return obj;
        }
    
        private blng__BillingRule__c createBillingRuleDoNotInvoice(Boolean doInsert) {
            blng__BillingRule__c obj = new blng__BillingRule__c();
            obj.Name = 'Don\'t Generate Invoice - Separate Partial Period';
            obj.blng__Active__c = true;
            obj.blng__GenerateInvoices__c = 'No';
            obj.blng__InitialBillingTrigger__c = 'Order Product Activation Date';
            obj.blng__PartialPeriodTreatment__c = 'Separate';
            if (doInsert) { insert obj; }
            return obj;
        }
    
        private blng__RevenueRecognitionRule__c createRevRecRule(Boolean doInsert) {
            blng__RevenueRecognitionRule__c obj = new blng__RevenueRecognitionRule__c();
            obj.Name ='Standard Revenue Recognition Rule';
            obj.blng__Active__c = true;
            obj.blng__CreateRevenueSchedule__c = 'Yes';
            //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
            if (doInsert) { insert obj; }
            return obj;
        }
    
        private blng__TaxRule__c createTaxRule(Boolean doInsert) {
            blng__TaxRule__c obj = new blng__TaxRule__c();
            obj.Name ='No Tax Calculation';
            obj.blng__Active__c = true;
            obj.blng__TaxableYesNo__c = 'Yes';
            //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
            if (doInsert) { insert obj; }
            return obj;
        }
    }
}