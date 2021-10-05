@isTest
public class ContractAmenderTest {

    @TestSetup
    static void makeData() {
        Account account = CPQ_TestDataFactory.createAccount(true);

        // Opportunities
        Opportunity oppty1 = CPQ_TestDataFactory.createOppty(account, true);
        Opportunity oppty2 = CPQ_TestDataFactory.createOppty(account, true);

         // Products
        Product2 p1 = CPQ_TestDataFactory.createProduct('Product 1 Name', true);
        Product2 p2 = CPQ_TestDataFactory.createProduct('Product 2 Name', true);
        Product2 p3 = CPQ_TestDataFactory.createProduct('Product 3 Name', true);
        Product2 p4 = CPQ_TestDataFactory.createProduct('Product 4 Name', false);
        //p4.SBQQ__Optional__c = false;
        insert p4;

        SBQQ__ProductOption__c pOption = new SBQQ__ProductOption__c(
            SBQQ__ConfiguredSKU__c = p3.Id,
            SBQQ__OptionalSKU__c = p4.Id,
            SBQQ__Number__c = 1
        );
        insert pOption;

        Product2 p = [
            SELECT Id, Name,
            (SELECT Id, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Id FROM SBQQ__Options__r),
            (SELECT Id, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Id FROM SBQQ__OptionalFor__r)
            FROM Product2
            WHERE Id = :p3.Id
        ];
        Product2 pp = [
            SELECT Id, Name,
            (SELECT Id, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Name FROM SBQQ__Options__r),
            (SELECT Id, SBQQ__OptionalSKU__c, SBQQ__OptionalSKU__r.Name FROM SBQQ__OptionalFor__r)
            FROM Product2
            WHERE Id = :p4.Id
        ];

        String pOptions = '';
        String pOptional = '';
        for (SBQQ__ProductOption__c po : p.SBQQ__Options__r) {
            pOptions += ' Option: ' + po;
        }
        for (SBQQ__ProductOption__c po : p.SBQQ__OptionalFor__r) {
            pOptional += ' - Optional: ' + po;
        }

        String ppOptions = '';
        String ppOptional = '';
        for (SBQQ__ProductOption__c po : pp.SBQQ__Options__r) {
            ppOptions += ' Option: ' + po;
        }
        for (SBQQ__ProductOption__c po : pp.SBQQ__OptionalFor__r) {
            ppOptional += ' - Optional: ' + po;
        }

        System.debug('p : ' + p.Id + ' ' + p.Name + pOptions);
        System.debug('pp : ' + pp.Id + ' ' + pp.Name + ppOptions);

        List<PricebookEntry> priceBookEntries = CPQ_TestDataFactory.createPriceBookEntries(new List<Product2> { p1, p2, p3, p4 }, true);

        Contact contact = CPQ_TestDataFactory.createContact(true);

        // Quotes
        SBQQ__Quote__c quote1 = CPQ_TestDataFactory.createQuote(oppty1, account, contact, true);
        SBQQ__Quote__c quote2 = CPQ_TestDataFactory.createQuote(oppty2, account, contact, true);

        // Quote Lines
        SBQQ__QuoteLine__c ql1_1 = CPQ_TestDataFactory.createQuoteLine(quote1, p1, priceBookEntries[0].Id, 10, true);
        SBQQ__QuoteLine__c ql1_2 = CPQ_TestDataFactory.createQuoteLine(quote1, p2, priceBookEntries[1].Id, 20, true);
        
        SBQQ__QuoteLine__c ql2_1 = CPQ_TestDataFactory.createQuoteLine(quote2, p3, priceBookEntries[2].Id, 30, false);
        ql2_1.SBQQ__Bundle__c = true;
        ql2_1.SBQQ__ProductOption__c = pOption.Id;
        insert ql2_1;

        SBQQ__QuoteLine__c ql2_2 = CPQ_TestDataFactory.createQuoteLine(quote2, p4, priceBookEntries[3].Id, 40, false);
        ql2_2.SBQQ__RequiredBy__c = ql2_1.Id;
        System.debug('ATG: ql2_1.Id is ' + ql2_1.Id + ' :: ql2_2.SBQQ__RequiredBy__c is ' + ql2_2.SBQQ__RequiredBy__c);
        insert ql2_2;
        
        Test.startTest();

        Order order1 = CPQ_TestDataFactory.createOrder(account, oppty1, quote1, true);
        OrderItem oi1_1 = CPQ_TestDataFactory.createOrderItems(order1, ql1_1, true);
        OrderItem oi1_2 = CPQ_TestDataFactory.createOrderItems(order1, ql1_2, true);
        
        CPQ_TestDataFactory.activateOrder(order1);
        CPQ_TestDataFactory.contractOrder(order1);

        Order order2 = CPQ_TestDataFactory.createOrder(account, oppty2, quote2, true);
        OrderItem oi2_1 = CPQ_TestDataFactory.createOrderItems(order2, ql2_1, true);
        OrderItem oi2_2 = CPQ_TestDataFactory.createOrderItems(order2, ql2_2, false);
        oi2_2.SBQQ__RequiredBy__c = oi2_1.Id;
        insert oi2_2;

        CPQ_TestDataFactory.activateOrder(order2);
        CPQ_TestDataFactory.contractOrder(order2);
        
        Test.stopTest();

        // bypass trigger handler
        /*TriggerHandler.bypass('OrderTriggerHandler');
            
        CPQ_TestUtils.createOrder(testData.account, testData.opportunity, quote, true);
        // clear bypass trigger handler
        TriggerHandler.clearBypass('OrderTriggerHandler');
        */

    }
    
