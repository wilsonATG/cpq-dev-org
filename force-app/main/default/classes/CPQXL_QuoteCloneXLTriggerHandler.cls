/**
 * Created by Name / Date:  Kevin Antonioli on 06.05.2019
 *
 * Description:
 * CPQU_TriggerHandler on CPQXL_CloneLargeQuoteEvent__e event object.
 * CPQXL_QuoteCloneXLTriggerHandler can handle both cloning a large quote to another quote, AND splitting a large quote into smaller subset quotes.
 *
 * Revisions:
 * Date : Name : Notes
 * 8/7/2019 : Kevin Antonioli : add functionality for optionally splitting the quote instead of cloning it.
 * 
 * TODO: log errors in custom error log object, OR use the SBQQ__RecordJob__c object to track progress
 *
 * Note: specific code  comments related to non-trivial logic, method usage, and revisions will be
 *             included in the appropriate area of the code below
 *  Note: always implement all trigger actions in the trigger class. they will be handled in the handler class
**/
public without sharing class CPQXL_QuoteCloneXLTriggerHandler extends CPQU_EventTriggerHandler {
    public static Id sourceQuoteId;
    public static Id targetQuoteId;
    public static Id opportunityId;
    public static String scenarioType;
    public static Set<String> oppAndQuoteTriggerHandlersToToggle = CPQU_ApexUtils.consolidateTriggerHandlerNames(new Set<String>{
        CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_QUOTE_TRIGGER_HANDLERS).TextValue__c, CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_OPPORTUNITY_TRIGGER_HANDLERS).TextValue__c
    });
    public static final String EVENT_CLASS_NAME = 'CPQXL_QuoteCloneXLTriggerHandler'; 
    public static final String EVENT_CLASSNAME_IN_FLIGHT = 'CPQXL_QuoteCloneXLTriggerHandler' + CPQU_Constants.ERROR_INFLIGHT_INDICATOR;

    // Constructor Variation 1:    
    public CPQXL_QuoteCloneXLTriggerHandler() {

    }

    // Constructor Variation 2:
    public CPQXL_QuoteCloneXLTriggerHandler(Integer retries, Integer delay) {
        delayInMilliseconds = delay;
        numberRetries = retries;
    }

    protected override void afterEventInsert(List<SObject> events) {
        processEvents((List<CPQXL_CloneLargeQuoteEvent__e>) events);
    }

    /**
     * @description -> Method to clone a subset of quote lines from the source large quote, onto the target quote.
     * @param List<CPQXL_CloneLargeQuoteEvent__e> cloneLargeQuoteEvents -> a list of Large Quote Clone events. There will only ever be one per execution/thread.
     *   There could be multiple per large quote cloning process.
     * @return void
    **/
    public void processEvents(List<CPQXL_CloneLargeQuoteEvent__e> cloneLargeQuoteEvents) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLTriggerHandler.processEvents() cloneLargeQuoteEvents: ' + cloneLargeQuoteEvents);
        Savepoint sp = Database.setSavepoint();
        CPQXL_CloneLargeQuoteEvent__e currentClqEvent = cloneLargeQuoteEvents[0];

        // There will be only 1 applicable partner event at this point in the context of the execution. Grab the attributes from it.
        scenarioType = currentClqEvent.CPQXL_ScenarioType__c;
        sourceQuoteId = currentClqEvent.CPQXL_SourceQuoteId__c;
        targetQuoteId = currentClqEvent.CPQXL_TargetQuoteId__c;
        opportunityId = currentClqEvent.CPQXL_OpportunityId__c;

        // Initialize additional Clone Large Quote platform event in memory (do not publish yet, we'll do that later in the execution):
        CPQXL_CloneLargeQuoteEvent__e nextClqEvent = initializeNextClqEvent(currentClqEvent);
        SBQQ__RecordJob__c quoteCloneOrSplitJob;

        try{
            String extendedId = sourceQuoteId + '::' + scenarioType;
            quoteCloneOrSplitJob = [
                SELECT Id, SBQQ__JobStatus__c FROM SBQQ__RecordJob__c WHERE SBQQ__RecordId__c = :extendedId LIMIT 1
            ];

            CPQU_BundleStructureUtils.disableTriggers(true, oppAndQuoteTriggerHandlersToToggle); // watch out for this potentially causing issues
            update new SBQQ__Quote__c(Id = sourceQuoteId, CPQXL_HeavyProcessingInFlight__c = true); // this essentially locks the record throughout the whole chain of events until the chain is complete
            update new Opportunity(Id = opportunityId, CPQXL_HeavyProcessingInFlight__c = true); // this essentially locks the record throughout the whole chain of events until the chain is complete
            CPQU_BundleStructureUtils.enableTriggers(true, oppAndQuoteTriggerHandlersToToggle); // watch out for this potentially causing issues

            // we're going to need all fields on the relevant quote lines since we're performing a clone:
            CPQU_BundleStructureUtils.signalToQueryAllLineFields();

            Integer aggrNumberToProcess = Integer.valueOf(currentClqEvent.CPQXL_AggregationNumberToProcess__c);
            Integer numOfBundlesToCloneFromSourceQuote = Integer.valueOf(currentClqEvent.CPQXL_SourceQuoteNumberOfBundles__c);
            Map<Integer, Set<Id>> bundleAggregationsMap = (Map<Integer, Set<Id>>) JSON.deserialize(currentClqEvent.CPQXL_BundleAggregationsJSON__c, 
                Map<Integer, Set<Id>>.class);
            Map<Integer, Set<Id>> bundleAggregationsMapExtended = (Map<Integer, Set<Id>>) JSON.deserialize(currentClqEvent.CPQXL_BundleAggregationsExtendedJSON__c, 
                Map<Integer, Set<Id>>.class);
            Decimal totalNumOfAggregations = bundleAggregationsMap.keySet().size();
            // variable to handle a quote CPQXL_Constants.LARGE_QUOTE_SPLIT_SCENARIO vs a quote CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO, depending on the context in which the code firing this platform event wants to use:
            Set<Id> remainingSubSetQuoteIds = currentClqEvent.CPQXL_RemainingSubsetQuoteIds__c == null
                ? new Set<Id>() : (Set<Id>) JSON.deserialize(currentClqEvent.CPQXL_RemainingSubsetQuoteIds__c, Set<Id>.class);
             // variable to get all subset quote ids for a particular large quote split scenario:
            Set<Id> allSubSetQuoteIds = currentClqEvent.CPQXL_AllSubsetQuoteIds__c == null 
                ? new Set<Id>() : (Set<Id>) JSON.deserialize(currentClqEvent.CPQXL_AllSubsetQuoteIds__c, Set<Id>.class);
            
            Set<Id> lineIdsToProcessInThisThread = bundleAggregationsMapExtended.get(aggrNumberToProcess);
            // tell CPQU_BundleStructureUtils to only query certain lines, to reduce chances of hitting heap size limits:
            CPQU_BundleStructureUtils.linesToQuery = lineIdsToProcessInThisThread;

            // query quote lines already on the target quote from previous executions (there won't be any on the first execution):
            Map<Id, SBQQ__QuoteLine__c> existingTargetParentBundleLines = getExistingParentBundleLines(targetQuoteId);
            Set<Id> bundlesToProcess = bundleAggregationsMap.get(aggrNumberToProcess);
            Decimal aggrNumberToProcessDec = decimal.valueOf(aggrNumberToProcess);
            quoteCloneOrSplitJob.CPQXL_PercentComplete__c = Integer.valueOf(aggrNumberToProcessDec / totalNumOfAggregations * 100);
            update quoteCloneOrSplitJob;

            if(bundlesToProcess != null) {
                // disable triggers so we won't have to wait for the Queueable Calculator Service as a means to avoid a mixed DML..
                // we are simply cloning the lines so we shouldn't have to rely on CPQ triggers for accurate data, since those triggers have already
                // ran on the lines we're cloning
                SBQQ.TriggerControl.disable();
                // clone the first x number of lines (it won't always be exactly x, depending when the last bundle in the aggregation ends) where
                // x is the number defined in the EQ custom setting.
                // Note: We are telling CPQU_BundleStructureUtils to only query the quote lines in a particular bundle aggregation, as to avoid heap size errors:
                Map<Id, SObject> quoteLineClones = CPQU_BundleStructureUtils.cloneBundles(sourceQuoteId, targetQuoteId, null, bundlesToProcess);
                SBQQ.TriggerControl.enable();
            }

            // re-query to see how many parent bundles we have on the target now:
            existingTargetParentBundleLines = getExistingParentBundleLines(targetQuoteId);
            
            Integer numberofBundlesOnTarget = existingTargetParentBundleLines.size();
            Boolean isCloneScenario = (scenarioType == CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO);
            Boolean isSplitScenario = (scenarioType.contains(CPQXL_Constants.LARGE_QUOTE_SPLIT_SCENARIO) || scenarioType.contains(CPQXL_Constants.LARGE_ORDER_SCENARIO));

            // see if we have any remaining bundle aggregations to clone:
            if((isCloneScenario && numOfBundlesToCloneFromSourceQuote > numberofBundlesOnTarget)
                || (isSplitScenario && !remainingSubSetQuoteIds.isEmpty())) {
                Integer nextAggrNumberToProcess = aggrNumberToProcess + 1;

                // if this is a quote CPQXL_Constants.LARGE_QUOTE_SPLIT_SCENARIO scenario:
                if(!remainingSubSetQuoteIds.isEmpty()) {
                    // check if the quote has line number sequencing issues 
                    //  (potentially incurred from a bad line number sequence on the contract subs/assets; or from manual data manipulation)
                    if(CPQU_BundleStructureUtils.hasLineNumberSequencingIssues(targetQuoteId)) {
                        Set<String> triggerHandlersToToggle = CPQU_ApexUtils.consolidateTriggerHandlerNames(new Set<String>{
                            utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_QUOTE_TRIGGER_HANDLERS).TextValue__c, utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_QUOTE_LINE_TRIGGER_HANDLERS).TextValue__c
                        }); 
                        // disable CPQ triggers and quote/quote line custom triggers since we are simply updating the line numbers.
                        // The recalc method several lines down will fire the triggers.
                        CPQU_BundleStructureUtils.disableTriggers(true, triggerHandlersToToggle);
                        CPQU_BundleStructureUtils.patchLineNumbersOnXobject(targetQuoteId);
                        CPQU_BundleStructureUtils.enableTriggers(true, triggerHandlersToToggle);
                    }
                    
                    // for the clone scenario, recalculate the subset quote that was created in this thread, since we are done adding quote lines to this particular quote.
                    // Only recalc if CPQXL_IgnoreRecalcForQuoteClone__c in the custom setting is false.
                    if(!isSplitScenario || (isCloneScenario && !utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_IGNORE_RECALC_FOR_QUOTE_LINE).BooleanValue__c)) {
                        List<SBQQ__QuoteLine__c> targetQuoteBundleLines = recalculateTargetQuoteLines(targetQuoteId);
                    }

                    remainingSubSetQuoteIds.remove(targetQuoteId);
                    // overwrite the target quote id with the next blank quote,
                    // so that it receives the next bundle aggregation in the next platform event within the chain:
                    if(!remainingSubSetQuoteIds.isEmpty()) {
                        targetQuoteId = (new List<Id>(remainingSubSetQuoteIds))[0];
                    }
                }

                nextClqEvent.CPQXL_TargetQuoteId__c = targetQuoteId; // static for cloning, dynamic for splitting
                nextClqEvent.CPQXL_AggregationNumberToProcess__c = nextAggrNumberToProcess; // dynamic, store which aggregation number to process in the next thread.
                nextClqEvent.CPQXL_RemainingSubsetQuoteIds__c = JSON.serialize(remainingSubSetQuoteIds); // dynamic set of remaining quote ids for quote split scenario

                // Keep kicking off platform events until the target quote has all the necessary lines on it.
                publishNextClqEvent(nextClqEvent);
            // if it's a clone scenario and we've finished creating all the lines on the target quote:
            } else if(scenarioType == CPQXL_Constants.LARGE_QUOTE_CLONE_SCENARIO && numOfBundlesToCloneFromSourceQuote == numberofBundlesOnTarget) { // all lines have been cloned to the target quote
                List<SBQQ__QuoteLine__c> targetQuoteBundleLines = recalculateTargetQuoteLines(targetQuoteId);

                CPQU_BundleStructureUtils.disableTriggers(true, oppAndQuoteTriggerHandlersToToggle); // watch out for this potentially causing issues
                CPQU_BundleStructureUtils.patchLineNumbersOnXobject(targetQuoteId);
                update new SBQQ__Quote__c(Id = sourceQuoteId, CPQXL_HeavyProcessingInFlight__c = false);
                update new Opportunity(Id = opportunityId, CPQXL_HeavyProcessingInFlight__c = false);
                CPQU_BundleStructureUtils.enableTriggers(true, oppAndQuoteTriggerHandlersToToggle); // watch out for this potentially causing issues

                quoteCloneOrSplitJob.SBQQ__JobStatus__c = CPQXL_Constants.COMPLETED_STATUS;
                update quoteCloneOrSplitJob;
            // if it's a quote split scenario, and we have not yet finished cloning all the lines from the source quote to the target quotes:
            } else if((scenarioType == CPQXL_Constants.LARGE_QUOTE_SPLIT_SCENARIO || scenarioType == CPQXL_Constants.LARGE_ORDER_SCENARIO) && !remainingSubSetQuoteIds.isEmpty()) {
                quoteCloneOrSplitJob.SBQQ__JobStatus__c = CPQXL_Constants.COMPLETED_STATUS;
                update quoteCloneOrSplitJob;
            // if it's a quote split scenario, and we have finished cloning lines from source quote to subset quotes:
            } else if(scenarioType == CPQXL_Constants.LARGE_ORDER_SCENARIO && remainingSubSetQuoteIds.isEmpty()) {
                // Commenting out Order generation, as this will most likely be up to the user to order the smaller quotes:
                createAndPublishGloPlatformEvent(CPQXL_Constants.OPPORTUNITY_OBJ_NAME, sourceQuoteId, opportunityId, allSubSetQuoteIds);
                System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLTriggerHandler.processEvents() large order generation platform event kicked off...');
            }
        } catch(Exception ex) {
            // queue up another platform event and try again if the system runs into the UNABLE_TO_LOCK_ROW Exception:
            if(ex.getMessage().contains('UNABLE_TO_LOCK_ROW')) {
                Database.rollback(sp);
                //CPQU_ErrorLog__c errorLog = CPQU_ApexUtils.createErrorLog(ex, EVENT_CLASS_NAME + ': failed (UNABLE_TO_LOCK_ROW). Reattempting... ScenarioType: ' + scenarioType, EVENT_CLASS_NAME, sourceQuoteId);
                publishNextClqEvent(nextClqEvent); // try the same event again in another thread
            } else {
                Database.rollback(sp);
                CPQU_BundleStructureUtils.disableTriggers(true, oppAndQuoteTriggerHandlersToToggle);
                Database.update(new SBQQ__Quote__c(Id = sourceQuoteId, CPQXL_HeavyProcessingInFlight__c = false), false); // this essentially unlocks the record (since we hit an Exception)
                Database.update(new Opportunity(Id = opportunityId, CPQXL_HeavyProcessingInFlight__c = false), false); // this essentially unlocks the record (since we hit an Exception)

                String exceptionMessage = 'CPQXL_QuoteCloneXLTriggerHandler.processEvents(): FATAL Exception occurred: ' + ex.getMessage() + '. stack trace: ' + ex.getStackTraceString();
                System.debug(LoggingLevel.WARN, exceptionMessage);
                // create an 'in-flight' error log record so we can query it from the VFP (via the controller) and show the error on the page:
                CPQU_ErrorLog__c errorLog = CPQU_ErrorLogUtils.createErrorLog(ex, EVENT_CLASS_NAME + ': failed on the following scenario: ' + scenarioType, EVENT_CLASSNAME_IN_FLIGHT, sourceQuoteId);
                quoteCloneOrSplitJob.SBQQ__JobStatus__c = CPQXL_Constants.JOB_FAILED_STATUS;
                quoteCloneOrSplitJob.SBQQ__JobDetails__c = exceptionMessage;
                update quoteCloneOrSplitJob;
            }
        }
    }

    /**
     * @description -> Method to initialize the next C.L.Q. event in the platform event chain
     * @param CPQXL_CloneLargeQuoteEvent__e currentClqEvent -> the current C.L.Q. event (not the next one) in the platform event chain 
     * @return CPQXL_CloneLargeQuoteEvent__e -> the next C.L.Q. event to be published.
    **/
    private CPQXL_CloneLargeQuoteEvent__e initializeNextClqEvent(CPQXL_CloneLargeQuoteEvent__e currentClqEvent) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLTriggerHandler.initializeNextClqEvent()...');
        // Initialize additional Generate Large Quote platform event in memory (do not publish yet, we'll do that later in the execution):
        return new CPQXL_CloneLargeQuoteEvent__e(
            CPQXL_ScenarioType__c = currentClqEvent.CPQXL_ScenarioType__c, // static
            CPQXL_SourceQuoteId__c = currentClqEvent.CPQXL_SourceQuoteId__c, // static
            CPQXL_OpportunityId__c = currentClqEvent.CPQXL_OpportunityId__c, // static
            CPQXL_SourceQuoteNumberOfBundles__c = currentClqEvent.CPQXL_SourceQuoteNumberOfBundles__c, // static
            CPQXL_BundleAggregationsJSON__c = currentClqEvent.CPQXL_BundleAggregationsJSON__c, // static
            CPQXL_BundleAggregationsExtendedJSON__c = currentClqEvent.CPQXL_BundleAggregationsExtendedJSON__c, // static
            CPQXL_AllSubsetQuoteIds__c = currentClqEvent.CPQXL_AllSubsetQuoteIds__c, // static
            CPQXL_TargetQuoteId__c = currentClqEvent.CPQXL_TargetQuoteId__c, // static for cloning, dynamic for splitting
            CPQXL_AggregationNumberToProcess__c = currentClqEvent.CPQXL_AggregationNumberToProcess__c, // dynamic(ish)
            CPQXL_RemainingSubsetQuoteIds__c = currentClqEvent.CPQXL_RemainingSubsetQuoteIds__c // dynamic(ish)
        );
    }

    /**
     * @description -> Method to publish the next C.L.Q event in the platform event chain
     * return void
    **/
    private void publishNextClqEvent(CPQXL_CloneLargeQuoteEvent__e nextClqEvent) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLTriggerHandler.publishNextClqEvent()...');

        Long startingTime = System.now().getTime();
        while (System.now().getTime() - startingTime < 500) {
            // Do nothing - workaround for not having a sleep or wait function
        }

        EventBus.publish(nextClqEvent);
    }

    /**
    * @description -> Method to recalculate target quote lines.
    * @param Id targetQuoteId -> id of the quote in which to recalculate
    * @return List<SBQQ__QuoteLine__c> -> list of quote lines that a recalculate was fired on
    **/
    private List<SBQQ__QuoteLine__c> recalculateTargetQuoteLines(Id targetQuoteId) {
        List<SBQQ__QuoteLine__c> targetQuoteBundleLines = [
            SELECT Id, SBQQ__Quote__r.SBQQ__Opportunity2__c
            FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c = :targetQuoteId AND SBQQ__RequiredBy__c = null
        ];
        // recalculate target quote by updating one of its bundle quote lines
        if(!targetQuoteBundleLines.isEmpty()) {
            update targetQuoteBundleLines[0];
        }

        return targetQuoteBundleLines;
    }

    /**
    * @description -> Method to get the ids of the quote lines that already exist on the target quote.
    * @param Map<Integer, Set<Id>> bundleAggregationsMap -> a map of all the bundle ids, broken out into aggregations at each key.
    * @return Set<Id> bundlesToProcess -> a set of the bundle ids to process in a given thread.
    **/
    private Map<Id, SBQQ__QuoteLine__c> getExistingParentBundleLines(Id targetQuoteId) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteCloneXLTriggerHandler.getExistingParentBundleLines() targetQuoteId: ' + targetQuoteId);
        // query quote lines already on the target quote from previous executions:
        Map<Id, SBQQ__QuoteLine__c> existingParentBundleLinesOnTarget = new Map<Id, SBQQ__QuoteLine__c>([
            SELECT Id, SBQQ__Source__c, SBQQ__Number__c FROM SBQQ__QuoteLine__c 
            WHERE SBQQ__Quote__c = :targetQuoteId AND SBQQ__RequiredBy__c = null
            ORDER BY SBQQ__Number__c
        ]);

        return existingParentBundleLinesOnTarget;
    }

    /**
     * @description -> Method to create a publish a the first Generate Large Order event in the Generate Large Order platform event chain.
     *  Note: the first Generate Large Order event in the chain will create the first subset order
     * @param String sourceContext
     * @param Id sourceQuoteId
     * @param Id opportunityId
     * @param Set<Id> allSubsetQuoteIds
     * @return void
     **/
    private void createAndPublishGloPlatformEvent(String sourceContext, Id sourceQuoteId, Id opportunityId, Set<Id> allSubsetQuoteIds) {
        // Fire the chain of platform events that will ultimately assemble the large order from the subset quotes:
        CPQXL_GenerateLargeOrderEvent__e generateLargeOrderEvent = new CPQXL_GenerateLargeOrderEvent__e(
            CPQXL_SourceContext__c = sourceContext,
            CPQXL_SourceQuoteId__c = sourceQuoteId, // static
            CPQXL_OpportunityId__c = opportunityId, // static
            CPQXL_RemainingSubsetQuoteIds__c = JSON.serialize(allSubSetQuoteIds) // dynamic
        );

        Long startingTime = System.now().getTime();
        while (System.now().getTime() - startingTime < delayInMilliseconds) {
            // Do nothing - workaround for not having a sleep or wait function
        }

        EventBus.publish(generateLargeOrderEvent);
        System.debug(LoggingLevel.WARN, 'CloneLargeQuoteTriggerHandler.processEvents() split order scenario generateLargeOrderEvent: ' + generateLargeOrderEvent);
    }
}