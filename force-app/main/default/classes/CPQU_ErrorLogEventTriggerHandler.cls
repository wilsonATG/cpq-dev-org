/**
 * 
 * CPQU_ErrorLogTriggerHandler class
 *
 * Versioning:
 *   7/8/21 : Steve Lohrenz : File Created
 */

public with sharing class CPQU_ErrorLogEventTriggerHandler extends CPQU_EventTriggerHandler {

    public CPQU_ErrorLogEventTriggerHandler() {
        super('CPQU_ErrorLogEventTriggerHandler');
    }

    protected override void afterEventInsert(List<SObject> events) {
        CPQU_ErrorLogUtils.createErrorLogs((List<CPQU_ErrorLogEvent__e>) events);
    }
}