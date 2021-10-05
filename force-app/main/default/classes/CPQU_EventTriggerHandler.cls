/** Description:
* EvebtTriggerHandler Generic extendable handler for events.
*
* Create by: Steve Lohrenz : 21.02.18
* Revisions: /
* Date : Name : Notes
*
* 04.25.18 : Ed Harrold : update logging
* 05.01.18 :              update update to db insert
* 09.24.19 : Kevin Antonioli : capture getStackTraceString in CPQU_EventDetails__c
*
* Note: specific code comments related to non-trivial logic, method usage, and revisions will be
*  included in the appropriate area of the code below
*  Note: always implement all trigger actions in the trigger class. they will be handled in the handler class
*/
public virtual class CPQU_EventTriggerHandler extends CPQU_TriggerHandler {
    protected Integer delayInMilliseconds = 3000;
    protected Integer MAX_NUMBER_RETRIES = 8;
    public Boolean logSuccessEvents = false;
    public static Integer testNumberRetries = 8;

    public CPQU_EventTriggerHandler() {
        super();
    }

    public CPQU_EventTriggerHandler(String handlerName) {
        super(handlerName);
    }

    protected virtual void afterEventInsert(List<SObject> events) {
    }

    protected override void afterInsert() {
        handleEventInsert(Trigger.new);
    }

    @TestVisible
    protected void handleEventInsert(List<SObject> listEvents) {
        List<CPQU_EventMonitorLog__c> eventLogs = new List<CPQU_EventMonitorLog__c>();

        if(Test.isRunningTest()) {
            MAX_NUMBER_RETRIES = testNumberRetries;
        }

        System.debug('CPQU_EventTriggerHandler.handleEventInsert() retries: ' + EventBus.TriggerContext.currentContext().retries + ' numberRetries: ' + MAX_NUMBER_RETRIES);
        if (EventBus.TriggerContext.currentContext().retries < MAX_NUMBER_RETRIES) {
            Boolean completedAfterEventInsert = false;
            try {
                afterEventInsert(listEvents);
                if(logSuccessEvents) {
                    CPQU_ErrorLogUtils.createErrorLog(JSON.serialize(listEvents).left(32000), 'Handling Platform Event Success', this.getHandlerName(), (String) listEvents.get(0).get('ReplayId'));
                }
            } catch(EventBus.RetryableException eek) {
                // We need this to be thrown so the retry actually happens. All other exceptions are caught below.
                CPQU_ErrorLogUtils.createErrorLog(eek, 'Handling Platform Event Retry', this.getHandlerName(), (String) listEvents.get(0).get('ReplayId'));
                throw eek;
            } catch (Exception ex) {
                CPQU_ErrorLogUtils.createErrorLog(ex, 'Handling Platform Event Processing', this.getHandlerName(), (String) listEvents.get(0).get('ReplayId'));
            }
        } else {
            CPQU_ErrorLogUtils.createErrorLog(JSON.serialize(listEvents), 'Handling Platform Event Too Many Retries have occurred', this.getHandlerName(), (String) listEvents.get(0).get('ReplayId'));
        }
    }
}