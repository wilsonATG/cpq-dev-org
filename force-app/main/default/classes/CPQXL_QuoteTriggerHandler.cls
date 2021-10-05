/**
 * @Title: CPQXL_QuoteTriggerHandler
 * @description: Created to push the checking of the SBQQ__Ordered__c checkbox to an 'Async via Queueable' context.
 *   Note: this gets us a boost from 10 Apex CPU seconds to 60 Apex CPU seconds, as well as doubles the heap size.
 *
 * Created by : Kevin Antonioli : 03.11.2020
 */
public without sharing class CPQXL_QuoteTriggerHandler extends CPQU_TriggerHandler {

    public CPQXL_QuoteTriggerHandler() {
        super('CPQXL_QuoteTriggerHandler');
    }

    /**
      * @description beforeUpdate trigger context override from TriggerHandler
      *
      */
    protected override void beforeUpdate() {
        updateFields((List<SBQQ__Quote__c>) Trigger.new, (Map<Id, SBQQ__Quote__c>) Trigger.oldMap);
    }

    /**
     * @description: method to update quote fields.
     *
     * @param quotes List<SBQQ__Quote__c>: Trigger.New
     * @param oldMap Map<Id, SBQQ__Quote__c>: Trigger.oldMap
     */
    private void updateFields(List<SBQQ__Quote__c> quotes, Map<Id, SBQQ__Quote__c> oldMap) {
        for(SBQQ__Quote__c quote : quotes) {
            SBQQ__Quote__c oldQuote = oldMap.get(quote.Id);
            // if the CPQXL_Ordered__c checkbox was just checked:
            if(quote.CPQXL_Ordered__c && !oldQuote.CPQXL_Ordered__c) {
                // if it is a large quote as determined by the custom setting:
                if(utilitySettings.containsKey(CPQXL_Constants.UTILITY_SETTING_VERY_LARGE_ORDER_THRESHOLD) &&
                    quote.SBQQ__LineItemCount__c > utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_VERY_LARGE_ORDER_THRESHOLD).NumberValue__c) {
                    // push the checking of the SBQQ__Ordered__c checkbox to an Apex Queueable to get a boost in governor limits:
                    CPQXL_QuoteCloneXLInitializer cloneXLInitializer = new CPQXL_QuoteCloneXLInitializer(quote.Id, null, CPQXL_Constants.LARGE_ORDER_SCENARIO);
                    System.debug('QuoteTriggerHandler.orderQuote() jobId: Very large process triggered');
                } else if(utilitySettings.containsKey(CPQXL_Constants.UTILITY_SETTING_LARGE_ORDER_THRESHOLD) &&
                    quote.SBQQ__LineItemCount__c > utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_LARGE_ORDER_THRESHOLD).NumberValue__c) {
                    // push the checking of the SBQQ__Ordered__c checkbox to an Apex Queueable to get a boost in governor limits:
                    Id jobId = System.enqueueJob(new CPQXL_AsyncQueueable(quote.Id, CPQXL_AsyncQueueable.SBQQ_ORDERED_FIELD));
                } else {
                    // smaller quotes follow the business as usual (synchronous) path:
                    quote.SBQQ__Ordered__c = true;
                }
            } else  if(!quote.CPQXL_Ordered__c && ((SBQQ__Quote__c) Trigger.oldMap.get(quote.Id)).CPQXL_Ordered__c) {
                quote.SBQQ__Ordered__c = false;
            }
        }
    }
 }