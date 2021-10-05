/** Description:
* CPQU_EventTriggerHandlerTest - Test class for Generic extendable handler for events.
*
* Create by: Steve Lohrenz : 21.02.18
* Updated : 03.11.2020 : Kevin Antonioli : add the ATG_ prefix
*
* TODO: needs work to be client agnostic
*
*/
@IsTest
private class CPQU_EventTriggerHandlerTest {
    @TestSetup
    private static void dataSetup() {
        CPQU_Features__c features = new CPQU_Features__c(SetupOwnerId = UserInfo.getOrganizationId(), AllTriggerHandlersDisabled__c = false,
                CPQU_ErrorLogEventTriggerHandler__c = false);
        insert features;

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
    }

    @IsTest
    static void test_EventTriggerHandler_negative() {
        Test.startTest();
        CPQU_ExampleTriggerHandler handler = new CPQU_ExampleTriggerHandler();
        handler.handleEventInsert(new List<CPQU_ErrorLogEvent__e> {new CPQU_ErrorLogEvent__e()});
        Test.stopTest();
    }

    @IsTest
    static void test_EventTriggerHandler_negative2() {
        CPQU_EventTriggerHandler.testNumberRetries = 0;
        Test.startTest();
        CPQU_ExampleTriggerHandler handler = new CPQU_ExampleTriggerHandler('CPQU_ExampleTriggerHandler');
        handler.handleEventInsert(new List<CPQU_ErrorLogEvent__e> {new CPQU_ErrorLogEvent__e()});
        Test.stopTest();
    }

    @IsTest
    static void test_EventTriggerHandlerCustomException() {
        CPQU_EventTriggerHandler.testNumberRetries = 1;

        CPQU_ExampleTriggerHandler handler = new CPQU_ExampleTriggerHandler('CPQU_ExampleTriggerHandler');
        handler.exceptionHandlingOn = true;
        Test.startTest();
        handler.handleEventInsert(new List<CPQU_ErrorLogEvent__e> {new CPQU_ErrorLogEvent__e()});
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM CPQU_ErrorLog__c].size());
    }

    @IsTest
    static void test_EventTriggerHandlerRetryableExceptionException() {
        CPQU_EventTriggerHandler.testNumberRetries = 1;

        CPQU_ExampleTriggerHandler handler = new CPQU_ExampleTriggerHandler('CPQU_ExampleTriggerHandler');
        handler.exceptionHandlingOn = true;
        handler.exceptionType = 'RetryableException';
        Test.startTest();
        try {
            handler.handleEventInsert(new List<CPQU_ErrorLogEvent__e>{
                    new CPQU_ErrorLogEvent__e()
            });
            System.assert(false);
        } catch(EventBus.RetryableException eek) {
            System.assert(true);
        }
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM CPQU_ErrorLog__c].size());
    }

    @IsTest
    static void test_EventTriggerHandlerLogSuccessEvents() {
        CPQU_EventTriggerHandler.testNumberRetries = 1;

        CPQU_ExampleTriggerHandler handler = new CPQU_ExampleTriggerHandler('CPQU_ExampleTriggerHandler');
        handler.exceptionHandlingOn = false;
        handler.logSuccessEvents = true;
        Test.startTest();
        handler.handleEventInsert(new List<CPQU_ErrorLogEvent__e> {new CPQU_ErrorLogEvent__e()});
        Test.stopTest();
        System.assertEquals(1, [SELECT Id FROM CPQU_ErrorLog__c].size());
    }

    public class CPQU_ExampleTriggerHandler extends CPQU_EventTriggerHandler {
        public Boolean exceptionHandlingOn { get; set; }
        public String exceptionType {get; set;}
        public CPQU_ExampleTriggerHandler() {
            super();
            exceptionHandlingOn = false;
        }

        public CPQU_ExampleTriggerHandler(String handlerName) {
            super(handlerName);
            exceptionHandlingOn = true;
        }

        protected override void afterEventInsert(List<SObject> events) {
            if(exceptionHandlingOn) {
                if(exceptionType == 'RetryableException') {
                    throw new EventBus.RetryableException();
                } else {
                    throw new CPQU_ErrorLogUtils.CPQU_Exception();
                }
            }
        }
    }

}