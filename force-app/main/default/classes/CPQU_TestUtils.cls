/**
 * 
 * CPQU_TestUtils class
 *
 * Versioning: 
 *   3/26/21 : Steve Lohrenz : File Created
 */

@IsTest
public class CPQU_TestUtils {
    private CPQ_TestUtilsExtendedInterface cpqTestUtilsExtendedInterface; 
    private static final String EXTENDED_CLASS_KEY_STRING = 'CPQU_TestUtilsExtendedIntName';

    public CPQU_TestUtils() {
       List<CPQU_UtilitySetting__mdt> metaDataExtendedClassList = [SELECT DeveloperName, TextValue__c FROM CPQU_UtilitySetting__mdt WHERE DeveloperName = :EXTENDED_CLASS_KEY_STRING AND IsActive__c = TRUE LIMIT 1];
        if(metaDataExtendedClassList.isEmpty() || String.isBlank(metaDataExtendedClassList.get(0).TextValue__c)) {
            cpqTestUtilsExtendedInterface = new CPQ_TestUtilsExtendedDefault();
        } else {
            // Get the Type corresponding to the class name
            Type classType = Type.forName(metaDataExtendedClassList.get(0).TextValue__c);

            // Instantiate the type.
            // The type of the instantiated object
            //   is the interface.
            cpqTestUtilsExtendedInterface = (CPQ_TestUtilsExtendedInterface) classType.newInstance();
        }
    }
    
    public Account createAccount(String name, Boolean doInsert) {
        Account obj = new Account();
        obj.Name = name;
        obj.BillingCity = 'Oxnard';
        obj.BillingCountry = 'United States';
        obj.BillingPostalCode = '93030';
        obj.BillingState = 'CA';
        obj.BillingStreet = '121 North ' + Math.random();
        obj.ShippingCity = 'Los Angeles';
        obj.ShippingCountry = 'United States';
        obj.ShippingPostalCode = '90033';
        obj.ShippingState = 'CA';
        obj.ShippingStreet = '1600 ' + Math.random();
        obj = cpqTestUtilsExtendedInterface.createAccount(obj);
        if(doInsert) {
            insert obj;
        }

        return obj;
    }

