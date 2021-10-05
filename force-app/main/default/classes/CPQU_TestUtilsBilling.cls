/**
 * 
 * CPQU_TestUtilsBilling class
 *
 * Versioning: 
 *   3/26/21 : Steve Lohrenz : File Created
 */

@IsTest
public class CPQU_TestUtilsBilling {
    /**
    * Create invoice for order.
    * Returns Invoice with invoice line subquery for easy reference
    */
    public List<blng__Invoice__c> billOrderNow(Order order) {
        // Update status and status code
        order.blng__BillNow__c = true;
        update order;
        // order line: SBQQ__Status__c
        return CPQU_TestUtils.queryRecordsAndChildrenFromIdsAndObjectNames(
            new Set<Id>{order.Id},              // Set<Id> recordIds (to bind to in where clause)
            'blng__Invoice__c',                 // String parentObjName
            'blng__InvoiceLine__c',             // String childObjName
            'blng__InvoiceInvoiceLines__r',     // String childObjRelationshipName
            'WHERE blng__Order__c IN :idSet'    // String whereClause
        );
    }

    public blng__BillingRule__c createBillingRule(Boolean doInsert) {
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

    public blng__BillingRule__c createBillingRuleDoNotInvoice(Boolean doInsert) {
        blng__BillingRule__c obj = new blng__BillingRule__c();
        obj.Name = 'Don\'t Generate Invoice - Separate Partial Period';
        obj.blng__Active__c = true;
        obj.blng__GenerateInvoices__c = 'No';
        obj.blng__InitialBillingTrigger__c = 'Order Product Activation Date';
        obj.blng__PartialPeriodTreatment__c = 'Separate';
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__GLAccount__c createGLAccount(Boolean doInsert) {
        blng__GLAccount__c obj = new blng__GLAccount__c();
        obj.Name = 'GL Account 1';
        obj.blng__Active__c = true;
        obj.blng__GLAccountDescription__c = 'Generic GL Account.';
        obj.blng__GLAccountNumber__c = '0001';
        System.debug('GL ACCOUNT: ' + obj);
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__GLTreatment__c createGLTreatment(blng__GLAccount__c glAccount, blng__GLRule__c glRule, blng__LegalEntity__c legalEntity, Boolean doInsert) {
        blng__GLTreatment__c obj = new blng__GLTreatment__c();
        obj.Name = 'Standard GL Treatment';
        obj.blng__GLLegalEntity__c = legalEntity.Id;
        obj.blng__Active__c = true;
        obj.blng__CreditGLAccount__c = glAccount.Id;
        obj.blng__DebitGLAccount__c = glAccount.Id;
        obj.blng__GLRule__c = glRule.Id;
        obj.blng__UniqueId__c = 'TEST';//String.valueOf(glRule.Id).toLowerCase() + String.valueOf(legalEntity.Id).toLowerCase();
        System.debug('GL TREATMENT: ' + obj);
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__RevenueRecognitionTreatment__c createRevRecTreatment(blng__RevenueRecognitionRule__c revRecRule,
        blng__GLRule__c glRule,
        blng__FinanceBook__c finBook,
        blng__RevenueDistributionMethod__c revDistMethod,
        blng__LegalEntity__c legalEntity,
        Boolean doInsert) {
        blng__RevenueRecognitionTreatment__c obj = new blng__RevenueRecognitionTreatment__c();
        obj.Name ='Standard Revenue Recognition Treatment - Order Activation';
        obj.blng__Active__c = true;
        obj.blng__RevenueLegalEntity__c = legalEntity.Id;
        obj.blng__ProcessingOrder__c = 1.0;
        obj.blng__Type__c = 'Percentage';
        obj.blng__Percentage__c = 100.0;
        obj.blng__RevenueRecognitionRule__c = revRecRule.Id;
        obj.blng__RevenueGLRule__c = glRule.Id;
        obj.blng__RevenueFinanceBook__c = finBook.Id;
        obj.blng__RevenueScheduleCreationAction__c = 'Order Activation';
        obj.blng__RevenueDistributionMethod__c = revDistMethod.Id;
        if (doInsert) { insert obj; }
        return obj;
    }

    /** Finance periods - this is optional in most use-cases */
    public List<blng__FinancePeriod__c> createFinancePeriods(Id legalEntityId, Id finBookId, Date startDate, Integer numPeriods) {
        List<blng__FinancePeriod__c> periods = new List<blng__FinancePeriod__c>();
        for(Integer i = 0; i < numPeriods; i++) {
            periods.add(new blng__FinancePeriod__c(
                Name = String.valueOf(startDate.year()) + '-' + String.valueOf(startDate.month()),
                blng__LegalEntity__c = legalEntityId,
                blng__FinanceBook__c = finBookId,
                blng__PeriodEndDate__c = startDate.addMonths(1).addDays(-1),
                blng__PeriodStartDate__c = startDate,
                blng__PeriodStatus__c = 'Open'
            ));
            startDate = startDate.addMonths(1);
        }
        insert periods;
        return periods;
    }

    private List<blng__FinancePeriod__c> createFinancePeriods(blng__FinanceBook__c finBook, Integer numYears, blng__LegalEntity__c legalEntity) {
        List<blng__FinancePeriod__c> periods = new List<blng__FinancePeriod__c>();
        Date today = Date.today();
        Integer currDay = today.day();
        Integer currMonth = today.month();
        Integer currYear = today.year();
        for(Integer year = 0; year < numYears; year++) {
            for(Integer month = 0; month < 12; month++) {
                Date currDate = today.addYears(year).addMonths(month);
                Date startDate = Date.newInstance(currDate.year(), currDate.month(), 1);
                Date endDate = Date.newInstance(currDate.year(), currDate.month(), 1).addMonths(1).addDays(-1);
                String uniqueIdDate = String.valueOf(startDate.year())+String.valueOf(startDate.month())+String.valueOf(startDate.day())+String.valueOf(endDate.year())+String.valueOf(endDate.month())+String.valueOf(endDate.day());

                blng__FinancePeriod__c financePeriod = new blng__FinancePeriod__c();
                financePeriod.blng__FinanceBook__c = finBook.Id;
                financePeriod.blng__LegalEntity__c = legalEntity.Id;
                financePeriod.blng__PeriodStartDate__c = startDate;
                financePeriod.blng__PeriodEndDate__c = endDate;
                financePeriod.blng__PeriodStatus__c = 'Open';
                //financePeriod.blng__UniqueId__c = finBook.Id+uniqueIdDate+'usd';
                periods.add(financePeriod);
            }
        }
        return periods;
    }

    public blng__TaxRule__c createTaxRule(Boolean doInsert) {
        blng__TaxRule__c obj = new blng__TaxRule__c();
        obj.Name ='No Tax Calculation';
        obj.blng__Active__c = true;
        obj.blng__TaxableYesNo__c = 'Yes';
        //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__RevenueRecognitionRule__c createRevRecRule(Boolean doInsert) {
        blng__RevenueRecognitionRule__c obj = new blng__RevenueRecognitionRule__c();
        obj.Name ='Standard Revenue Recognition Rule';
        obj.blng__Active__c = true;
        obj.blng__CreateRevenueSchedule__c = 'Yes';
        //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__GLRule__c createGlRule(Boolean doInsert) {
        blng__GLRule__c obj = new blng__GLRule__c();
        obj.Name ='Standard GL Rule';
        obj.blng__Active__c = true;
        //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__FinanceBook__c createFinanceBookRevenue(Boolean doInsert) {
        blng__FinanceBook__c obj = new blng__FinanceBook__c();
        obj.Name ='Accounting Book';
        obj.blng__Active__c = true;
        obj.blng__PeriodType__c = 'Accounting';
        //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__FinanceBook__c createFinanceBookAccounting(Boolean doInsert) {
        blng__FinanceBook__c obj = new blng__FinanceBook__c();
        obj.Name ='Revenue Book';
        obj.blng__Active__c = true;
        obj.blng__PeriodType__c = 'Revenue';
        //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__BillingTreatment__c createBillingTreatment(blng__BillingRule__c billingRule,
        blng__GLRule__c glRule,
        blng__FinanceBook__c finBook,
        Boolean doInsert) {
        blng__BillingTreatment__c obj = new blng__BillingTreatment__c();
        obj.Name ='Standard Billing Treatment';
        obj.blng__Active__c = true;
        //obj.blng__BillingLegalEntity__c = 'Revenue';
        obj.blng__BillingGLRule__c = glRule.Id;
        obj.blng__BillingFinanceBook__c = finBook.Id;
        obj.blng__BillingRule__c = billingRule.Id;
        //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (doInsert) { insert obj; }
        return obj;
    }
    public blng__BillingTreatment__c createBillingTreatment(blng__BillingRule__c billingRule,
        blng__GLRule__c glRule,
        blng__FinanceBook__c finBook,
        blng__LegalEntity__c legalEntity,
        Boolean doInsert) {
        blng__BillingTreatment__c obj = createBillingTreatment(billingRule, glRule, finBook, false);
        obj.blng__BillingLegalEntity__c = legalEntity.Id;
        if (doInsert) { insert obj; }
        return obj;
    }

    public blng__RevenueDistributionMethod__c createRevenueDistMethod(Boolean doInsert) {
        blng__RevenueDistributionMethod__c obj = new blng__RevenueDistributionMethod__c();
        obj.Name ='Standard Revenue Distribution Method - Order';
        obj.blng__Active__c = true;
        obj.blng__RevenueTransactionCreationProcess__c = 'Automatic';
        obj.blng__MonthlyRecognitionProration__c = 'Number of Days';
        obj.blng__Type__c = 'Order';
        obj.blng__DistributionMethod__c = 'Monthly';
        obj.blng__RevenueScheduleTermStartDate__c = 'Order Product Start Date';
        obj.blng__RevenueScheduleTermEndDate__c = 'Order Product End Date';
        //obj.CurrencyIsoCode = 'USD'; // Uncomment for multi-currency orgs
        if (doInsert) { insert obj; }
        return obj;
    }

    public class FinanceTestObjects {
        public blng__LegalEntity__c legalEntity {get; set;}
        public blng__BillingRule__c billingRule {get; set;}
        public blng__BillingRule__c billingRuleDoNotInvoice {get; set;}
        public blng__RevenueRecognitionRule__c revRecRule {get; set;}
        public blng__TaxRule__c taxRule {get; set;}
        public blng__GLRule__c glRule {get; set;}
        public blng__FinanceBook__c financeBookRevenue {get; set;}
        public blng__FinanceBook__c financeBookAccounting {get; set;}
        public blng__BillingTreatment__c billingTreatment {get; set;}
        public blng__RevenueDistributionMethod__c revenueDistMethod {get; set;}
        public blng__RevenueRecognitionTreatment__c revRecTreatment {get; set;}
        public blng__GLAccount__c gLAccount {get; set;}
        public blng__GLTreatment__c gLTreatment {get; set;}
        public List<blng__FinancePeriod__c> revenueFinancePeriod {get; set;}
        public List<blng__FinancePeriod__c> acconutingFinancePeriod {get; set;}
    }

    public void createBillingPrefix() {
        blng__BillingPrefix__c billingPrefix = new blng__BillingPrefix__c();
        billingPrefix.Name = 'aAMS00000000IB2';
        billingPrefix.blng__BarPrefix__c = 'blng__';
        billingPrefix.blng__DotPrefix__c = 'blng.';
        billingPrefix.blng__RawPrefix__c = 'blng';
        insert billingPrefix;
    }

    /** Create default legal entity */
    public blng__LegalEntity__c createLegalEntity(Boolean doInsert) {
        blng__LegalEntity__c obj = new blng__LegalEntity__c();
        obj.Name = 'AvalaraForPrimePay';
        obj.blng__Active__c = true;
        obj.blng__City__c = 'West chester';
        obj.blng__Country__c = 'USA';
        obj.blng__State__c = 'PA';
        obj.blng__Street1__c = '1487 Dunwoody Drive';
        obj.blng__ZipPostalCode__c = '19380';
        if (doInsert) { insert obj; }
        return obj;
    }

    public List<blng__BillingConfig__c> createBillingConfigs() {
        List<blng__BillingConfig__c> billingConfigs = new List<blng__BillingConfig__c>();

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'INSERT_SAMPLE_DATA',
            blng__BooleanValue__c = false,
            blng__Description__c = 'Insert Sample Data',
            blng__FieldType__c = 'Boolean'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'USAGE_RATING_PROCESS',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Usage Rating Process based on',
            blng__FieldType__c = 'Picklist',
            blng__PicklistIndicator__c = 'UsageRatingProcessList',
            blng__Sequence__c = 9,
            blng__StringValue__c = 'On Trigger'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'BILLING_REMAINDER_PROCESS',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Invoice',
            blng__Description__c = 'Billing Remainder Process',
            blng__FieldType__c = 'Picklist',
            blng__PicklistIndicator__c = 'billingRemainderProcessList',
            blng__Sequence__c = 5,
            blng__StringValue__c = 'Last Period'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'PARTIAL_PERIOD_BILLING_PRORATION',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Invoice',
            blng__Description__c = 'Partial Proration Type',
            blng__FieldType__c = 'Picklist',
            blng__PicklistIndicator__c = 'PartialProrationTypeList',
            blng__Sequence__c = 3,
            blng__StringValue__c = 'Month + Daily'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'PERIOD_PRICE_ROUNDING',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Billable Unit Price Rounding',
            blng__FieldType__c = 'Picklist',
            blng__PicklistIndicator__c = 'PeriodPriceRoundingList',
            blng__Sequence__c = 8,
            blng__StringValue__c = 'HALF_UP'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'REVENUE_REMAINDER_PROCESS',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Invoice',
            blng__Description__c = 'Revenue Remainder Process',
            blng__FieldType__c = 'Picklist',
            blng__PicklistIndicator__c = 'RevenueRemainderProcessList',
            blng__Sequence__c = 6,
            blng__StringValue__c = 'Last Period'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'SAVE_CREDIT_CARD_ON_PAYMENT_PAGE',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Save credit card details',
            blng__FieldType__c = 'Boolean',
            blng__Sequence__c = 6));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'ENABLE_STATE_AND_COUNTRY_PICKLIST',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Enable state and country picklist in Site Page and Virtual Terminal(works when state and country feature is enabled in Salesforce)',
            blng__FieldType__c = 'Boolean',
            blng__Sequence__c = 6));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'ACCOUNT_LEGAL_ENTITY_FIELD_NAME',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Select Account field that holds the legal entity information',
            blng__FieldType__c = 'String',
            blng__PicklistIndicator__c = 'Account',
            blng__Sequence__c = 1,
            blng__StringValue__c = 'AccountNumber'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'ADVANCED_AR_APPLICATION',
            blng__BooleanValue__c = true,
            blng__Category__c = 'Invoice',
            blng__Description__c = 'Advanced AR application',
            blng__FieldType__c = 'Boolean',
            blng__Sequence__c = 2));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'ORDER_LEGAL_ENTITY_FIELD_NAME',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Select Order field that holds the Legal Entity (This will override the Account Legal Entity field)',
            blng__FieldType__c = 'String',
            blng__PicklistIndicator__c = 'ORDER_FIELD_NAME',
            blng__Sequence__c = 3,
            blng__StringValue__c = 'Order Number'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'ALIGN_BILLDAYOFMONTH_TO_ORDERSTARTDATE',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Align Billing day of month to Order start date.',
            blng__FieldType__c = 'Boolean',
            blng__Sequence__c = 3));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'PRORATION_TYPE',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Invoice',
            blng__Description__c = 'Proration type.',
            blng__FieldType__c = 'String',
            blng__Sequence__c = 3,
            blng__StringValue__c = 'Calendar Days'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'INVOICE_TO_BE_CHARGED_ON',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Invoice',
            blng__Description__c = 'Payment Scheduler to pickup unpaid invoices on OR after',
            blng__FieldType__c = 'String',
            blng__Sequence__c = 2,
            blng__StringValue__c = 'Due Date'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'AVALARA_AVATAX',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Tax',
            blng__StringValue__c = 'Avalara AvaTax'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'DISABLE_TRIGGERS',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Disable triggers',
            blng__FieldType__c = 'Boolean'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'PAYMENT_METHOD_DISPLAY',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Payment',
            blng__Description__c = 'Payment Method Display',
            blng__FieldType__c = 'Picklist',
            blng__PicklistIndicator__c = 'PaymentMethodDisplayList',
            blng__Sequence__c = 1,
            blng__StringValue__c = 'Nickname'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'CARD_MAPPING',
            blng__BooleanValue__c = false,
            blng__Category__c = 'Payment',
            blng__Description__c = 'Card Mapping',
            blng__FieldType__c = 'String',
            blng__Sequence__c = 2));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'TAX_CALCULATION_BASED_ON',
            blng__BooleanValue__c = false,
            blng__Category__c = 'General',
            blng__Description__c = 'Tax calculation is based on?',
            blng__FieldType__c = 'Picklist',
            blng__PicklistIndicator__c = 'TaxcCalculationList',
            blng__Sequence__c = 3,
            blng__StringValue__c = 'Order: Account Shipping Address'));

        billingConfigs.add(new blng__BillingConfig__c(
            Name = 'TAX_EXEMPT',
            blng__BooleanValue__c = false,
            blng__Sequence__c = 9));

        insert billingConfigs;
        return billingConfigs;
    }

    public blng__PaymentMethod__c createPaymentMethod(Account acct, Boolean doInsert) {
        blng__PaymentMethod__c paymentMethod = new blng__PaymentMethod__c();
        paymentMethod.blng__Account__c = acct.Id;
        paymentMethod.blng__Active__c = true;
        paymentMethod.blng__BankAccountType__c = 'Checking';
        paymentMethod.blng__PaymentType__c = 'ACH';

        if (doInsert) { insert paymentMethod; }
        return paymentMethod;
    }

    public blng__Invoice__c createInvoice(Account account, Order order, Boolean doInsert) {
        return createInvoice(account, order, doInsert, '14973936196600017A00000OqeglQABNet 30');
    }

    public blng__Invoice__c createInvoice(Account account, Order order, Boolean doInsert, String uniqeId) {
        blng__Invoice__c invoice = new blng__Invoice__c();
        invoice.blng__InvoiceStatus__c = 'Posted';
        invoice.blng__Account__c = account.Id;
        invoice.blng__DueDate__c = Date.today();
        invoice.blng__InvoiceDate__c = Date.today();
        invoice.blng__Order__c = order.Id;
        invoice.blng__TargetDate__c = Date.today();
        invoice.blng__UniqueId__c = uniqeId;
        if (doInsert) { insert invoice; }
        return invoice;
    }

    public blng__InvoiceLine__c createInvoiceLine(blng__Invoice__c invoice, OrderItem op, Product2 p, Boolean doInsert) {
        return createInvoiceLine(invoice, op, p, doInsert, '8027A000000PUXOQA4_2017-6-13_2019-6-12___a1z7A000000Hn6iQAC__01t7A000001jG2aQAE');
    }

    public blng__InvoiceLine__c createInvoiceLine(blng__Invoice__c invoice, OrderItem op, Product2 p, Boolean doInsert, String uniqeId) {
        blng__InvoiceLine__c invoiceLine = new blng__InvoiceLine__c();
        invoiceLine.Name = 'Branded Content';
        //invoiceLine.CurrencyIsoCode = 'USD'; //uncomment if multicurrency is enabled
        invoiceLine.blng__BillingFinanceBook__c = op.blng__FinanceBookAccounting__c;
        invoiceLine.blng__BillingRule__c = op.blng__BillingRule__c;
        invoiceLine.blng__BillingTreatment__c = op.blng__BillingTreatment__c;
        invoiceLine.blng__CalculatedQuantity__c = 1;
        invoiceLine.blng__ChargeDate__c = Date.today();
        invoiceLine.blng__ChargeType__c = 'One-Time';
        invoiceLine.blng__EndDate__c = Date.today().addMonths(1);
        invoiceLine.blng__InvoiceLineState__c = 'Regular';
        invoiceLine.blng__InvoiceLineStatus__c = 'Posted';
        invoiceLine.blng__Invoice__c = invoice.Id;
        invoiceLine.blng__LegalEntityReference__c = op.blng__LegalEntityReference__c;
        invoiceLine.blng__NegativeLineConversion__c = 0;
        invoiceLine.blng__OrderProduct__c = op.Id;
        invoiceLine.blng__Product__c = p.Id;
        invoiceLine.blng__Quantity__c = 1;
        invoiceLine.blng__StartDate__c = Date.today();
        invoiceLine.blng__Subtotal__c = 100;
        invoiceLine.blng__TaxErrorMessage__c = 'This line is not taxable';
        invoiceLine.blng__TaxRule__c = op.blng__TaxRule__c;
        invoiceLine.blng__TaxStatus__c = 'Warning';
        //invoiceLine.blng__TaxTreatment__c = 'a2g7A000000DKFLQA4';
        invoiceLine.blng__TotalAmount__c = 100;
        invoiceLine.blng__UniqueId__c = uniqeId;
        invoiceLine.blng__UnitPrice__c = 100;
        if (doInsert) { insert invoiceLine; }
        return invoiceLine;
    }

    public FinanceTestObjects createFinanceObjects() {
        // CREATE GLOBAL SETTINGS
        createBillingPrefix();
        createBillingConfigs();
        FinanceTestObjects fin = new FinanceTestObjects();
        fin.legalEntity = createLegalEntity(true);
        fin.billingRule = createBillingRule(true);
        fin.billingRuleDoNotInvoice = createBillingRuleDoNotInvoice(true);
        fin.revRecRule = createRevRecRule(true);
        fin.taxRule = createTaxRule(true);
        fin.glRule = createGlRule(true);
        fin.financeBookRevenue = createFinanceBookRevenue(true);
        fin.financeBookAccounting = createFinanceBookAccounting(true);
        fin.billingTreatment = createBillingTreatment(fin.billingRule, fin.glRule, fin.financeBookRevenue, fin.legalEntity, true);

        fin.gLAccount = createGLAccount(true);
        fin.gLTreatment = createGLTreatment(fin.gLAccount, fin.glRule, fin.legalEntity, true);

        fin.revenueDistMethod = createRevenueDistMethod(true);
        fin.revRecTreatment = createRevRecTreatment(fin.revRecRule, fin.glRule, fin.financeBookAccounting, fin.revenueDistMethod, fin.legalEntity, true);
        fin.revenueFinancePeriod = createFinancePeriods(fin.financeBookRevenue, 3, fin.legalEntity);
        fin.acconutingFinancePeriod = createFinancePeriods(fin.financeBookAccounting, 3, fin.legalEntity);

        List<blng__FinancePeriod__c> periods = new List<blng__FinancePeriod__c>();
        periods.addAll(fin.revenueFinancePeriod);
        periods.addAll(fin.acconutingFinancePeriod);

        insert periods;

        System.debug(LoggingLevel.WARN, fin);

        return fin;
    }
}