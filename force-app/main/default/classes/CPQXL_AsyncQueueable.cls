/**
 * 
 * CPQXL_AsyncQueueable class
 *
 * Versioning: 
 *   2/16/21 : Steve Lohrenz : File Created
 */

public with sharing class CPQXL_AsyncQueueable implements Queueable {
// the id of the quote in which to order:
    private Id recordId;
    private String combinedId;
    private String fieldToCheck;

    private static final String CLASS_NAME = 'CPQXL_AsyncQueueable';
    private static final String JOB_FAILED_STATUS = 'Failed';
    private static final String JOB_COMPLETED_STATUS = 'Completed';

    public static final String SBQQ_CONTRACTED_FIELD = 'SBQQ__Contracted__c';
    public static final String SBQQ_ORDERED_FIELD = 'SBQQ__Ordered__c';
    public static final String SBQQ_INVOICE_FIELD = 'blng__BillNow__c';

    // Constructor:
    public CPQXL_AsyncQueueable(Id recordId, String fieldToCheck) {
        this.recordId = recordId;
        this.combinedId = recordId + '::' + 'CPQXL_AsyncQueueable:' + fieldToCheck;
        this.fieldToCheck = fieldToCheck;
    }

    /**
     * @description: method to check the OOB Processing field on various objects.
     *
     * @param QueueableContext context
     * @return void
     */
    public void execute(QueueableContext context) {
        String METHOD_NAME = CLASS_NAME + '.execute() ';
        try {
            System.debug(METHOD_NAME + ' recordId: ' + recordId);
            SObject recordToUpdate = recordId.getSObjectType().newSObject(recordId);
            recordToUpdate.Id = recordId;
            recordToUpdate.put(fieldToCheck, true);
            System.debug(METHOD_NAME + ' recordToUpdate.Id: ' + recordToUpdate.Id);
            update recordToUpdate;
        } catch(Exception ex) {
            System.debug(METHOD_NAME + ' Error occurred with recordId: ' + recordId);
            System.debug(METHOD_NAME + ' ex.getStackTraceString(): ' + ex.getStackTraceString());
            System.debug(METHOD_NAME + ' ex.getMessage(): ' + ex.getMessage());
            CPQU_ErrorLogUtils.createErrorLog(ex, METHOD_NAME + ' Attempting Async Execute ' + recordId.getSObjectType(), CPQU_Constants.APPLICATION_CPQ, recordId);
        } 
    }
}