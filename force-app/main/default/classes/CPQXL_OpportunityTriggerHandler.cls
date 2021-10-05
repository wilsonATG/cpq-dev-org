/**
 * @Title: CPQXL_OpportunityTriggerHandler
 * @description: Created to push the checking of the SBQQ__Ordered__c checkbox to an 'Async via Queueable' context.
 *   Note: this gets us a boost from 10 Apex CPU seconds to 60 Apex CPU seconds, as well as doubles the heap size.
 *
 * Created by : Kevin Antonioli : 03.11.2020
 */
public without sharing class CPQXL_OpportunityTriggerHandler extends CPQU_TriggerHandler {
    public CPQXL_OpportunityTriggerHandler() {
        super('CPQXL_OpportunityTriggerHandler');
    }

    /**
      * @description beforeUpdate trigger context override from TriggerHandler
      *
      * @param null
      * @return void
      */
    protected override void beforeUpdate() {
        updateFields((List<Opportunity>) Trigger.new, (Map<Id, Opportunity>) Trigger.oldMap);
    }
    /**
     * @description: method to update opportunity fields.
     *
     * @param List<Opportunity> opportunities: Trigger.New
     * @param Map<Id, Opportunity> oldMap: Trigger.oldMap
     * @return void
     */
    private void updateFields(List<Opportunity> opportunities, Map<Id, Opportunity> oldMap) {
        for(Opportunity opportunity : opportunities) {
            Opportunity oldOpp = oldMap.get(opportunity.Id);
            // if the CPQXL_Ordered__c checkbox was just checked:
            if(opportunity.CPQXL_Ordered__c && !oldOpp.CPQXL_Ordered__c) {
                if(utilitySettings.containsKey(CPQXL_Constants.UTILITY_SETTING_VERY_LARGE_ORDER_THRESHOLD) &&
                    opportunity.CPQXL_QuoteLineItemCount__c > utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_VERY_LARGE_ORDER_THRESHOLD).NumberValue__c) {
                    // push the checking of the SBQQ__Ordered__c checkbox to an Apex Queueable to get a boost in governor limits:
                    CPQXL_QuoteCloneXLInitializer cloneXLInitializer = new CPQXL_QuoteCloneXLInitializer(opportunity.SBQQ__PrimaryQuote__c, null, CPQXL_Constants.LARGE_ORDER_SCENARIO);
                    System.debug('CPQXL_OpportunityTriggerHandler.updateFields() jobId: very large process triggered');
                } else
                if(utilitySettings.containsKey(CPQXL_Constants.UTILITY_SETTING_LARGE_ORDER_THRESHOLD) &&
                    // if it is a large opportunity as determined by the custom setting:
                    opportunity.CPQXL_QuoteLineItemCount__c > utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_LARGE_ORDER_THRESHOLD).NumberValue__c) {
                    // push the checking of the SBQQ__Ordered__c checkbox to an Apex Queueable to get a boost in governor limits:
                    Id jobId = System.enqueueJob(new CPQXL_AsyncQueueable(opportunity.Id, CPQXL_AsyncQueueable.SBQQ_ORDERED_FIELD));
                } else {
                    // opportunities with smaller quotes follow the business as usual (synchronous) path:
                    opportunity.SBQQ__Ordered__c = true;
                }
            } else  if(!opportunity.CPQXL_Ordered__c && ((Opportunity) Trigger.oldMap.get(opportunity.Id)).CPQXL_Ordered__c) {
                opportunity.SBQQ__Ordered__c = false;
            }
        }
    }
 }