/**
 * 
 * CPQXL_OrderContractXLInitializer class
 *
 * Versioning: 
 *   3/31/21 : Steve Lohrenz : File Created
 */

public with sharing class CPQXL_OrderContractXLInitializer {
  private static final Map<String, CPQU_UtilitySetting__mdt> utilitySettings = new Map<String, CPQU_UtilitySetting__mdt>();

  // static initialization
  static {
    utilitySettings.putAll(CPQU_ApexUtils.groupSettingsByDeveloperName(
    [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
    FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]));
  }

  public String scenarioType = CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO;

  // constructor:
  public CPQXL_OrderContractXLInitializer(Id sourceOrderId, Id sourceQuoteId, List<String> bundlesToExcludeParam) {
    contractOrder(sourceOrderId, sourceQuoteId, bundlesToExcludeParam);
  }

  public CPQXL_OrderContractXLInitializer(Id sourceOrderId, Id sourceQuoteId, List<String> bundlesToExcludeParam, String scenarioType) {
    this.scenarioType = scenarioType;
    contractOrder(sourceOrderId, sourceQuoteId, bundlesToExcludeParam);
  }
  
  public void contractOrder(Id orderId, Id quoteId, List<String> bundlesToExcludeParam) {
    // query the subset orders (aka smaller orders) that make up the main (aka large) order:
    Map<Id, Order> subsetOrders = new Map<Id, Order>([
      SELECT Id, CPQXL_LargeOrderId__c, SBQQ__Contracted__c
      FROM Order
      WHERE CPQXL_LargeOrderId__c != NULL AND CPQXL_LargeOrderId__c = :orderId
    ]);

    Set<Id> remainingSubsetOrderIds = subsetOrders.keySet();

    for(Order anOrder : subsetOrders.values()) {
      if(anOrder.SBQQ__Contracted__c) {
        SObjectException e = new SObjectException();
        e.setMessage('Cannot generate large Contract for Order with Id ' + anOrder.Id + '. One or more of the subset Orders is marked as Contracted. '
          + 'Before generating a large contract, all subset Orders must not be marked as Contracted. Please contact your System Administrator');
        throw e;
      }
    }

    CPQXL_GenerateLargeContractEvent__e firstGLcEventInTheChain = initializeGlcEvent(orderId, quoteId, remainingSubsetOrderIds);
    EventBus.publish(firstGLcEventInTheChain);
  }

  /**
     * @description -> Method to initialize the first event in the Generate Large Contract platform event chain.
     * @param
     * @return Generate_Large_Contract_Event__e -> the first event in a Generate Large Contract platform event chain
     */
  private CPQXL_GenerateLargeContractEvent__e initializeGlcEvent(Id orderId, Id quoteId,  Set<Id> remainingSubsetOrderIds) {
    System.debug(LoggingLevel.WARN, 'GenerateLargeContractController.initializeGlcEvent()...');
    // Initialize additional Generate Large Quote platform event in memory (do not publish yet, we'll do that later in the execution):
    return new CPQXL_GenerateLargeContractEvent__e(
      CPQXL_SourceContext__c = 'Order', // static
      CPQXL_OrderId__c = (String) orderId, // static
      CPQXL_PrimaryQuoteId__c = (String) quoteId, // static
      CPQXL_RemainingSubsetOrderIds__c = JSON.serialize(remainingSubsetOrderIds) // dynamic
    );
  }
}