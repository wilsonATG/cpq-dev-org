/**
 * 
 * CPQU_TestsCacheBilling class
 *
 * Versioning: 
 *   3/31/21 : stevelohrenz : File Created
 */

@IsTest
public class CPQU_TestsCacheBilling implements CPQU_TestsCache.CPQU_TestCacheExtendedInterface {

    private static CPQU_TestUtilsBilling.FinanceTestObjects fin;
    private static blng__BillingRule__c billingRule; //#SFBILLING
    private static blng__TaxRule__c taxRule; //#SFBILLING
    private static blng__RevenueRecognitionRule__c revRecRule; //#SFBILLING
    private static blng__GLRule__c glRule; //#SFBILLING
    private static blng__FinanceBook__c financeBookRevenue; //#SFBILLING
    private static blng__FinanceBook__c financeBookAccounting; //#SFBILLING
    private static blng__BillingTreatment__c billingTreatment;

    public Map<String, Id> initialSetupAdditional() {
        Map<String, Id> mappingIdsByName = new Map<String, Id>();
        CPQU_TestUtilsBilling cpqTestUtilsBilling = new CPQU_TestUtilsBilling();

        fin = cpqTestUtilsBilling.createFinanceObjects(); //#SFBILLING

        billingRule = cpqTestUtilsBilling.createBillingRule(true); //#SFBILLING
        taxRule = cpqTestUtilsBilling.createTaxRule(true); //#SFBILLING
        revRecRule = cpqTestUtilsBilling.createRevRecRule(true); //#SFBILLING
        glRule = cpqTestUtilsBilling.createGlRule(true); //#SFBILLING
        financeBookRevenue = cpqTestUtilsBilling.createFinanceBookRevenue(true); //#SFBILLING
        financeBookAccounting = cpqTestUtilsBilling.createFinanceBookAccounting(true); //#SFBILLING
        billingTreatment = cpqTestUtilsBilling.createBillingTreatment(billingRule, glRule, financeBookRevenue, true); //#SFBILLING

        //mappingIdsByName.put('FinanceTestObjects', fin);
        mappingIdsByName.put('blng__BillingRule__c', billingRule.Id);
        mappingIdsByName.put('blng__TaxRule__c', taxRule.Id);
        mappingIdsByName.put('blng__RevenueRecognitionRule__c', revRecRule.Id);
        mappingIdsByName.put('blng__GLRule__c', glRule.Id);
        mappingIdsByName.put('blng__FinanceBook__cRev', financeBookRevenue.Id);
        mappingIdsByName.put('blng__FinanceBook__cAcc', financeBookAccounting.Id);
        mappingIdsByName.put('blng__BillingTreatment__c', billingTreatment.Id);

        return mappingIdsByName;
    }

    @IsTest
    static void testBehavior() {
    }
}