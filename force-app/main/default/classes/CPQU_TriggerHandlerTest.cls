@IsTest
private class CPQU_TriggerHandlerTest {

  private static final String TRIGGER_CONTEXT_ERROR = 'Trigger handler called outside of Trigger execution';

  private static String lastMethodCalled;

  private static CPQU_TriggerHandlerTest.TestHandler handler;

  static {
    handler = new CPQU_TriggerHandlerTest.TestHandler();
    // override its internal trigger detection
    handler.isTriggerExecuting = true;
  }

  @TestSetup
  static void testSetup() {
    CPQU_Features__c features = new CPQU_Features__c(SetupOwnerId = UserInfo.getOrganizationId(), AllTriggerHandlersDisabled__c = false,
            CPQU_ErrorLogEventTriggerHandler__c = false);
    insert features;
  }

  /***************************************
   * unit tests
   ***************************************/

  // contexts tests

  @IsTest
  static void testBeforeInsert() {
    beforeInsertMode();
    handler.run();
    System.assertEquals('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
  }

  @IsTest
  static void testBeforeUpdate() {
    beforeUpdateMode();
    handler.run();
    System.assertEquals('beforeUpdate', lastMethodCalled, 'last method should be beforeUpdate');
  }

  @IsTest
  static void testBeforeDelete() {
    beforeDeleteMode();
    handler.run();
    System.assertEquals('beforeDelete', lastMethodCalled, 'last method should be beforeDelete');
  }

  @IsTest
  static void testAfterInsert() {
    afterInsertMode();
    handler.run();
    System.assertEquals('afterInsert', lastMethodCalled, 'last method should be afterInsert');
  }

  @IsTest
  static void testAfterUpdate() {
    afterUpdateMode();
    handler.run();
    System.assertEquals('afterUpdate', lastMethodCalled, 'last method should be afterUpdate');
  }

  @IsTest
  static void testAfterDelete() {
    afterDeleteMode();
    handler.run();
    System.assertEquals('afterDelete', lastMethodCalled, 'last method should be afterDelete');
  }

  @IsTest
  static void testAfterUndelete() {
    afterUndeleteMode();
    handler.run();
    System.assertEquals('afterUndelete', lastMethodCalled, 'last method should be afterUndelete');
  }

  @IsTest
  static void testNonTriggerContext() {
    try{
      handler.run();
      System.assert(false, 'the handler ran but should have thrown');
    } catch(CPQU_TriggerHandler.TriggerHandlerException te) {
      System.assertEquals(TRIGGER_CONTEXT_ERROR, te.getMessage(), 'the exception message should match');
    } catch(Exception e) {
      System.assert(false, 'the exception thrown was not expected: ' + e.getTypeName() + ': ' + e.getMessage());
    }
  }

  // test bypass api

  @IsTest
  static void testBypassAPI() {
    afterUpdateMode();

    // test a bypass and run handler
    CPQU_TriggerHandler.bypass('TestHandler');
    handler.run();
    System.assertEquals(null, lastMethodCalled, 'last method should be null when bypassed');
    System.assertEquals(true, CPQU_TriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
    resetTest();

    // clear that bypass and run handler
    CPQU_TriggerHandler.clearBypass('TestHandler');
    handler.run();
    System.assertEquals('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
    System.assertEquals(false, CPQU_TriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
    resetTest();

    // test a re-bypass and run handler
    CPQU_TriggerHandler.bypass('TestHandler');
    handler.run();
    System.assertEquals(null, lastMethodCalled, 'last method should be null when bypassed');
    System.assertEquals(true, CPQU_TriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
    resetTest();

    // clear all bypasses and run handler
    CPQU_TriggerHandler.clearAllBypasses();
    handler.run();
    System.assertEquals('afterUpdate', lastMethodCalled, 'last method called should be afterUpdate');
    System.assertEquals(false, CPQU_TriggerHandler.isBypassed('TestHandler'), 'test handler should be bypassed');
    resetTest();
  }

  // instance method tests

  @IsTest
  static void testLoopCount() {
    beforeInsertMode();
    
    // set the max loops to 2
    handler.setMaxLoopCount(2);

    // run the handler twice
    handler.run();
    handler.run();

    // clear the tests
    resetTest();

    try {
      // try running it. This should exceed the limit.
      handler.run();
      System.assert(false, 'the handler should throw on the 3rd run when maxloopcount is 3');
    } catch(CPQU_TriggerHandler.TriggerHandlerException te) {
      // we're expecting to get here
      System.assertEquals(null, lastMethodCalled, 'last method should be null');
    } catch(Exception e) {  
      System.assert(false, 'the exception thrown was not expected: ' + e.getTypeName() + ': ' + e.getMessage());
    }

    // clear the tests
    resetTest();

    // now clear the loop count
    handler.clearMaxLoopCount();

    try {
      // re-run the handler. We shouldn't throw now.
      handler.run();
      System.assertEquals('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
    } catch(CPQU_TriggerHandler.TriggerHandlerException te) {
      System.assert(false, 'running the handler after clearing the loop count should not throw');
    } catch(Exception e) {  
      System.assert(false, 'the exception thrown was not expected: ' + e.getTypeName() + ': ' + e.getMessage());
    }
  }

  @IsTest
  static void testLoopCountClass() {
    CPQU_TriggerHandler.LoopCount lc = new CPQU_TriggerHandler.LoopCount();
    System.assertEquals(5, lc.getMax(), 'max should be five on init');
    System.assertEquals(0, lc.getCount(), 'count should be zero on init');

    lc.increment();
    System.assertEquals(1, lc.getCount(), 'count should be 1');
    System.assertEquals(false, lc.exceeded(), 'should not be exceeded with count of 1');

    lc.increment();
    lc.increment();
    lc.increment();
    lc.increment();
    System.assertEquals(5, lc.getCount(), 'count should be 5');
    System.assertEquals(false, lc.exceeded(), 'should not be exceeded with count of 5');

    lc.increment();
    System.assertEquals(6, lc.getCount(), 'count should be 6');
    System.assertEquals(true, lc.exceeded(), 'should not be exceeded with count of 6');
  }

  // private method tests

  @IsTest
  static void testGetHandlerName() {
    System.assertEquals('TestHandler', handler.getHandlerName(), 'handler name should match class name');
  }

  // test virtual methods
  
  @IsTest
  static void testVirtualMethods() {
    CPQU_TriggerHandler h = new CPQU_TriggerHandler();
    h.beforeInsert();
    h.beforeUpdate();
    h.beforeDelete();
    h.afterInsert();
    h.afterUpdate();
    h.afterDelete();
    h.afterUndelete();
  }

  /***************************************
   * testing utilities
   ***************************************/

  private static void resetTest() {
    lastMethodCalled = null;
  }

  // modes for testing

  private static void beforeInsertMode() {
    handler.setTriggerContext('before insert', true);
  }

  private static void beforeUpdateMode() {
    handler.setTriggerContext('before update', true);
  }

  private static void beforeDeleteMode() {
    handler.setTriggerContext('before delete', true);
  }

  private static void afterInsertMode() {
    handler.setTriggerContext('after insert', true);
  }

  private static void afterUpdateMode() {
    handler.setTriggerContext('after update', true);
  }

  private static void afterDeleteMode() {
    handler.setTriggerContext('after delete', true);
  }

  private static void afterUndeleteMode() {
    handler.setTriggerContext('after undelete', true);
  }

  // test implementation of the CPQU_TriggerHandler

  private class TestHandler extends CPQU_TriggerHandler {

    public override void beforeInsert() {
      CPQU_TriggerHandlerTest.lastMethodCalled = 'beforeInsert';
    }

    public override void  beforeUpdate() {
      CPQU_TriggerHandlerTest.lastMethodCalled = 'beforeUpdate';
    }

    public override void beforeDelete() {
      CPQU_TriggerHandlerTest.lastMethodCalled = 'beforeDelete';
    }

    public override void afterInsert() {
      CPQU_TriggerHandlerTest.lastMethodCalled = 'afterInsert';
    }

    public override void afterUpdate() {
      CPQU_TriggerHandlerTest.lastMethodCalled = 'afterUpdate';
    }

    public override void afterDelete() {
      CPQU_TriggerHandlerTest.lastMethodCalled = 'afterDelete';
    }

    public override void afterUndelete() {
      CPQU_TriggerHandlerTest.lastMethodCalled = 'afterUndelete';
    }

  }

  private class TestHandler2 extends CPQU_TriggerHandler {
    TestHandler2() {
      super('TestHandler2');
    }
  }

  @IsTest
  static void testValidateFeaturesAllDisabled(){
    CPQU_Features__c features = new CPQU_Features__c(SetupOwnerId = UserInfo.getUserId(), AllTriggerHandlersDisabled__c = true);
    Test.startTest();
    insert features;
    Test.stopTest();

    TestHandler2 testHandler = new CPQU_TriggerHandlerTest.TestHandler2();
    testHandler.isTriggerExecuting = true;
    testHandler.context = CPQU_TriggerHandler.TriggerContext.BEFORE_INSERT;

    System.assert(!testHandler.validateRun());
  }

  @IsTest
  static void testValidateFeaturesTrigger(){
    CPQU_Features__c features = new CPQU_Features__c(SetupOwnerId = UserInfo.getUserId(), CPQU_ErrorLogEventTriggerHandler__c = true);
    Test.startTest();
    insert features;
    Test.stopTest();

    CPQU_ErrorLogEventTriggerHandler testHandler = new CPQU_ErrorLogEventTriggerHandler();
    testHandler.isTriggerExecuting = true;
    testHandler.context = CPQU_TriggerHandler.TriggerContext.BEFORE_INSERT;

    System.assert(!testHandler.validateRun());
  }

  @IsTest
  static void testValidateFeaturesNoEntryForHandler(){
    handler.isTriggerExecuting = true;
    handler.context = CPQU_TriggerHandler.TriggerContext.BEFORE_INSERT;

    System.assert(handler.validateRun());
  }
	
}