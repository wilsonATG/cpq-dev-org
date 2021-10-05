public without sharing class CPQU_ErrorLogUtils {
    public CPQU_ErrorLogUtils() {

    }

    /**
    * @description -> method to create error log, given certain params
    * @param Exeception e -> the exception that was caught
    * @param String context -> the context under which the error occurred
    * @param String errorSource -> the source (usually an apex class name) of the error
    * @param String referenceId -> the record that the error occurred for
    * @return void
    **/
    public static void createErrorLog(Exception e, String context, String errorSource, String referenceId) {
        System.debug('CPQU_ErrorLogUtils.createErrorLog() + ' + context + ' referenceId: ' + referenceId);
        CPQU_ErrorLogEvent__e errorLog = new CPQU_ErrorLogEvent__e(
                CPQU_Context__c = context == null ? null : context.left(150),
                CPQU_ErrorMessage__c = e == null ? null : e.getMessage() + ' , stack trace: ' + e.getStackTraceString(),
                CPQU_ErrorSource__c = errorSource == null ? null : errorSource.left(50),
                CPQU_LineNumber__c = e == null ? null : e.getLineNumber(),
                CPQU_Message__c = e == null ? null : e.getMessage().left(255),
                CPQU_ReferenceId__c = referenceId,
                CPQU_Type__c = e == null ? null : e.getTypeName().left(50),
                CPQU_UserId__c = UserInfo.getUserId()
        );

        EventBus.publish(errorLog);
    }

    public static void createErrorLog(String eventData, String context, String errorSource, String referenceId) {
        System.debug('CPQU_ErrorLogUtils.createErrorLog() + ' + context + ' referenceId: ' + referenceId);
        CPQU_ErrorLogEvent__e errorLog = new CPQU_ErrorLogEvent__e(
                CPQU_Context__c = context == null ? null : context.left(150),
                CPQU_ErrorMessage__c = eventData == null ? null : eventData,
                CPQU_ErrorSource__c = errorSource == null ? null : errorSource.left(50),
                CPQU_ReferenceId__c = referenceId,
                CPQU_UserId__c = UserInfo.getUserId()
        );

        EventBus.publish(errorLog);
    }

    /**
    * @description -> method to create error log, given certain params
    * @param Exeception e -> the exception that was caught
    * @param String context -> the context under which the error occurred
    * @param String errorSource -> the source (usually an apex class name) of the error
    * @param String referenceId -> the record that the error occurred for
    * @return void
    **/
    public static void createErrorLog(String context, String errorSource, List<Database.Error> saveResults, String referenceId) {
        System.debug('CPQU_ErrorLogUtils.createErrorLog() + ' + context + ' saveResults.size(): ' + saveResults.size());
        CPQU_ErrorLogEvent__e errorLog = new CPQU_ErrorLogEvent__e(
                CPQU_Context__c = context == null ? null : context.left(150),
                CPQU_ErrorMessage__c = String.join(saveResults, '; '),
                CPQU_ErrorSource__c = errorSource == null ? null : errorSource.left(50),
                CPQU_ReferenceId__c = referenceId,
                CPQU_Type__c = 'Save Results',
                CPQU_UserId__c = UserInfo.getUserId()
        );

        EventBus.publish(errorLog);
    }

    /**
    * @description -> remove in-flight indicators from error logs, to make them no longer in-flight.
    * @param Set<Id> referenceIds -> ids of records that generated the error log records
    * @param Set<String> errorSources -> sources (apex class names) that caused the error logs
    * @return void
    **/
    public static void processErrorLogs(Set<Id> referenceIds, Set<String> errorSources) {
        List<CPQU_ErrorLog__c> errorLogs = [
            SELECT Id, CPQU_ErrorMessage__c, CPQU_ErrorSource__c FROM CPQU_ErrorLog__c
            WHERE CPQU_ReferenceID__c IN :referenceIds AND CPQU_ErrorSource__c IN :errorSources
            ORDER BY CreatedDate DESC
        ];

        if(!errorLogs.isEmpty()) {
            for(CPQU_ErrorLog__c errorLog : errorLogs) {
                errorLog.CPQU_ErrorSource__c = errorLog.CPQU_ErrorSource__c.remove(CPQU_Constants.ERROR_INFLIGHT_INDICATOR);
            }
            update errorLogs;
        }
    }

    public static void createErrorLogs(List<CPQU_ErrorLogEvent__e> events) {
        System.debug('CPQU_ErrorLogEventTriggerHandler.createErrorLogs() events.size(): ' + events.size());
        List<CPQU_ErrorLog__c> errorLogs = new List<CPQU_ErrorLog__c>();
        for(CPQU_ErrorLogEvent__e errorLogEvent: events) {
            CPQU_ErrorLog__c errorLog = new CPQU_ErrorLog__c(
                    CPQU_Context__c = errorLogEvent.CPQU_Context__c,
                    CPQU_ErrorMessage__c = errorLogEvent.CPQU_ErrorMessage__c,
                    CPQU_ErrorSource__c = errorLogEvent.CPQU_ErrorSource__c,
                    CPQU_LineNumber__c = errorLogEvent.CPQU_LineNumber__c,
                    CPQU_Message__c = errorLogEvent.CPQU_Message__c,
                    CPQU_ReferenceID__c = errorLogEvent.CPQU_ReferenceId__c,
                    CPQU_Type__c = errorLogEvent.CPQU_Type__c,
                    CPQU_User__c = errorLogEvent.CPQU_UserId__c
            );
            errorLogs.add(errorLog);
        }

        System.debug('CPQU_ErrorLogEventTriggerHandler.createErrorLogs() errorLogs.size(): ' + errorLogs.size());
        if(!errorLogs.isEmpty()) {
            insert errorLogs;
        }
    }

    public class CPQU_Exception extends Exception {}

    @InvocableMethod(Label='Invoke ExceptionUtil')
    public static void throwCustomException(List<String> exceptionMessage) {
        throw new CPQU_Exception('An internal exception happened during current operation.' +
                'Please contact system administrator with these exception details:' + exceptionMessage[0]);

    }
}