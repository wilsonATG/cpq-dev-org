/**
 * 
 * CPQXL_AsyncQueueableTest class
 *
 * Versioning: 
 *   3/22/21 : Steve Lohrenz : File Created
 */

@IsTest
private class CPQXL_AsyncQueueableTest {
    @TestSetup
    static void setBaseScenario() {
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
    static void test_AsyncOrderingQueueable_positive(){
        SBQQ__Quote__c quote = [
            SELECT Id FROM SBQQ__Quote__c LIMIT 1
        ];
        quote.SBQQ__Primary__c = true;
        update quote;

        Test.startTest();
        Id jobId = System.enqueueJob(new CPQXL_AsyncQueueable(quote.Id, CPQXL_AsyncQueueable.SBQQ_ORDERED_FIELD));
        Test.stopTest(); 

        quote = [
            SELECT Id, SBQQ__Ordered__c FROM SBQQ__Quote__c LIMIT 1
        ];
        System.assertEquals(quote.SBQQ__Ordered__c, true);
    }

    @IsTest
    static void test_AsyncOrderingQueueable_negative(){
        SBQQ__Quote__c quote = [
            SELECT Id FROM SBQQ__Quote__c LIMIT 1
        ];
        quote.SBQQ__Primary__c = false;
        update quote;

        Test.startTest();
        // CPQ does not allow non-primary quotes to be ordered. This should hit the exception in the CPQXL_AsyncOrderingQueueable class:
        Id jobId = System.enqueueJob(new CPQXL_AsyncQueueable(quote.Id, CPQXL_AsyncQueueable.SBQQ_ORDERED_FIELD));
        Test.stopTest();

        quote = [
            SELECT Id, SBQQ__Ordered__c FROM SBQQ__Quote__c LIMIT 1
        ];
        System.assertEquals(quote.SBQQ__Ordered__c, false);
    }
}