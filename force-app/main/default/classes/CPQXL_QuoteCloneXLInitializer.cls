/**
 * @Title: CPQXL_QuoteCloneXLInitializer
 * @description =>  Created for CPQ governor limit workarounds to be leveraged on large quotes
 *
 * Created by : Kevin Antonioli : 03.11.2020
 */
public without sharing class CPQXL_QuoteCloneXLInitializer {
    private static final Map<String, CPQU_UtilitySetting__mdt> utilitySettings = new Map<String, CPQU_UtilitySetting__mdt>();

    // static initialization
    static {
        utilitySettings.putAll(CPQU_ApexUtils.groupSettingsByDeveloperName(
        [SELECT DeveloperName, Label, BooleanValue__c, TextValue__c, NumberValue__c, ValueType__c, IsActive__c
        FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]));
    }

    public Id targetQuoteId;
    public Integer numOfSourceBundlesToClone;
    public String scenarioType = CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO;

    // constructor:
    public CPQXL_QuoteCloneXLInitializer(Id sourceQuoteId, List<String> bundlesToExcludeParam) {
        cloneQuote(sourceQuoteId, bundlesToExcludeParam);
    }

    public CPQXL_QuoteCloneXLInitializer(Id sourceQuoteId, List<String> bundlesToExcludeParam, String scenarioType) {
        this.scenarioType = scenarioType;
        cloneQuote(sourceQuoteId, bundlesToExcludeParam);
    }

    /**
     * @description Method called by the Clone button on the custom Clone with Related page (the page that looks like SF OOB CWR). 
     * @param sourceQuoteId (SBQQ__Quote__c): the source quote that is getting cloned
     * @param bundlesToExcludeParam List<String>: any bundles that the user deselected in the UI
     */   
    public void cloneQuote(Id sourceQuoteId, List<String> bundlesToExcludeParam) {
        System.debug('CPQXL_QuoteCloneXLInitializer.cloneQuote() sourceQuoteId: ' + sourceQuoteId);
        SBQQ__Quote__c sourceQuote = [
            SELECT Id, SBQQ__LineItemCount__c, SBQQ__Opportunity2__c FROM SBQQ__Quote__c WHERE Id = :sourceQuoteId
        ];

        if(sourceQuote.SBQQ__LineItemCount__c <= utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_LINE_THRESHOLD).NumberValue__c) {
            targetQuoteId = handleCloningSmallQuote(sourceQuoteId, bundlesToExcludeParam);
            //return (new PageReference('/' + targetQuoteId)); 
        } else {
            handleLargeQuote(sourceQuote, bundlesToExcludeParam);
        }
    }

    /**
     * @description Method called by the Clone button on the CloneXL page.
     * @param sourceQuoteId (Id): the Id of the quote that is getting cloned.
     * @param bundlesToExcludeParam (List<String>): bundles that the user does not wish to get cloned to the target quote 
     * @return void
     */   
    public Id handleCloningSmallQuote(Id sourceQuoteId, List<String> bundlesToExcludeParam) {
        System.debug('CPQXL_QuoteCloneXLInitializer.handleCloningSmallQuote() sourceQuoteId: ' + sourceQuoteId);
        // create the target quote header (no line items yet):
        SBQQ__Quote__c targetQuote = createTargetQuote(sourceQuoteId, true);
        System.debug('CPQXL_QuoteCloneXLInitializer.handleCloningSmallQuote() 1 targetQuote: ' + targetQuote);

        String queryTopBundlesString = 'SELECT Id ' +
                ' FROM SBQQ__QuoteLine__c ' +
                '            WHERE SBQQ__RequiredBy__c = NULL AND SBQQ__Quote__c = :sourceQuoteId ' +
                (bundlesToExcludeParam != null ? ' AND Id NOT IN :bundlesToExcludeParam' : '');

        Map<Id, SBQQ__QuoteLine__c> bundlesToClone = new Map<Id, SBQQ__QuoteLine__c>((List<SBQQ__QuoteLine__c>) Database.query(queryTopBundlesString));
        /*Map<Id, SBQQ__QuoteLine__c> bundlesToClone = new Map<Id, SBQQ__QuoteLine__c>([
            SELECT Id FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__RequiredBy__c = NULL AND SBQQ__Quote__c = :sourceQuoteId AND Id NOT IN :bundlesToExcludeParam
        ]);*/
        System.debug('CPQXL_QuoteCloneXLInitializer.handleCloningSmallQuote() 2 targetQuote.Id: ' + targetQuote.Id);
        targetQuoteId = targetQuote.Id;

        // create all line items for the target in a single thread:
        CPQU_BundleStructureUtils.cloneBundles(sourceQuoteId, targetQuote.Id, null, bundlesToClone.keySet());
        System.debug('CPQXL_QuoteCloneXLInitializer.handleCloningSmallQuote() 3 targetQuote.Id: ' + targetQuote.Id);
        return targetQuote.Id;
    }
    /**
     * @description -> TODO: fill out method description and param descriptions
     * @param sourceQuote (SBQQ__Quote__c): the source quote that is getting cloned
     * @param bundlesToExcludeParam List<String>: any bundles that the user deselected in the UI
     */
    public void handleLargeQuote(SBQQ__Quote__c sourceQuote, List<String> bundlesToExcludeParam) {
        System.debug('CPQXL_QuoteCloneXLInitializer.handleLargeQuote() sourceQuote: ' + sourceQuote);
        initializeRecordJob(sourceQuote.Id);

        Set<String> bundlesToExclude = utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_ALLOW_PARTIAL_CLONING_ON_CLONE).BooleanValue__c ? new Set<String>(bundlesToExcludeParam) : new Set<String>();
        Id sourceQuoteId = sourceQuote.Id;
        Integer customAggrSize = Integer.valueOf(utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE).NumberValue__c);
        // construct the bundleAggregationsMap to only include the bundles the user wants:
        Map<Integer, Set<Id>> bundleAggregationsMap = CPQU_BundleStructureUtils.getBundleAggregations(
            sourceQuoteId, Integer.valueOf(customAggrSize), bundlesToExclude
        );
        numOfSourceBundlesToClone = getNumOfSourceBundlesToClone(bundleAggregationsMap, bundlesToExclude);

        SBQQ__Quote__c targetQuote;
        Set<Id> targetQuoteIds = new Set<Id>();
        // Added for B-13097:
        Set<Id> remainingSubSetQuoteIds = new Set<Id>();
        if(scenarioType == CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO) {
            // create the target quote header (no line items yet):
            targetQuote = createTargetQuote(sourceQuoteId, true);
            targetQuoteId = targetQuote.Id;
        } else if(scenarioType.contains(CPQXL_Constants.LARGE_QUOTE_SPLIT_SCENARIO) || scenarioType.contains(CPQXL_Constants.LARGE_ORDER_SCENARIO)) {
            List<SBQQ__Quote__c> subSetQuotes = (List<SBQQ__Quote__c>) CPQU_BundleStructureUtils.cloneXObjectHeader(sourceQuoteId, null, bundleAggregationsMap.size(), false);
            for(SBQQ__Quote__c subsetQuote : subSetQuotes) {
                subsetQuote.CPQXL_IsSubset__c = true;
            }

            if(!subSetQuotes.isEmpty()) {
                insert subSetQuotes;
                remainingSubSetQuoteIds = (new Map<Id,SBQQ__Quote__c>(subSetQuotes)).keySet();
                // this is the first target quote Id for the split scenario:
                targetQuoteId = (new List<Id>(remainingSubSetQuoteIds))[0];
                System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLInitializer.handleLargeQuote remainingSubSetQuoteIds: ' + remainingSubSetQuoteIds);
            }
        }

        targetQuoteIds = new Set<Id>{targetQuoteId};
        targetQuoteIds.addAll(remainingSubSetQuoteIds);

        // build map of aggregation number to ALL quote lines applicable to that aggregation:
        Map<Integer, Set<Id>> bundleAggregationsMapExtended =  CPQU_BundleStructureUtils.getBundleAggregationsExtended(
            sourceQuoteId, Integer.valueOf(customAggrSize), bundlesToExclude, true
        );
        Set<Id> quoteLineIdsToProcessInPlatformEvent = bundleAggregationsMapExtended.get(1);
        CPQXL_CloneLargeQuoteEvent__e cloneLargeQuoteEvent = initializeQuoteClonePlatformEvent(
            bundleAggregationsMap, bundleAggregationsMapExtended, remainingSubSetQuoteIds, scenarioType, sourceQuote, numOfSourceBundlesToClone, targetQuoteId
        );

        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLInitializer.handleLargeQuote() bundlesToExclude: ' + bundlesToExclude);
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLInitializer.handleLargeQuote() quoteLineIdsToProcessInPlatformEvent: ' + quoteLineIdsToProcessInPlatformEvent);

        CPQU_ApexUtils.consolidateTriggerHandlerNames(new Set<String>{
            utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_QUOTE_TRIGGER_HANDLERS).TextValue__c, utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_OPPORTUNITY_TRIGGER_HANDLERS).TextValue__c
        }); 

        // kick off the platform event that will clone the quote lines from the first bundle aggregation:
        EventBus.publish(cloneLargeQuoteEvent);
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLInitializer.handleLargeQuote() cloneLargeQuoteEvents: ' + cloneLargeQuoteEvent);
    }

    /**
     * @description: method to initialize a SBQQ__RecordJob__c record to track status of a large quote clone/split
     * @param quoteIdParam (Id): the Id of the quote in which to clone or split, depending on scenario type
     */  
    private void initializeRecordJob(Id quoteIdParam) {
        String combinedId = quoteIdParam + '::' + scenarioType;
        List<SBQQ__RecordJob__c> quoteCloneOrSplitJobs = [
            SELECT Id, SBQQ__RecordId__c, SBQQ__JobId__c, SBQQ__JobStatus__c FROM SBQQ__RecordJob__c
            WHERE SBQQ__RecordId__c = :combinedId
            LIMIT 1
        ];

        // create (or update existing) record job so that we can track the status 
        if(quoteCloneOrSplitJobs.isEmpty()) {
            // create the record job if it doesn't exist:
            insert new SBQQ__RecordJob__c(SBQQ__RecordId__c = combinedId, SBQQ__JobStatus__c = 'Queued', CPQXL_PercentComplete__c = 0);
        } else {
            // update the record job if it already exists:
            quoteCloneOrSplitJobs[0].CPQXL_PercentComplete__c = 0;
            quoteCloneOrSplitJobs[0].SBQQ__JobStatus__c = 'Queued';
            quoteCloneOrSplitJobs[0].SBQQ__JobDetails__c = null;
            update quoteCloneOrSplitJobs;
        }
    }

    /**
     * @description Method to get the number of relevant bundles to clone. This will vary depending on what bundles the user may have chosen
     *  to omit.
     * @param bundleAggregationsMap Map<Integer>, Set<Id>>
     * @param bundlesToExclude Set<Id>>
     *
     * @return Integer
     */
    private Integer getNumOfSourceBundlesToClone(Map<Integer, Set<Id>> bundleAggregationsMap, Set<String> bundlesToExclude) {
        System.debug('CPQXL_QuoteCloneXLInitializer.getNumOfSourceBundlesToClone() bundleAggregationsMap: ' + bundleAggregationsMap);
        numOfSourceBundlesToClone = 0;
        for(Integer bundleAggrNum : bundleAggregationsMap.keySet()) {
            for(Id bundleId : bundleAggregationsMap.get(bundleAggrNum)) {
                // only increment the number of bundles if the bundle is not to be 
                // excluded from the clone:
                if(!bundlesToExclude.contains(bundleId)) {
                    numOfSourceBundlesToClone += 1;
                }
            }
        }

        return numOfSourceBundlesToClone;
    }

    /**
     * @description -> method to create the target quote (with no line items yet, just the header).
     * @param sourceQuoteId Id of source quote
     * @param doInsert Boolean
     * @return SBQQ__Quote__c -> the target quote with no line items
     */  
    private SBQQ__Quote__c createTargetQuote(Id sourceQuoteId, Boolean doInsert) {
        return ((SBQQ__Quote__c) CPQU_BundleStructureUtils.cloneXObjectHeader(sourceQuoteId, false /* setCloneAsPrimary */, doInsert /*doInsert*/));
    }

    /**
     * @description Method to initialize the first event in the Clone Large Quote platform event chain.
     * @param bundleAggregationsMap Map<Integer, Set<Id>>  -> a map of bundle aggregation number to bundle line ids within an aggregation
     * @param bundleAggregationsMapExtended Map<Integer, Set<Id>> -> a map of bundle aggregation number to all quote line ids in the aggregation
     * @param remainingSubSetQuoteIds Set<Id> -> for quote split scenarios, the remaining subset (smaller) quotes we have yet to process
     * @param scenarioType String - which scenario is this (Large Order, Quote Clone, etc)
     * @param sourceQuote SBQQ__Quote__c - The quote of the source quote
     * @param numOfSourceBundlesToClone Integer - the number of source bundles we should clone with the next action
     * @param targetQuoteId Id - the target quote id
     * @return CPQXL_CloneLargeQuoteEvent__e cloneLargeQuoteEvent -> the first event in a Clone Large Quote platform event chain
     */
    private CPQXL_CloneLargeQuoteEvent__e initializeQuoteClonePlatformEvent(
        Map<Integer, Set<Id>> bundleAggregationsMap, Map<Integer, Set<Id>> bundleAggregationsMapExtended, Set<Id> remainingSubSetQuoteIds,
        String scenarioType, SBQQ__Quote__c sourceQuote, Integer numOfSourceBundlesToClone, Id targetQuoteId
    ) {
        System.debug('CPQXL_QuoteCloneXLInitializer.initializeQuoteClonePlatformEvent() targetQuoteId: ' + targetQuoteId);
        // initialize platform event record:
        return new CPQXL_CloneLargeQuoteEvent__e(
            CPQXL_ScenarioType__c = scenarioType,
            CPQXL_SourceQuoteId__c = sourceQuote.Id,
            CPQXL_OpportunityId__c = sourceQuote.SBQQ__Opportunity2__c,
            CPQXL_SourceQuoteNumberOfBundles__c = numOfSourceBundlesToClone,
            CPQXL_TargetQuoteId__c = targetQuoteId,
            CPQXL_BundleAggregationsJSON__c = JSON.serialize(bundleAggregationsMap),
            CPQXL_BundleAggregationsExtendedJSON__c = JSON.serialize(bundleAggregationsMapExtended),
            CPQXL_AggregationNumberToProcess__c = 1, // next aggregation number to process
            CPQXL_RemainingSubsetQuoteIds__c = JSON.serialize(remainingSubSetQuoteIds),
            //CPQXL_BundlesToExclude_JSON__c = ....
            CPQXL_AllSubsetQuoteIds__c = JSON.serialize(remainingSubSetQuoteIds) // static 
        );
    }
}
