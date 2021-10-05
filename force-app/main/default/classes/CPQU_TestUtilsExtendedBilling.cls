/**
 * 
 * CPQU_TestUtilsExtendedBilling class
 *
 * Versioning: 
 *   3/26/21 : Steve Lohrenz : File Created
 */

public with sharing class CPQU_TestUtilsExtendedBilling implements CPQU_TestUtils.CPQ_TestUtilsExtendedInterface {

    public Account createAccount(Account anAccount) {
        return anAccount;
    }

    public Contact createContact(Contact aContact) {
        return aContact;
    }

    public Product2 createProduct(Product2 aProduct, Id billingRuleId, Id taxRuleId, Id revRecRuleId) {
        aProduct.blng__BillingRule__c = billingRuleId == null ? null : billingRuleId; //#SFBILLING
        aProduct.blng__TaxRule__c = taxRuleId == null ? null : taxRuleId; //#SFBILLING
        aProduct.blng__RevenueRecognitionRule__c = revRecRuleId == null ? null : revRecRuleId; //#SFBILLING
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
        anOrder.blng__BillingDayOfMonth__c = String.valueOf(Date.today().day());
        return anOrder;
    }

    public OrderItem createOrderItem(OrderItem anOrderItem, Product2 product, Id legalEntityId) {
        anOrderItem.blng__BillableUnitPrice__c = 650;
        anOrderItem.blng__BillingRule__c = product.blng__BillingRule__c;
        //orderItem.blng__InvoiceRunStatus__c = 'Queued for Invoice';
        anOrderItem.blng__RevenueRecognitionRule__c = product.blng__RevenueRecognitionRule__c;
        anOrderItem.blng__TaxRule__c = product.blng__TaxRule__c;
        anOrderItem.blng__LegalEntity__c = legalEntityId;
        anOrderItem.blng__UniqueId__c = '8016C000000HRNaQAO-01u6C000000mQQtQAM-a5I6C00000055MxUAI';
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
        anOrder.blng__BillingDayOfMonth__c = '1';
        return anOrder;
    }

}