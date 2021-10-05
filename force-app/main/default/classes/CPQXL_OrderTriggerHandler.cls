/**
 * 
 * CPQXL_OrderTriggerHandler class
 *
 * Versioning: 
 *   3/22/21 : Steve Lohrenz : File Created
 */

public with sharing class CPQXL_OrderTriggerHandler extends CPQU_TriggerHandler {

    public CPQXL_OrderTriggerHandler() {
        super('CPQXL_OrderTriggerHandler');
    }

    public override void beforeUpdate() {
        List<Order> contractOrder = new List<Order>();
        for (Order anOrder : (List<Order>) Trigger.new) {
            if (anOrder.CPQXL_Contracted__c && !((Order) Trigger.oldMap.get(anOrder.Id)).CPQXL_Contracted__c) {
                contractOrder.add(anOrder);
            } else if (!anOrder.CPQXL_Contracted__c && ((Order) Trigger.oldMap.get(anOrder.Id)).CPQXL_Contracted__c) {
                anOrder.SBQQ__Contracted__c = false;
            }
        }

        if (!contractOrder.isEmpty()) {
            contractOrder(contractOrder);
        }
    }

    public void contractOrder(List<Order> orders) {
        System.debug('OrderTriggerHandler.contractOrder() orders: ' + orders);
        Map<Id, Order> orderMap = new Map<Id, Order> ([SELECT Id, (SELECT Id FROM OrderItems) FROM Order WHERE Id IN :orders]);
        for (Order anOrder : orders) {
            if (anOrder.CPQXL_Contracted__c && !((Order) Trigger.oldMap.get(anOrder.Id)).CPQXL_Contracted__c) {
                Integer numberOrderLines = orderMap.get(anOrder.Id).OrderItems.size();
                // if it is a large anOrder as determined by the custom setting:
                if (utilitySettings.containsKey(CPQXL_Constants.UTILITY_SETTING_VERY_LARGE_CONTRACT_THRESHOLD) &&
                    numberOrderLines > utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_VERY_LARGE_CONTRACT_THRESHOLD).NumberValue__c) {
                    // push the checking of the SBQQ__Ordered__c checkbox to an Apex Queueable to get a boost in governor limits:
                    CPQXL_OrderContractXLInitializer contractXLInitializer = new CPQXL_OrderContractXLInitializer(anOrder.Id, anOrder.SBQQ__Quote__c, null, CPQXL_Constants.LARGE_CONTRACT_SCENARIO);
                    System.debug('OrderTriggerHandler.contractOrder() jobId: Very Large Process Triggered');
                } else if (utilitySettings.containsKey(CPQXL_Constants.UTILITY_SETTING_LARGE_CONTRACT_THRESHOLD) &&
                    numberOrderLines > utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_LARGE_CONTRACT_THRESHOLD).NumberValue__c) {
                    // push the checking of the SBQQ__Contracted__c checkbox to an Apex Queueable to get a boost in governor limits:
                    Id jobId = System.enqueueJob(new CPQXL_AsyncQueueable(anOrder.Id, CPQXL_AsyncQueueable.SBQQ_CONTRACTED_FIELD));
                    System.debug('OrderTriggerHandler.contractOrder() jobId: ' + jobId);
                } else {
                    System.debug('OrderTriggerHandler.contractOrder() simple anOrder anOrder.Id: ' + anOrder.Id);
                    // smaller orders follow the business as usual (synchronous) path:
                    anOrder.SBQQ__Contracted__c = true;
                }
            } else if (!anOrder.CPQXL_Contracted__c && ((Order) Trigger.oldMap.get(anOrder.Id)).CPQXL_Contracted__c) {
                anOrder.SBQQ__Contracted__c = false;
            }
        }
    }
}