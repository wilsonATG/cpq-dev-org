/**
 * @Title: CPQXL_QuoteCloneXLController
 * @description: Created for CPQ governor limit workarounds to be leveraged on large quotes
 *
 * Created by : Kevin Antonioli : 03.11.2020
 */
public without sharing class CPQXL_QuoteCloneXLController {
    private static final String CPQ_LINE_SOURCE_NAME = 'CPQ Line';
    private static final String CPQ_QUOTE_API_NAME = 'SBQQ__Quote__c';
    private static final String CPQ_QUOTELINE_API_NAME = 'SBQQ__QuoteLine__c';
    private static final String CPQ_ORDERITEM_API_NAME = 'OrderItem';
    private static final String CPQ_ASSET_API_NAME = 'Asset';
    private static final String CPQ_SUBSCRIPTION_API_NAME = 'SBQQ__Subscription__c';
    private static final Map<String, CPQU_UtilitySetting__mdt> utilitySettings = new Map<String, CPQU_UtilitySetting__mdt>();

    // static initialization
    static {
        utilitySettings.putAll(CPQU_ApexUtils.groupSettingsByDeveloperName(
        [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
        FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]));
    }


    //##############################################//
    //################# CloneXL #################//
    //##############################################//

    /**
     * @Description -> method to parse the CPQXL settings relevant to CloneXL
     * @return CPQXL_Settings__c: the CPQXL settings read in from the custom setting
     */
    @AuraEnabled(Cacheable=true)
    public static Map<String, CPQU_UtilitySetting__mdt> cpqxlSettings() {
        System.debug('CPQXL_QuoteCloneXLController.getCpqxlSettings()');
        return utilitySettings;
    }

    /**
     * @Description -> method to clone records that are listed in the customList table
     * @param String recordIdParam -> the source parent record (Ex: Quote, Order, Contract, etc.)
     * @param String configValues -> configs defined on the component
     * @return void
     */
    @AuraEnabled
    public static AsyncProcessProperties cloneRecords(String recordIdParam, List<String> bundlesToExcludeParam) {
        System.debug('CPQXL_QuoteCloneXLController.cloneRecords() recordIdParam: ' + recordIdParam);
        AsyncProcessProperties appProperties = new AsyncProcessProperties();
        try {
            CPQXL_QuoteCloneXLInitializer cloneXLInitializer = new CPQXL_QuoteCloneXLInitializer(recordIdParam, bundlesToExcludeParam);
            appProperties.sourceRecordId = recordIdParam;
            appProperties.targetRecordId = cloneXLInitializer.targetQuoteId;
            appProperties.targetQuote = [SELECT Id, Name FROM SBQQ__Quote__c WHERE Id = :appProperties.targetRecordId];
        } catch(Exception e) {
            String exceptionMessage = 'CPQXL_QuoteCloneXLController.cloneRecords() exception: ' + e.getMessage() + ' Stack trace: ' + e.getStackTraceString();
            System.debug(exceptionMessage);
            throw new AuraHandledException(exceptionMessage);
        }
        return appProperties;
    }

    /**
     * @description: data structure to track the properties of a CPQ Enterprise-related process
     */
    public class AsyncProcessProperties {
        @AuraEnabled public Id sourceRecordId;
        @AuraEnabled public Id targetRecordId;
        @AuraEnabled public Integer percentComplete;
        @AuraEnabled public String status;
        @AuraEnabled public SObject record;
        @AuraEnabled public SBQQ__Quote__c targetQuote;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Boolean errorEncountered = false;
    }
    
    /**
     * @Description -> method to get the status of a clone process
     * @param sourceRecordId (Id): Id of the record getting cloned
     * @param targetRecordId (Id): Id of the clone getting created
     * @param bundlesToExcludeParam List<String> 
     * @param AsyncProcessProperties (apPropertiesParam): data structure to track the properties of a CPQ Enterprise-related process
     * @return (Integer): percentage complete of the clone
     */
    @AuraEnabled
    public static AsyncProcessProperties getCloneStatus(
        Id sourceRecordId, Id targetRecordId, List<String> bundlesToExcludeParam, AsyncProcessProperties apPropertiesParam
    ) {
        System.debug('CPQXL_QuoteCloneXLController.getCloneStatus() targetRecordId: ' + targetRecordId);
        apPropertiesParam.sourceRecordId = sourceRecordId;
        apPropertiesParam.targetRecordId = targetRecordId;
        if(!apPropertiesParam.errorEncountered) {
            String combinedId = sourceRecordId + '::' + CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO;
            List<SBQQ__RecordJob__c> quoteCloneJobs = [
                SELECT Id, SBQQ__RecordId__c, SBQQ__JobId__c, SBQQ__JobStatus__c, SBQQ__JobDetails__c FROM SBQQ__RecordJob__c
                WHERE SBQQ__RecordId__c = :combinedId
                LIMIT 1
            ];
            if(!quoteCloneJobs.isEmpty()) {
                // capture any failed clone jobs so that we can present the error message to the user:
                if(quoteCloneJobs[0].SBQQ__JobStatus__c == CPQXL_Constants.JOB_FAILED_STATUS) {
                    apPropertiesParam.errorMessage = quoteCloneJobs[0].SBQQ__JobDetails__c;
                    apPropertiesParam.errorEncountered = true;
                } else {
                    apPropertiesParam = getCloneProgressPercentage(sourceRecordId, targetRecordId, bundlesToExcludeParam, apPropertiesParam);
                }
            } else {
                apPropertiesParam = getCloneProgressPercentage(sourceRecordId, targetRecordId, bundlesToExcludeParam, apPropertiesParam);
            }
        }

        return apPropertiesParam;
    }

     /**
     * @Description -> TODO: fill out description
     * @param sourceRecordId (Id): Id of the record getting cloned
     * @param targetRecordId (Id): Id of the clone getting created
     * @param bundlesToExcludeParam List<String> 
     * @param AsyncProcessProperties (apPropertiesParam): data structure to track the properties of a CPQ Enterprise-related process
     * @return AsyncProcessProperties: the properties of the cloning process, including the up-to-date percentage complete
     */
    private static AsyncProcessProperties getCloneProgressPercentage(
        Id sourceRecordId, Id targetRecordId, List<String> bundlesToExcludeParam, AsyncProcessProperties apPropertiesParam
    ) {
        List<SBQQ__QuoteLine__c> applicableSourceBundles = [
            SELECT Id FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c = :sourceRecordId AND SBQQ__RequiredBy__c = null AND Id NOT IN :bundlesToExcludeParam
        ];
        List<SBQQ__QuoteLine__c> applicableBundlesOnTarget = [
            SELECT Id FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c = :targetRecordId AND SBQQ__RequiredBy__c = null
        ];

        apPropertiesParam.percentComplete = Integer.valueOf(Decimal.valueOf(applicableBundlesOnTarget.size()) 
            / Decimal.valueOf(applicableSourceBundles.size()) * 100);

        return apPropertiesParam;
    }
}