    @isTest
    public static void amendContractNoBundlesProduct() {
        SBQQ__Quote__c quote1 = [
            SELECT Id FROM SBQQ__Quote__c
        ][0];

        Order order1 = [
            SELECT Id, ContractId, SBQQ__Contracted__c FROM Order
        ][0];

        //////
        /*
        CPQ_TestDataFactory.activateOrder(order);
        
        Contract contract = CPQ_TestDataFactory.createContract(account, Test.getStandardPricebookId(), oppty, order, quote, false);
        
        contract.SBQQ__PreserveBundleStructureUponRenewals__c = true;
        contract.SBQQ__AmendmentRenewalBehavior__c = 'Latest End Date';
        contract.CurrencyIsoCode = 'USD';
        contract.SBQQ__DisableAmendmentCoTerm__c = false;
        contract.Status = 'Draft';
        
        insert contract;

        order.SBQQ__Contracted__c = true;
        update order;
        */
        //////

        //////
        Contract contract = [
            SELECT Id, SBQQ__PreserveBundleStructureUponRenewals__c,
            AccountId, SBQQ__ActiveContract__c, SBQQ__AmendmentRenewalBehavior__c, 
            SBQQ__AmendmentOpportunityRecordTypeId__c, SBQQ__AmendmentOpportunityStage__c, 
            SBQQ__AmendmentOwner__c, SBQQ__AmendmentPricebookId__c, SBQQ__AmendmentStartDate__c, 
            /*CurrencyIsoCode,*/ EndDate, Name, ContractNumber, StartDate, ContractTerm, 
            SBQQ__DisableAmendmentCoTerm__c, SBQQ__ExpirationDate__c, SBQQ__Opportunity__c, 
            SBQQ__OpportunityPricebookId__c, SBQQ__Order__c, 
            Pricebook2Id, SBQQ__Quote__c, Status
            FROM Contract WHERE SBQQ__Order__c = :order1.Id
        ];

        contract.SBQQ__PreserveBundleStructureUponRenewals__c = true;
        contract.SBQQ__AmendmentRenewalBehavior__c = 'Latest End Date';
        /*contract.CurrencyIsoCode = 'USD';*/
        contract.SBQQ__DisableAmendmentCoTerm__c = false;
        contract.Status = 'Draft';
        
        update contract;
        //////
        
        String contractId = contract.Id;
        System.debug('ATG: contract.Id is ' + contractId);

        System.debug('ATG: contract is ' + contract);
        
        Test.startTest();
        String outputMessage = '';
        if (contractId != null) {
            CPQ_ApiDataModels.QuoteModel quoteModel = ContractAmender.makeAmend(contractId);
            System.debug('ATG: QuoteModel is ' + quoteModel);
            System.assertEquals(2, quoteModel.lineItems.size());

            quoteModel = ContractAmender.modifyQuoteLines(quoteModel);
            System.assertEquals(4, quoteModel.lineItems.size());

            System.assertEquals(0, Integer.valueOf(quoteModel.lineItems[0].record.SBQQ__Quantity__c));
            System.assertEquals(0, Integer.valueOf(quoteModel.lineItems[1].record.SBQQ__Quantity__c));
            System.assertEquals(10, Integer.valueOf(quoteModel.lineItems[2].record.SBQQ__Quantity__c));
            System.assertEquals(20, Integer.valueOf(quoteModel.lineItems[3].record.SBQQ__Quantity__c));

            for (CPQ_ApiDataModels.QuoteLineModel qlModel : quoteModel.lineItems) {
                outputMessage += 'Product : ' + qlModel.record.SBQQ__Product__r.Name + '\n';
                outputMessage += 'List Price : ' + qlModel.record.SBQQ__ListPrice__c + '\n';
                outputMessage += 'Quantity : ' + qlModel.record.SBQQ__Quantity__c + '\n';
                outputMessage += 'TermDiscount : ' + qlModel.record.SBQQ__TermDiscount__c + '\n\n';
            }

            System.debug('ATG: Quote Lines of Amended Contract\n\n' + outputMessage);
        }

        Test.stopTest();
    }

