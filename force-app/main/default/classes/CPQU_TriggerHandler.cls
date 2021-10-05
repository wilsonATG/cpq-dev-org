// https://github.com/kevinohara80/sfdc-trigger-framework/blob/master/src/classes/ATG_TriggerHandler.cls
public virtual class CPQU_TriggerHandler {

    // static map of handlerName, times run() was invoked
    private static Map<String, LoopCount> loopCountMap;
    private static Set<String> bypassedHandlers;
  
    // the current context of the trigger, overridable in tests
    @TestVisible
    private TriggerContext context;
  
    // the current context of the trigger, overridable in tests
    @TestVisible
    private Boolean isTriggerExecuting;

    private String handlerName {get; set;}

    public static final Map<String, CPQU_UtilitySetting__mdt> CPQU_UTILITY_SETTING_MAP = new Map<String, CPQU_UtilitySetting__mdt>();
    public static CPQU_Features__c CPQU_FEATURES = CPQU_Features__c.getInstance(UserInfo.getUserId());
    public static final Map<String, Schema.SObjectField> CPQU_FEATURES_FIELD_MAP = Schema.SObjectType.CPQU_Features__c.fields.getMap();
    // static initialization
    static {
      loopCountMap = new Map<String, LoopCount>();
      bypassedHandlers = new Set<String>();
      CPQU_UTILITY_SETTING_MAP.putAll(CPQU_ApexUtils.groupSettingsByDeveloperName(
        [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
        FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]));

    }
    
    // constructor
    public CPQU_TriggerHandler() {
      this.setTriggerContext();
        CPQU_FEATURES = CPQU_Features__c.getInstance(UserInfo.getUserId());
    }

    public CPQU_TriggerHandler(String handlerName) {
        this.handlerName = handlerName;
        this.setTriggerContext();
        CPQU_FEATURES = CPQU_Features__c.getInstance(UserInfo.getUserId());
    }
  
    /***************************************
     * public instance methods
     ***************************************/
  
    // main method that will be called during execution
    public void run() {
  
      if(!validateRun()) return;
  
      addToLoopCount();
  
      // dispatch to the correct handler method
      if(this.context == TriggerContext.BEFORE_INSERT) {
        this.beforeInsert();
      } else if(this.context == TriggerContext.BEFORE_UPDATE) {
        this.beforeUpdate();
      } else if(this.context == TriggerContext.BEFORE_DELETE) {
        this.beforeDelete();
      } else if(this.context == TriggerContext.AFTER_INSERT) {
        this.afterInsert();
      } else if(this.context == TriggerContext.AFTER_UPDATE) {
        this.afterUpdate();
      } else if(this.context == TriggerContext.AFTER_DELETE) {
        this.afterDelete();
      } else if(this.context == TriggerContext.AFTER_UNDELETE) {
        this.afterUndelete();
      }
  
    }
  
    public void setMaxLoopCount(Integer max) {
      String handlerName = getHandlerName();
      if(!CPQU_TriggerHandler.loopCountMap.containsKey(handlerName)) {
        CPQU_TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
      } else {
        CPQU_TriggerHandler.loopCountMap.get(handlerName).setMax(max);
      }
    }
  
    public void clearMaxLoopCount() {
      this.setMaxLoopCount(-1);
    }
  
    /***************************************
     * public static methods
     ***************************************/
  
    public static void bypass(String handlerName) {
      CPQU_TriggerHandler.bypassedHandlers.add(handlerName);
    }
  
    public static void clearBypass(String handlerName) {
      CPQU_TriggerHandler.bypassedHandlers.remove(handlerName);
    }
  
    public static Boolean isBypassed(String handlerName) {
      return CPQU_TriggerHandler.bypassedHandlers.contains(handlerName);
    }
  
    public static void clearAllBypasses() {
      CPQU_TriggerHandler.bypassedHandlers.clear();
    }
  
    /***************************************
     * private instance methods
     ***************************************/
  
    @TestVisible
    private void setTriggerContext() {
      this.setTriggerContext(null, false);
    }
  
    @TestVisible
    private void setTriggerContext(String ctx, Boolean testMode) {
      if(!Trigger.isExecuting && !testMode) {
        this.isTriggerExecuting = false;
        return;
      } else {
        this.isTriggerExecuting = true;
      }
      
      if((Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) ||
          (ctx != null && ctx == 'before insert')) {
        this.context = TriggerContext.BEFORE_INSERT;
      } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) ||
          (ctx != null && ctx == 'before update')){
        this.context = TriggerContext.BEFORE_UPDATE;
      } else if((Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) ||
          (ctx != null && ctx == 'before delete')) {
        this.context = TriggerContext.BEFORE_DELETE;
      } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) ||
          (ctx != null && ctx == 'after insert')) {
        this.context = TriggerContext.AFTER_INSERT;
      } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) ||
          (ctx != null && ctx == 'after update')) {
        this.context = TriggerContext.AFTER_UPDATE;
      } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) ||
          (ctx != null && ctx == 'after delete')) {
        this.context = TriggerContext.AFTER_DELETE;
      } else if((Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) ||
          (ctx != null && ctx == 'after undelete')) {
        this.context = TriggerContext.AFTER_UNDELETE;
      }
    }
  
    // increment the loop count
    @TestVisible
    private void addToLoopCount() {
      String handlerName = getHandlerName();
      if(CPQU_TriggerHandler.loopCountMap.containsKey(handlerName)) {
        Boolean exceeded = CPQU_TriggerHandler.loopCountMap.get(handlerName).increment();
        if(exceeded) {
          Integer max = CPQU_TriggerHandler.loopCountMap.get(handlerName).max;
          throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
        }
      }
    }

  // make sure this trigger should continue to run
  @TestVisible
  private Boolean validateRun() {
    if (!this.isTriggerExecuting || this.context == null) {
      throw new TriggerHandlerException('Trigger handler called outside of Trigger execution');
    }

      System.debug('CPQU_TriggerHandler.validateRun() ' + CPQU_FEATURES.get(CPQU_Constants.CUSTOM_FEATURES_ALL_TRIGGER_NAME));
    if (CPQU_TriggerHandler.bypassedHandlers.contains(getHandlerName()) ||
      (Boolean) CPQU_FEATURES.get(CPQU_Constants.CUSTOM_FEATURES_ALL_TRIGGER_NAME) ||
            (CPQU_FEATURES_FIELD_MAP.containsKey(this.handlerName + '__c') && (Boolean) CPQU_FEATURES.get(this.handlerName + '__c'))) {
      return false;
    }
    return true;
  }

  @TestVisible
  protected String getHandlerName() {
    if (String.isBlank(this.handlerName)) {
      this.handlerName = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    }
    return this.handlerName;
  }
  
    /***************************************
     * context methods
     ***************************************/
  
    // context-specific methods for override
    @TestVisible
    protected virtual void beforeInsert(){}
    @TestVisible
    protected virtual void beforeUpdate(){}
    @TestVisible
    protected virtual void beforeDelete(){}
    @TestVisible
    protected virtual void afterInsert(){}
    @TestVisible
    protected virtual void afterUpdate(){}
    @TestVisible
    protected virtual void afterDelete(){}
    @TestVisible
    protected virtual void afterUndelete(){}
  
    /***************************************
     * inner classes
     ***************************************/
  
    // inner class for managing the loop count per handler
    @TestVisible
    private class LoopCount {
      private Integer max;
      private Integer count;
  
      public LoopCount() {
        this.max = 5;
        this.count = 0;
      }
  
      public LoopCount(Integer max) {
        this.max = max;
        this.count = 0;
      }
  
      public Boolean increment() {
        this.count++;
        return this.exceeded();
      }
  
      public Boolean exceeded() {
        if(this.max < 0) return false;
        if(this.count > this.max) {
          return true;
        }
        return false;
      }
  
      public Integer getMax() {
        return this.max;
      }
  
      public Integer getCount() {
        return this.count;
      }
  
      public void setMax(Integer max) {
        this.max = max;
      }
    }
  
    // possible trigger contexts
    @TestVisible
    private enum TriggerContext {
      BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
      AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE,
      AFTER_UNDELETE
    }
  
    // exception class
    public class TriggerHandlerException extends Exception {}
  
  }