    public Contact createContact(Account acc, Boolean doInsert) {
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Testing',
            AccountId = acc.Id,
            Email = 'fullname@domain.com'
        );
        testContact = cpqTestUtilsExtendedInterface.createContact(testContact);
        if(doInsert) {
            insert testContact;
        }
        return testContact;
    }

    /** Create product **/
    public Product2 createProduct(String name, String productType, String productCode, Id billingRuleId, Id taxRuleId, Id revRecRuleId, Boolean populateDefaultValues, Boolean doInsert) {
        Product2 obj = (Product2)Product2.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            true // loadDefaultValues
        );
        obj.Name = name;
        obj.IsActive = true;
        obj.ProductCode = productCode;
        obj.SBQQ__QuantityEditable__c = true;
        obj.SBQQ__DefaultQuantity__c = 1.0;
        obj.SBQQ__AssetConversion__c = 'One per quote line';
        obj.SBQQ__SubscriptionCategory__c = 'Bundle';

        if(productType == 'Subscription') {
            obj.SBQQ__SubscriptionTerm__c = 12;
            obj.SBQQ__SubscriptionType__c = 'Renewable';
            obj.SBQQ__SubscriptionPricing__c = 'Fixed Price';
            obj.SBQQ__PricingMethod__c = 'List';
            obj.SBQQ__SubscriptionBase__c = 'Regular';
        } else if(productType == 'Non-Subscription') {
            obj.SBQQ__SubscriptionBase__c = 'List';
        }

        // Required to Order a quote when Billing is installed:
        obj.SBQQ__ChargeType__c = 'Recurring';
        obj.SBQQ__BillingType__c = 'Advance';
        obj.SBQQ__BillingFrequency__c = 'Monthly';

        obj = cpqTestUtilsExtendedInterface.createProduct(obj, billingRuleId, taxRuleId, revRecRuleId);
        if(doInsert) {
            insert obj;
        }

        return obj;
    }

    /** Create pricebook **/
    public Pricebook2 createPriceBook(String name, Boolean IsActive, String currencyIsoCode, Boolean populateDefaultValues, Boolean doInsert){
        Pricebook2 obj = (Pricebook2)Pricebook2.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            true // loadDefaultValues
        );
        obj.Name = name;
        obj.IsActive = IsActive;
        obj = cpqTestUtilsExtendedInterface.createPricebook2(obj);

        // Note: de-comment if multicurrency is enabled:
        //obj.CurrencyIsoCode = currencyIsoCode;

        if(doInsert) {
            insert obj;
        }
        return obj;
    }

    /** Create pricebook entry **/
    public PricebookEntry createPriceBookEntry(Product2 product, Pricebook2 priceBook, Boolean populateDefaultValues, Boolean doInsert) {
        PricebookEntry obj = (PricebookEntry) PricebookEntry.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            populateDefaultValues // loadDefaultValues
        );
        obj.UnitPrice = 100;
        obj.Pricebook2Id = priceBook == null ? Test.getStandardPricebookId() : priceBook.Id;
        obj.Product2Id = product.Id;
        obj.IsActive = true;

        obj = cpqTestUtilsExtendedInterface.createPriceBookEntry(obj);
        if(doInsert) {
            insert obj;
        }
        return obj;
    }

    public Opportunity createOpportunity(String name, Account anAccount, Boolean doInsert) {
        Opportunity obj = new Opportunity(Name = name, Account = anAccount, StageName = 'Qualification',
            CloseDate = Date.today() + 7, Pricebook2Id = Test.getStandardPricebookId());
        obj = cpqTestUtilsExtendedInterface.createOpportunity(obj);
        if(doInsert) {
            insert obj;
        }

        return obj;
    }

    public Opportunity createOpportunity(String name, Account anAccount, Contact aContact, Boolean doInsert) {
        Opportunity obj = new CPQU_TestUtils().createOpportunity(name, anAccount, false);
        obj.ContactId = aContact.Id;
        obj = cpqTestUtilsExtendedInterface.createOpportunity(obj);
        if(doInsert) {
            insert obj;
        }

        return obj;
    }

    /** Create quote **/
    public SBQQ__Quote__c createQuote(Account acct, Opportunity opp, Boolean isPrimary, Boolean populateDefaultValues, Boolean doInsert) {
        SBQQ__Quote__c obj = (SBQQ__Quote__c)SBQQ__Quote__c.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            true // loadDefaultValues
        );
        obj.SBQQ__Primary__c = isPrimary;
        obj.SBQQ__StartDate__c = Date.today();
        //obj.SBQQ__EndDate__c = Date.today().addMonths(1);
        obj.SBQQ__Opportunity2__c = opp == null ? null : opp.Id;
        obj.SBQQ__SubscriptionTerm__c = 12;
        obj.SBQQ__ExpirationDate__c = Date.today() + 30;
        obj.SBQQ__Account__c = acct == null ? null : acct.Id;
        obj.SBQQ__Type__c = 'Quote';
        obj.SBQQ__ProrationDayOfMonth__c = '1';
        obj = cpqTestUtilsExtendedInterface.createQuote(obj);

        if(doInsert) {
            insert obj;
        }
        return obj;
    }

    /** Create quote line **/
    public SBQQ__QuoteLine__c createQuoteLine(Product2 product, PricebookEntry pbe, SBQQ__Quote__c quote, Boolean populateDefaultValues, Boolean doInsert) {
        SBQQ__QuoteLine__c obj = (SBQQ__QuoteLine__c)SBQQ__QuoteLine__c.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            populateDefaultValues // loadDefaultValues
        );
        obj.SBQQ__Product__c = product.Id;
        obj.SBQQ__Quote__c = quote.Id;
        obj.SBQQ__PricebookEntryId__c = pbe == null ? null : pbe.Id;
        obj.SBQQ__PricingMethod__c = 'List';
        obj.SBQQ__StartDate__c = Date.today();
        obj.SBQQ__ListPrice__c = 100;
        obj.SBQQ__Quantity__c = 1;
        obj.SBQQ__PriorQuantity__c = 0;
        obj.SBQQ__RegularPrice__c = 100;
        obj.SBQQ__NetPrice__c = 100;
        obj.SBQQ__Number__c = 1;
        obj.SBQQ__ProrateMultiplier__c = 1;
        obj.SBQQ__SubscriptionPricing__c = 'Fixed Price';
        obj.SBQQ__SubscriptionScope__c = 'Quote';
        obj.SBQQ__DefaultSubscriptionTerm__c = 1;
        obj.SBQQ__ChargeType__c = product.SBQQ__ChargeType__c;
        obj.SBQQ__BillingType__c = product.SBQQ__BillingType__c;
        obj.SBQQ__BillingFrequency__c = product.SBQQ__BillingFrequency__c;
        obj = cpqTestUtilsExtendedInterface.createQuoteLine(obj);

        if(doInsert) {
            insert obj;
        }
        return obj;
    }

    /** Create Asset */
    public Asset createAsset(Account acct, Product2 product, SBQQ__QuoteLine__c quoteLine, Boolean populateDefaultValues, Boolean doInsert) {
        Asset obj = (Asset)Asset.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            populateDefaultValues // loadDefaultValues
        );
        obj.Name = 'Test Asset';
        obj.AccountId = acct.Id;
        obj.Product2Id = product.Id;
        // Decomment if multicurrency is enabled:
        //obj.CurrencyIsoCode = 'USD';
        obj.Status = 'Registered';
        obj.PurchaseDate = System.today();
        obj.SBQQ__QuoteLine__c = quoteLine == null ? null : quoteLine.Id;
        obj.SerialNumber = '1234567890';
        obj = cpqTestUtilsExtendedInterface.createAsset(obj);

        if(doInsert) {
            insert obj;
        }
        return obj;
    }

    public Contract createContract(Account acct, Id pricebookId, Opportunity opp, Order order, SBQQ__Quote__c quote, Boolean doInsert) {
        Contract obj = (Contract)Contract.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            true // loadDefaultValues
        );
        obj.AccountId = acct.Id;
        obj.ContractTerm = 12;
        obj.SBQQ__Quote__c = quote == null ? null : quote.Id;
        obj.SBQQ__Opportunity__c = opp == null ? null : opp.Id;
        obj.SBQQ__Order__c = order == null ? null : order.Id;
        obj.SBQQ__RenewalTerm__c = 12;
        obj.StartDate = System.today();
        obj = cpqTestUtilsExtendedInterface.createContract(obj);

        if(doInsert) {
            insert obj;
        }
        return obj;
    }

    /** Create Subscription **/
    public SBQQ__Subscription__c createSubscription(Account acct, Contract con, SBQQ__QuoteLine__c quoteLine, Boolean populateDefaultValues, Boolean doInsert) {
        SBQQ__Subscription__c obj = (SBQQ__Subscription__c)SBQQ__Subscription__c.SObjectType.newSObject(
            null, // null will make it the default record type for the user
            true // loadDefaultValues
        );
        obj.SBQQ__Account__c = acct.Id;
        obj.SBQQ__Contract__c = con.Id;
        obj.SBQQ__QuoteLine__c = quoteLine.Id;
        obj.SBQQ__OriginalQuoteLine__c = quoteLine.Id;
        obj.SBQQ__Quantity__c = 1.00;
        obj.SBQQ__RenewalQuantity__c = 1.00;
        obj.SBQQ__Product__c = quoteLine.SBQQ__Product__c;
        obj.SBQQ__Number__c = 1;
        obj.SBQQ__ProrateMultiplier__c = 1.0000;

        obj = cpqTestUtilsExtendedInterface.createSubscription(obj);
        if(doInsert) {
            insert obj;
        }
        return obj;
    }

    /************************************/
    /***** ORDER automation RELATED *****/
    /************************************/

    /** Create Order from Quote **/
    public Order createAutomatedOrderFromQuote(Id quoteId) {
        SBQQ__Quote__c q = new SBQQ__Quote__c(Id = quoteId, SBQQ__Ordered__c= true);
        update q;

        /** Query order from quote id */
        List<Order> orderList = queryRecordsFromIdsAndObjectName(
            new Set<Id>{quoteId},              // Set<Id> idSet (to bind to in where clause)
            'Order',                            // String objectName
            'WHERE SBQQ__Quote__c IN :idSet'    // String whereClause
        );
        return orderList[0];
    }

    /** Create Order from Opportunity **/
    public Order createAutomatedOrderFromOpportunity(Id oppId) {
        Opportunity obj = new Opportunity(Id = oppId, SBQQ__Ordered__c= true);
        update obj;

        /** Query order from opp id */
        List<Order> orderList = queryRecordsFromIdsAndObjectName(
            new Set<Id>{oppId},                // Set<Id> idSet (to bind to in where clause)
            'Order',                            // String objectName
            'WHERE OpportunityId IN :idSet'     // String whereClause
        );
        return orderList[0];
    }

    /**
     * Activate order - status and status code are both updated
     * This should update all lines as well. Order lines are queried and returned
     */
    public List<OrderItem> activateOrder(Order anOrder) {
        anOrder.Status = 'Activated';
        anOrder.StatusCode = 'Activated';

        // order.blng__BillingDayOfMonth__c = '1'; //#SFBILLING
        anOrder = cpqTestUtilsExtendedInterface.activateOrderSetup(anOrder);
        // Update Order:
        update anOrder;

        /** Query order items by order id */
        return queryRecordsFromIdsAndObjectName(
            new Set<Id>{anOrder.Id},     // Set<Id> idSet (to bind to in where clause)
            'OrderItem',                // String objectName
            'WHERE OrderId IN :idSet'   // String whereClause
        );
    }

    /** Contract an Order **/
    public List<Contract> contractOrder(Order order, Boolean startTests, Boolean stopTests) {
        // Update status and status code
        order.SBQQ__Contracted__c = true;

        if(startTests) { Test.startTest(); }
        // Update Order:
        update order;
        if(stopTests) { Test.stopTest(); }

        /** Query contract with lines (subscriptions) by order **/
        return queryRecordsAndChildrenFromIdsAndObjectNames(
            new Set<Id>{order.Id},              // Set<Id> idSet (to bind to in where clause)
            'Contract',                         // String parentObjName
            'SBQQ__Subscription__c',            // String childObjName
            'SBQQ__Subscriptions__r',           // String childObjRelationshipName
            'WHERE SBQQ__Order__c IN :idSet'    // String whereClause
        );
    }

    /** Contract an Opportunity **/
    public List<Contract> contractOpportunity(Opportunity opp, Boolean startTests, Boolean stopTests) {
        opp.SBQQ__Contracted__c = true;

        if(startTests) { Test.startTest(); }
        // Update Opportunity:
        update opp;
        if(stopTests) { Test.stopTest(); }

        /** Query contract with lines (subscriptions) by Opportunity **/
        return queryRecordsAndChildrenFromIdsAndObjectNames(
            new Set<Id>{opp.Id},                    // Set<Id> idSet (to bind to in where clause)
            'Contract',                             // String parentObjName
            'SBQQ__Subscription__c',                // String childObjName
            'SBQQ__Subscriptions__r',               // String childObjRelationshipName
            'WHERE SBQQ__Opportunity__c IN :idSet'  // String whereClause
        );

    }

    public Integer queryCount = 0;
    public void printQueries(String message) {
        System.debug(LoggingLevel.ERROR, message + ' used ' + (Limits.getQueries() - queryCount) + ' queries. The total queries used is ' + Limits.getQueries() + ' CPU TIME: ' + Limits.getCpuTime() + ' ' + Limits.getLimitCpuTime());
        queryCount = Limits.getQueries();
    }

    /**
     * ********************** Query Helpers ********************
     */

    /** Query sobject without subquery */
    public static List<SObject> queryRecordsFromIdsAndObjectName(Set<Id> idSet, String objectName, String whereClause) {
        return (queryRecordsFromIdsAndObjectName(idSet, objectName, null, whereClause));
    }
    public static List<SObject> queryRecordsFromIdsAndObjectName(Set<Id> idSet, String objectName, String additionalReferences, String whereClause) {
        String additionalRef = additionalReferences == null ? '' : additionalReferences;
        String soql = 'SELECT ' + getAllFieldsForSObjAsStr(objectName) + ' ' + additionalRef + ' FROM ' + objectName + ' ' + whereClause;
        return Database.query(soql);
    }

    /** Query sobject with subquery */
    public static List<SObject> queryRecordsAndChildrenFromIdsAndObjectNames(Set<Id> idSet, String parentObjName, String childObjName, String childObjRelationshipName, String whereClause) {
        String soql = 'SELECT ' + getAllFieldsForSObjAsStr(parentObjName) + ', (SELECT ' + getAllFieldsForSObjAsStr(childObjName) + ' FROM ' + childObjRelationshipName + ') FROM ' + parentObjName + ' ' + whereClause;
        return Database.query(soql);
    }

    /** Get all fields for an sobject as a list - helpful for dynamic SOQL */
    public static List<String> getAllFieldsForSobj(String sobjectName) {
        List<String> allFields = new List<String>(Schema.getGlobalDescribe().get(sobjectName).getDescribe().fields.getMap().keySet());
        return allFields;
    }

    /** Get comma delimited string list of all sobject fields */
    public static String getAllFieldsForSObjAsStr(String sobjectName) {
        return String.join(getAllFieldsForSobj(sobjectName), ', ');
    }

    /** Create subscription product */
    public Product2 createProduct(Id billingRuleId, Id taxRuleId, Id revRecRuleId, Boolean doInsert) {
        Product2 obj = new Product2();
        obj.Name = 'Test Product' + Math.roundToLong(Math.random()*10000000);
        obj.IsActive = true;
        obj.ProductCode = 'CL01';
        obj.Description = 'Product of Clip Licensing';
        obj.Family = 'Analytics';
        obj.ProductCode = 'TestProduct';
        obj.SBQQ__OptionSelectionMethod__c = 'Click';
        obj.SBQQ__ConfigurationType__c = null;
        obj.SBQQ__QuantityEditable__c = true;
        obj.SBQQ__SubscriptionBase__c = 'List';
        obj.SBQQ__Taxable__c = false;
        obj.SBQQ__BlockPricingField__c = 'Quantity';
        obj.SBQQ__Component__c = false;
        obj.SBQQ__DefaultQuantity__c = 1;
        obj.SBQQ__ExcludeFromOpportunity__c = false;
        obj.SBQQ__PriceEditable__c = true;
        obj.SBQQ__PricingMethod__c = 'List';
        obj.SBQQ__SubscriptionPricing__c = 'Fixed Price';
        obj.SBQQ__SubscriptionType__c = 'Renewable';
        obj.SBQQ__SubscriptionTerm__c = 12;
        obj.SBQQ__ChargeType__c = 'Recurring';
        obj.SBQQ__BillingType__c = 'Advance';
        obj.SBQQ__BillingFrequency__c = 'Monthly';
        obj = cpqTestUtilsExtendedInterface.createProduct(obj, billingRuleId, taxRuleId, revRecRuleId);

        System.debug(obj);
        if (doInsert) { insert obj; }
        System.debug(obj);
        return obj;
    }

    //public Product2 createSubscriptionProduct(String productName, String productCode, Boolean doInsert) {
    //    Product2 obj = new Product2();
    //    // de-comment for multi currency orgs:
    //    //obj.CurrencyIsoCode = 'USD';
    //    obj.Family = 'Family 123';
    //    obj.IsActive = true;
    //    obj.Name = productName;
    //    obj.ProductCode = productCode;
    //    obj.SBQQ__AssetConversion__c='One per quote line';
    //    obj.SBQQ__PricingMethod__c='List';
    //    obj.SBQQ__SubscriptionBase__c='List';
    //    obj.SBQQ__SubscriptionPricing__c='Fixed Price';
    //    obj.SBQQ__SubscriptionType__c='Renewable';

    //    if (doInsert) {
    //        insert obj;
    //    }
    //    return obj;
    //}

    /** Create Contract */
    public Contract createContract(Account a, Boolean doInsert) {
        return createContract(a, null, doInsert);
    }
    public Contract createContract(Account a, Opportunity o, Boolean doInsert) {
        Contract obj = new Contract();
        obj.AccountId = a.Id;
        obj.SBQQ__Opportunity__c = o == null ? null : o.Id;
        obj.Status = 'Draft';
        obj.StartDate = Date.today();
        obj.ContractTerm = 12;

        if (doInsert) {
            insert obj;
        }

        return obj;
    }

    /** Create Subscription */
    public SBQQ__Subscription__c createSubscription(Account a, Product2 p, Contract contract, Boolean doInsert) {
        SBQQ__Subscription__c obj = new SBQQ__Subscription__c();
        obj.SBQQ__Account__c = a.Id;
        obj.SBQQ__Product__c = p.Id;
        obj.SBQQ__Contract__c = contract.Id;
        obj.SBQQ__Quantity__c = 10.00;
        obj.SBQQ__RevisedSubscription__c = obj.Id;

        if (doInsert) {
            insert obj;
        }

        return obj;
    }

    /**
     * @description this method sets up a contract or series of contracts for renewal, equivalent of getting a contract in a
     *   state where Renewal Quoted can be checked.
     *
     * @param Integer numOfSubscriptionProducts -> number of asset products to create
     * @param Integer numOfAssetProducts -> number of products to create
     * @param Integer numOfContracts -> number of contracts to create
     * @param Integer numOfSubsPerContract -> number of subscriptions to create on each contract
     */
    public Account account_contractRenewalRelated;
    public List<Contract> contractsToInsertRenewalRelated;
    public void setupTestData_contractRenewalRelated(Integer numOfSubscriptionProducts, Integer numOfAssetProducts, Integer numOfContracts) {
        account_contractRenewalRelated = new Account(Name = 'Test Account');
        insert account_contractRenewalRelated;

        List<Product2> subProductsToInsert = new List<Product2>();
        for(Integer i = 0; i < numOfSubscriptionProducts; i++) {
            Product2 p = createProduct(
                'Subscription Product XYZ' + i, // String name
                'Subscription',                 // String productType
                'SBP-XYZ-111' + i,              // String productCode
                null,                           // Id billingRuleId
                null,                           // Id taxRuleId
                null,                           // Id revRecRuleId
                true,                           // Boolean populateDefaultValues
                false                           // Boolean doInsert
            );
            subProductsToInsert.add(p);
        }
        List<Product2> assetProductsToInsert = new List<Product2>();
        for(Integer i = 0; i < numOfAssetProducts; i++) {
            Product2 p = createProduct(
                'Asset Product XYZ' + i,        // String name
                'Asset',                        // String productType
                'ABP-XYZ-111' + i,              // String productCode
                null,                           // Id billingRuleId
                null,                           // Id taxRuleId
                null,                           // Id revRecRuleId
                true,                           // Boolean populateDefaultValues
                false                           // Boolean doInsert
            );
            assetProductsToInsert.add(p);
        }
        List<Product2> productsToInsert = new List<Product2>();
        productsToInsert.addAll(subProductsToInsert);
        productsToInsert.addAll(assetProductsToInsert);
        insert productsToInsert;

        contractsToInsertRenewalRelated = new List<Contract>();
        for(Integer i = 0; i < numOfContracts; i++) {
            Contract c = createContract(account_contractRenewalRelated, false);
            c.AccountId = account_contractRenewalRelated.Id;
            c.Status = 'Draft';
            //c.EndDate = System.today() + 30;
            contractsToInsertRenewalRelated.add(c);
        }
        insert contractsToInsertRenewalRelated;

        List<Asset> assetsToInsert = new List<Asset>();
        for(Integer i = 0; i < numOfContracts; i++) {
            for(Integer j = 0; j < assetProductsToInsert.size(); j++) {
                Asset a = createAsset(account_contractRenewalRelated, assetProductsToInsert[i], null, true, false);
                a.Quantity = 1;
                assetsToInsert.add(a);
            }
        }
        insert assetsToInsert;

        List<SBQQ__Subscription__c> subsToInsert = new List<SBQQ__Subscription__c>();
        for(Integer i = 0; i < numOfContracts; i++) {
            for(Integer j = 0; j < subProductsToInsert.size(); j++) {
                SBQQ__Subscription__c s = createSubscription(account_contractRenewalRelated, subProductsToInsert[j], contractsToInsertRenewalRelated[i], false);
                s.SBQQ__Quantity__c = 1;
                s.SBQQ__RenewalQuantity__c = 1;
                s.SBQQ__SubscriptionStartDate__c = System.today();

                if(j == 0 && assetsToInsert.size() > 0) {
                    s.SBQQ__RequiredById__c = assetsToInsert[j].Id;
                }
                subsToInsert.add(s);
            }
        }

        insert subsToInsert;

        // populate the current subscription on the first asset:
        assetsToInsert[0].SBQQ__CurrentSubscription__c = subsToInsert[0].Id;
        update assetsToInsert;
    }

    /** //#SFBILLING
     * ************  SALESFORCE BILLING CONFIGURATIONS ********************
     * ******  Decomment if and when Salesforce Billing is installed ******
     *  Feel free to Remove if Salesforce Billing will never be installed
     */

    public Order createOrder(Opportunity opp, SBQQ__Quote__c quote, Boolean doInsert) {
        Order order = new Order();
        order.AccountId = opp.AccountId;
        order.BillingCity = 'Abilene';
        order.BillingCountry = 'USA';
        order.BillingPostalCode = '79606';
        order.BillingState = 'TX';
        order.BillingStreet = '4602 Marlboro Dr.';
        order.EffectiveDate = Date.today();
        order.OpportunityId = opp.Id;
        order.Pricebook2Id = opp.Pricebook2Id;
        order.SBQQ__ContractingMethod__c = 'Single Contract';
        order.SBQQ__PaymentTerm__c = 'Net 30';
        order.SBQQ__PriceCalcStatus__c = 'Completed';
        order.SBQQ__Quote__c = quote.Id;
        order.ShippingCity = 'Abilene';
        order.ShippingCountry = 'USA';
        order.ShippingPostalCode = '79606';
        order.ShippingState = 'TX';
        order.ShippingStreet = '4602 Marlboro Dr.';
        order.Status = 'Draft';
        order.Type = 'New';

        order = cpqTestUtilsExtendedInterface.createOrder(order);
        if (doInsert) { insert order; }
        return order;
    }


    public OrderItem createOrderItem(
        Order order, SBQQ__QuoteLine__c quoteLine, Product2 product, PricebookEntry pbe, Id legalEntityId, Boolean doInsert
    ) {
        OrderItem orderItem = new OrderItem();
        orderItem.EndDate = Date.today().addMonths(1).addDays(-1);
        orderItem.OrderId = order.Id;
        orderItem.PricebookEntryId = pbe.Id;
        orderItem.Product2Id = product.Id;
        orderItem.Quantity = 1;
        orderItem.SBQQ__BillingFrequency__c = 'Annual';
        orderItem.SBQQ__ChargeType__c = 'Usage';
        orderItem.SBQQ__DefaultSubscriptionTerm__c = 364;
        orderItem.SBQQ__OrderedQuantity__c = 1;
        orderItem.SBQQ__QuoteLine__c = quoteLine.Id;
        orderItem.SBQQ__QuotedQuantity__c = 1;
        orderItem.SBQQ__SubscriptionPricing__c = 'Fixed Price';
        orderItem.SBQQ__SubscriptionTerm__c = 364;
        //orderItem.SBQQ__TotalAmount__c = 650;
        orderItem.SBQQ__UnproratedNetPrice__c = 650;
        orderItem.ServiceDate = Date.today();
        orderItem.UnitPrice = 650;
        orderItem = cpqTestUtilsExtendedInterface.createOrderItem(orderItem, product, legalEntityId);

        if (doInsert) { insert orderItem; }
        return orderItem;
    }

    public SBQQ__PriceSchedule__c createPriceSchedule(Order anOrder, OrderItem op, Product2 p, SBQQ__Quote__c q, SBQQ__QuoteLine__c ql, Boolean doInsert) {
        SBQQ__PriceSchedule__c priceSchedule = new SBQQ__PriceSchedule__c();
        //priceSchedule.Name = 'IoT SGW Volume Discount Schedule';
        priceSchedule.SBQQ__DiscountUnit__c = 'Percent';
        priceSchedule.SBQQ__OrderProduct__c = op.Id;
        priceSchedule.SBQQ__Order__c = anOrder.Id;
        priceSchedule.SBQQ__PriceScale__c = 2;
        priceSchedule.SBQQ__PriceType__c = 'Volume';
        priceSchedule.SBQQ__Pricebook__c = Test.getStandardPricebookId();
        priceSchedule.SBQQ__Product__c = p.Id;
        priceSchedule.SBQQ__QuoteLineQuantityField__c = 'Quantity';
        priceSchedule.SBQQ__QuoteLine__c = ql.Id;
        priceSchedule.SBQQ__Quote__c = q.Id;
        System.debug(LoggingLevel.WARN, 'createPriceSchedule() ' + priceSchedule);

        if (doInsert) { insert priceSchedule; }
        return priceSchedule;
    }

    public SBQQ__PriceTier__c createPriceTier(SBQQ__PriceSchedule__c sc, String name, Integer num, Decimal price, Integer lower, Integer upper, Boolean doInsert) {
        SBQQ__PriceTier__c priceTier = new SBQQ__PriceTier__c();
        priceTier.Name = name;
        priceTier.SBQQ__LowerBound__c = lower;
        priceTier.SBQQ__UpperBound__c = upper;
        priceTier.SBQQ__Number__c = num;
        priceTier.SBQQ__PriceModel__c = 'Per Unit';
        priceTier.SBQQ__PriceSchedule__c = sc.Id;
        priceTier.SBQQ__Price__c = price;
        System.debug(LoggingLevel.WARN, 'createPriceTier() ' + priceTier);

        if (doInsert) { insert priceTier; }
        return priceTier;
    }

    public interface CPQ_TestUtilsExtendedInterface {
        Account createAccount(Account anAccount);
        Contact createContact(Contact aContact);
        Product2 createProduct(Product2 aProduct, Id billingRuleId, Id taxRuleId, Id revRecRuleId);
        Pricebook2 createPricebook2(Pricebook2 aPricebook);
        PricebookEntry createPriceBookEntry(PricebookEntry aPriceBookEntry);
        Opportunity createOpportunity(Opportunity anOpportunity);
        SBQQ__Quote__c createQuote(SBQQ__Quote__c aQuote);
        SBQQ__QuoteLine__c createQuoteLine(SBQQ__QuoteLine__c aQuoteLine);
        Order createOrder(Order anOrder);
        OrderItem createOrderItem(OrderItem anOrderItem, Product2 aProduct, Id legalEntityId);

        Asset createAsset(Asset anAsset);
        Contract createContract(Contract aContract);
        SBQQ__Subscription__c createSubscription(SBQQ__Subscription__c aSubscription);
        Order activateOrderSetup(Order anOrder);
    }

    public class CPQ_TestUtilsExtendedDefault implements CPQ_TestUtilsExtendedInterface {
        public Account createAccount(Account anAccount) {
            return anAccount;
        }

        public Contact createContact(Contact aContact) {
            return aContact;
        }

        public Product2 createProduct(Product2 aProduct, Id billingRuleId, Id taxRuleId, Id revRecRuleId) {
            aProduct.blng__BillingRule__c = billingRuleId;
            aProduct.blng__TaxRule__c = taxRuleId;
            aProduct.blng__RevenueRecognitionRule__c = revRecRuleId;
            return aProduct;
        }

        public Pricebook2 createPricebook2(Pricebook2 aPricebook) {
            return aPricebook;
        }

        public PricebookEntry createPriceBookEntry(PricebookEntry aPriceBookEntry) {
            return aPriceBookEntry;
        }

        public Opportunity createOpportunity(Opportunity anOpportunity) {
            return anOpportunity;
        }

        public SBQQ__Quote__c createQuote(SBQQ__Quote__c aQuote) {
            return aQuote;
        }

        public SBQQ__QuoteLine__c createQuoteLine(SBQQ__QuoteLine__c aQuoteLine) {
            return aQuoteLine;
        }

        public Order createOrder(Order anOrder) {
            return anOrder;
        }

        public OrderItem createOrderItem(OrderItem anOrderItem, Product2 aProduct, Id legalEntityId) {
            return anOrderItem;
        }

        public Asset createAsset(Asset anAsset) {
            return anAsset;
        }

        public Contract createContract(Contract aContract) {
            return aContract;
        }

        public SBQQ__Subscription__c createSubscription(SBQQ__Subscription__c aSubscription) {
            return aSubscription;
        }

        public Order activateOrderSetup(Order anOrder) {
            return anOrder;
        }
    }
}