    @isTest
    public static void amendContractBundlesProduct() {
        SBQQ__Quote__c quote2 = [
            SELECT Id FROM SBQQ__Quote__c
        ][1];

        Order order2 = [
            SELECT Id, ContractId, SBQQ__Contracted__c FROM Order
        ][1];

        //////
        Contract contract = [
            SELECT Id, SBQQ__PreserveBundleStructureUponRenewals__c,
            AccountId, SBQQ__ActiveContract__c, SBQQ__AmendmentRenewalBehavior__c, 
            SBQQ__AmendmentOpportunityRecordTypeId__c, SBQQ__AmendmentOpportunityStage__c, 
            SBQQ__AmendmentOwner__c, SBQQ__AmendmentPricebookId__c, SBQQ__AmendmentStartDate__c, 
            /*CurrencyIsoCode,*/ EndDate, Name, ContractNumber, StartDate, ContractTerm, 
            SBQQ__DisableAmendmentCoTerm__c, SBQQ__ExpirationDate__c, SBQQ__Opportunity__c, 
            SBQQ__OpportunityPricebookId__c, SBQQ__Order__c, 
            Pricebook2Id, SBQQ__Quote__c, Status
            FROM Contract WHERE SBQQ__Order__c = :order2.Id
        ];

        contract.SBQQ__PreserveBundleStructureUponRenewals__c = true;
        contract.SBQQ__AmendmentRenewalBehavior__c = 'Latest End Date';
        /*contract.CurrencyIsoCode = 'USD';*/
        contract.SBQQ__DisableAmendmentCoTerm__c = false;
        contract.Status = 'Draft';
        
        update contract;
        //////

        String contractId = contract.Id;
        System.debug('ATG: contract.Id is ' + contractId);

        Test.startTest();
        String outputMessage = '';
        if (contractId != null) {
            CPQ_ApiDataModels.QuoteModel quoteModel = ContractAmender.makeAmend(contractId);
            System.debug('ATG: QuoteModel is ' + quoteModel);
            System.assertEquals(2, quoteModel.lineItems.size());

            quoteModel = ContractAmender.modifyQuoteLines(quoteModel);
            System.assertEquals(4, quoteModel.lineItems.size());

            System.assertEquals(0, Integer.valueOf(quoteModel.lineItems[0].record.SBQQ__Quantity__c));
            System.assertEquals(0, Integer.valueOf(quoteModel.lineItems[1].record.SBQQ__Quantity__c));
            System.assertEquals(30, Integer.valueOf(quoteModel.lineItems[2].record.SBQQ__Quantity__c));
            System.assertEquals(40, Integer.valueOf(quoteModel.lineItems[3].record.SBQQ__Quantity__c));

            for (CPQ_ApiDataModels.QuoteLineModel qlModel : quoteModel.lineItems) {
                outputMessage += 'Product : ' + qlModel.record.SBQQ__Product__r.Name + '\n';
                outputMessage += 'List Price : ' + qlModel.record.SBQQ__ListPrice__c + '\n';
                outputMessage += 'Quantity : ' + qlModel.record.SBQQ__Quantity__c + '\n';
                outputMessage += 'TermDiscount : ' + qlModel.record.SBQQ__TermDiscount__c + '\n\n';
            }

            System.debug('ATG: Quote Lines of Amended Contract\n\n' + outputMessage);
        }

        Test.stopTest();
    }
}
