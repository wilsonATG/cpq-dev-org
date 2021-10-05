/**
 * 
 * CPQXL_OrderContractXLTriggerHandler class
 *
 * Versioning: 
 *   3/22/21 : Steve Lohrenz : File Created
 */

public with sharing class CPQXL_OrderContractXLTriggerHandler extends CPQU_EventTriggerHandler {
    private static final String EVENT_CLASSNAME = 'CPQXL_OrderContractXLTriggerHandler';
    private static final String EVENT_CLASSNAME_IN_FLIGHT = 'CPQXL_OrderContractXLTriggerHandler' + CPQU_Constants.ERROR_INFLIGHT_INDICATOR;
    private static final String ORDER_ITEM_SOURCE_FIELD_REF = 'CPQXL_SourceId__c';

    // For the G.L.C. process, if you want to disable custom Subscription trigger handlers and/or Contract trigger handlers, 
    //  you can define those trigger handlers in CPQXL Settings.
    private static Set<String> subscriptionAndContractTriggersToToggle = CPQU_ApexUtils.consolidateTriggerHandlerNames(new Set<String>{
      CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_SUBSCRIPTION_TRIGGER_HANDLERS).TextValue__c, CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_CONTRACT_TRIGGER_HANDLERS).TextValue__c, CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_ASSET_TRIGGER_HANDLERS).TextValue__c
    });

    // If you want to disable custom Order trigger handlers and Order item trigger handlers, 
    //  you can define those trigger handlers in CPQXL Settings.
    private static Set<String> orderAndOrderItemTriggerHandlersToToggle = CPQU_ApexUtils.consolidateTriggerHandlerNames(new Set<String>{
      CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_ORDER_TRIGGER_HANDLERS).TextValue__c, CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_ORDER_ITEM_TRIGGER_HANDLERS).TextValue__c
    });

    private static String scenarioType; // whether we're contracting from opportunity, or order. Currently only contracting from the order is supported for G.L.C.
    private static Id mainOrderId; // id of the main (aka large) order we are generating the large contract for
    private static Id primaryQuoteId;
    private static Id mainContractId; // the id of the contract that will soon be the large contract (at the end of the process)
    private static Set<Id> remainingSubsetOrderIds; // a dynamically shrinking list of subset order ids, in which we will generate subset contracts for
    private static Integer numOfEventsAccumulatedForOrder;

    // Constructor Variation 1:    
    public CPQXL_OrderContractXLTriggerHandler() {

    }

    // Constructor Variation 2:
    public CPQXL_OrderContractXLTriggerHandler(Integer retries, Integer delay) {
        delayInMilliseconds = delay;
        numberRetries = retries;
    }

    protected override void afterEventInsert(List<SObject> events) {
        processEvents((List<CPQXL_GenerateLargeContractEvent__e>) events);
    }

    /**
     * @description -> Method to create smaller contracts (aka subset contracts) to assist in creating a large contract or series of large contracts.
     * @param generateLargeContractEvents List<CPQXL_GenerateLargeContractEvent__e> -> a list of Generate Large Contract events.
     *  Note: There will only ever be one contract per 'execution/thread' (aka per event in the platform event chain)
     *  There will almost always be multiple events in the chain, per large contract generation 'process'.
    **/
    public void processEvents(List<CPQXL_GenerateLargeContractEvent__e> generateLargeContractEvents) {
        System.debug(LoggingLevel.WARN, 'CPQXL_OrderContractXLTriggerHandler.processEvents() generateLargeContractEvents 1:' + generateLargeContractEvents);
        CPQXL_GenerateLargeContractEvent__e currentGlcEvent = generateLargeContractEvents[0];

        scenarioType = currentGlcEvent.CPQXL_SourceContext__c;
        mainOrderId = currentGlcEvent.CPQXL_OrderId__c;
        mainContractId = currentGlcEvent.CPQXL_MainContractId__c;
        primaryQuoteId = currentGlcEvent.CPQXL_PrimaryQuoteId__c;
        // Track how many events we've ran for attempting to contract a particular subset order:
        numOfEventsAccumulatedForOrder = currentGlcEvent.CPQXL_NumberOfEventsAccumulated__c == null ? 1 : Integer.valueOf(currentGlcEvent.CPQXL_NumberOfEventsAccumulated__c);

        // Initialize additional Generate Large Contract platform event in memory (do not publish yet, we'll do that later in the execution):
        CPQXL_GenerateLargeContractEvent__e nextGlcEvent = initializeNextGlcEvent(currentGlcEvent);

        remainingSubsetOrderIds = currentGlcEvent.CPQXL_RemainingSubsetOrderIds__c == null
            ? new Set<Id>() : (Set<Id>) JSON.deserialize(currentGlcEvent.CPQXL_RemainingSubsetOrderIds__c, Set<Id>.class);
        System.debug('CPQXL_OrderContractXLTriggerHandler.processEvents() remainingSubsetOrderIds.size():' + remainingSubsetOrderIds.size());

        Savepoint sp = Database.setSavepoint();
        try {
            CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle); // watch out for this potentially causing issues
            update new Order(Id = mainOrderId, CPQXL_HeavyProcessingInFlight__c = true); // this essentially locks the record from editable by anyone but Automated Process user, throughout the whole chain of events until the chain is complete
            CPQU_BundleStructureUtils.enableTriggers(true, orderAndOrderItemTriggerHandlersToToggle); // watch out for this potentially causing issues

            // if we still have subset orders in which we need to create subset contracts for:
            if(!remainingSubsetOrderIds.isEmpty()) {
                Id orderIdToProcess = (new List<Id>(remainingSubsetOrderIds))[0];

                // ignore any subset orders that don't have at least one subscription product on them:
                List<Order> subsetOrders = [
                    SELECT Id, Status, SBQQ__Contracted__c FROM Order WHERE Id = :orderIdToProcess
                    AND Id IN (SELECT OrderId FROM OrderItem WHERE Product2.SBQQ__SubscriptionPricing__c != NULL) FOR UPDATE
                ]; // subset order to contract in this thread/event in the chain
                System.debug('CPQXL_OrderContractXLTriggerHandler.processEvents() subsetOrders.size():' + subsetOrders.size());

                if(subsetOrders.isEmpty()) {
                    remainingSubsetOrderIds.remove(orderIdToProcess); // this particular subset order does not have any subscription products, therefore skip it
                    numOfEventsAccumulatedForOrder = 0;
                    nextGlcEvent.CPQXL_RemainingSubsetOrderIds__c = JSON.serialize(remainingSubsetOrderIds);
                    nextGlcEvent.CPQXL_NumberOfEventsAccumulated__c = numOfEventsAccumulatedForOrder;
                    publishNextGlcEvent(nextGlcEvent, numOfEventsAccumulatedForOrder, sp);
                    return;
                }

                Order subsetOrder = subsetOrders[0];

                subsetOrder = activateAndContractSubsetOrder(subsetOrder);
                List<Contract> newContracts = scanForNewlyGeneratedContract(subsetOrder);
                System.debug('CPQXL_OrderContractXLTriggerHandler.processEvents() newContracts.size():' + newContracts.size());

                if(newContracts.isEmpty()) {
                    numOfEventsAccumulatedForOrder += 1;
                    nextGlcEvent.CPQXL_NumberOfEventsAccumulated__c = numOfEventsAccumulatedForOrder;
                    // republish the same event until we get a contract with Subscriptions on it.
                    publishNextGlcEvent(nextGlcEvent, numOfEventsAccumulatedForOrder, sp);
                } else {
                    Contract newlyGeneratedSubsetContract = newContracts[0];

                    // we now have a subset contract generated with subscriptions.
                    if(mainContractId == null) {
                        // If this is the first subset contract, clone the header to another contract (which will be designated as the main aka large contract):
                        Contract mainContract = createMainContract(newlyGeneratedSubsetContract, mainOrderId, primaryQuoteId);
                        mainContractId = mainContract.Id;
                        nextGlcEvent.CPQXL_MainContractId__c = mainContractId;
                    }

                    // stamp the subset contract with some specific field values to denote that it is a subset contract in the system:
                    newlyGeneratedSubsetContract = stampSubsetContractWithCPQXLValues(mainContractId, newlyGeneratedSubsetContract);
                    // tell CPQXL_BundleStructureUtils what the source order product field ref is.
                    CPQU_BundleStructureUtils.ORDER_ITEM_SOURCE_FIELD_REF = ORDER_ITEM_SOURCE_FIELD_REF;

                    // move the subscriptions (and Assets IB Specific) from the subset contract to the main contract, while also reestablishing the following relationships to align with the
                    // main (large) Order's Order Products, as well as to align with the main (large) Quote's quote lines:
                    //   -> Asset.SBQQ__OrderProduct__c, Asset.SBQQ__QuoteLine__c, Asset.SBQQ__LatestQuoteLine__c -> assign from subset to main
                    //   -> Subscription.SBQQ__OrderProduct__c, Subscription.SBQQ__QuoteLine__c -> assign from subset to main
                    Map<Id, SObject> linesToMove = CPQU_BundleStructureUtils.moveContractBundles(newlyGeneratedSubsetContract.Id, mainContractId, false /*Boolean doUpdate*/);
                    for(SObject line : linesToMove.values()) {
                        line = reassignManagedLookupFieldsOnObj(line, ORDER_ITEM_SOURCE_FIELD_REF);
                    }

                    System.debug('CPQXL_OrderContractXLTriggerHandler.processEvents() linesToMove.size():' + linesToMove.size());
                    if(!linesToMove.isEmpty()) {
                        update linesToMove.values(); // move the bundles to the main (large) contract
                    }

                    remainingSubsetOrderIds.remove(subsetOrder.Id); // we are done processing this subset order. Remove it from the set so that we can process the next one in the next event/thread
                    numOfEventsAccumulatedForOrder = 0;
                    nextGlcEvent.CPQXL_RemainingSubsetOrderIds__c = JSON.serialize(remainingSubsetOrderIds);
                    nextGlcEvent.CPQXL_NumberOfEventsAccumulated__c = numOfEventsAccumulatedForOrder;
                    publishNextGlcEvent(nextGlcEvent, numOfEventsAccumulatedForOrder, sp);
                }
            } else {
                // we have finished creating the subset contracts AND have shuttled their bundles to the main (large contract)
                // Delete the subset contracts... they are no longer needed.
                cleanupSubsetContractsAndOrders(mainOrderId, mainContractId);

                // TODO: watch out for the potential need to twin source order products (from subset orders) to target order products (on the main order) 
                //   after marking the SBQQ__Contracted__c checkbox on the subset Order with Triggers disabled.
                // If we need to do that, then it will have to be in additional threads.
                // Also watch out for the potential need to twin the source order header over from one of the subset orders to the large order header 
                //  (after marking the SBQQ__Contracted__c checkbox on the Order with triggers disabled)

                CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
                // no need for managed CPQ triggers to run here. We've already ran CPQ triggers in the previous events within the event chain, 
                // thus generating the resource intensive Subscriptions and shuttling them to the master contract.
                update new Order(Id = mainOrderId, CPQXL_HeavyProcessingInFlight__c = false, SBQQ__Contracted__c = true);
                List<OrderItem> mainOrderItems = [SELECT Id FROM OrderItem WHERE OrderId = :mainOrderId];

                for(OrderItem OrderItem : mainOrderItems) {
                    OrderItem.SBQQ__Contracted__c = true;
                    //OrderItem.SBQQ__Contract__c = mainContractId;
                }
                try {
                    if(!mainOrderItems.isEmpty()) {
                        update mainOrderItems;
                    }
                } catch(Exception e2) { 
                    Database.rollback(sp);
                    Database.update(new Order(Id = mainOrderId, CPQXL_HeavyProcessingInFlight__c = false), false); // this essentially unlocks the record (since we hit an exception)
                    CPQU_ErrorLogUtils.createErrorLog(e2, EVENT_CLASSNAME + ': failed to generate large contract.', EVENT_CLASSNAME_IN_FLIGHT, mainOrderId);
                }

            }
        } catch(Exception e) {
            if(e.getMessage().contains('UNABLE_TO_LOCK_ROW')) {
                Database.rollback(sp);
                publishNextGlcEvent(nextGlcEvent, numOfEventsAccumulatedForOrder, sp); // try the same event again in a fresh thread/event
            } else {
                Database.rollback(sp);
                System.debug(LoggingLevel.WARN, 'CPQXL_OrderContractXLTriggerHandler.processEvents(): FATAL error occurred: ' + e.getMessage() + '. stack trace: ' + e.getStackTraceString());
                // create an error log record so we can query it from the VFP and show the error on the page:
                CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
                Database.update(new Order(Id = mainOrderId, CPQXL_HeavyProcessingInFlight__c = false), false); // this essentially unlocks the record (since we hit an exception)
                CPQU_ErrorLogUtils.createErrorLog(e, EVENT_CLASSNAME + ': failed to generate large contract.', EVENT_CLASSNAME_IN_FLIGHT, mainOrderId);
            }
        }
    }

    /**
     * @description -> Method to initialize the first event in the Generate Large Contract platform event chain.
     * @param currentGlcEvent CPQXL_GenerateLargeContractEvent__e -> the currently running Generate Large Contract platform event
     * @return CPQXL_GenerateLargeContractEvent__e -> the first event in a Generate Large Contract platform event chain
     */
    private CPQXL_GenerateLargeContractEvent__e initializeNextGlcEvent(CPQXL_GenerateLargeContractEvent__e currentGlcEvent) {
        System.debug(LoggingLevel.WARN, 'CPQXL_OrderContractXLTriggerHandler.initializeGlcEvent()...');
        // Initialize additional Generate Large Quote platform event in memory (do not publish yet, we'll do that later in the execution):
        return new CPQXL_GenerateLargeContractEvent__e(
            CPQXL_SourceContext__c = currentGlcEvent.CPQXL_SourceContext__c, // static
            CPQXL_OrderId__c = currentGlcEvent.CPQXL_OrderId__c, // static
            CPQXL_PrimaryQuoteId__c = currentGlcEvent.CPQXL_PrimaryQuoteId__c, // static
            CPQXL_MainContractId__c = currentGlcEvent.CPQXL_MainContractId__c, // static
            CPQXL_RemainingSubsetOrderIds__c = currentGlcEvent.CPQXL_RemainingSubsetOrderIds__c // dynamically shrinks as the chain progresses
        );
    }

    /**
     * @description -> Method to activate a subset order and kick off the CPQ OOB contracting of it:
     * @param subsetOrder Order -> the subset order to activate and contract. Note: contracting it causes CPQ to kick off a queueable thread that executes asynchronously.
     * @return Order subsetOrder -> the activated (and soon to be contracted) subset order
     */
    private Order activateAndContractSubsetOrder(Order subsetOrder) {
        // activate subset order if it isn't already
        if(subsetOrder.Status != CPQU_Constants.STATUS_ACTIVATED) {
            subsetOrder.Status = CPQU_Constants.STATUS_ACTIVATED;
            update subsetOrder;
        }
        // reset the Contracted checkbox if it is checked. This is necessary in case the managed CPQ future thread fails the first time,
        // possibly due to a UNABLE_TO_LOCK_ROW error.
        if(subsetOrder.SBQQ__Contracted__c) {
            subsetOrder.SBQQ__Contracted__c = false;
            update subsetOrder;
        }
        // contract the subset order (if it isn't already):
        if(!subsetOrder.SBQQ__Contracted__c) {
            subsetOrder.SBQQ__Contracted__c = true;
            update subsetOrder; // this will cause the CPQ to start generating the contract for the subset order, which happens asynchronously
        }

        return subsetOrder;
    }

    /**
    * @description -> Method to query for the newly generated subset (smaller) contract, where that newly generated contract was generated by the CPQ package
    * @param subsetOrder Order -> the order in which we marked SBQQ__Contracted__c on in this particular thread/event
    * @return List<Contract> newContracts -> a List of contracts, that will have a contract within it if the CPQ managed package finished generating one.
    */
    private List<Contract> scanForNewlyGeneratedContract(Order subsetOrder) {
        Datetime tenMinutesAgo = (System.now() - 0.006908);
        // Now see if the new contract has been created AND subscriptions have been created for it (by the CPQ package) AND quote line has been populated on those subscriptions.
        // If it hasn't, we'll keep checking in subsequent events until it has, then clone its subscriptions to the main (large) contract.
        // Query contracts created within the last 5 minutes where the SBQQ__Order__c is populated with the subset order we 
        // are working with in this thread/event within the chain of events:
        List<Contract> newContracts = [
            SELECT Id FROM Contract WHERE SBQQ__Order__c != NULL AND SBQQ__Order__c = :subsetOrder.Id AND CPQXL_GenerateLargeContractApplicable__c = FALSE
            AND Id IN (
                SELECT SBQQ__Contract__c FROM SBQQ__Subscription__c
                WHERE SBQQ__Contract__r.SBQQ__Order__c = :subsetOrder.Id AND SBQQ__OrderProduct__c != NULL AND SBQQ__QuoteLine__c != NULL
            )
            AND CreatedDate > :tenMinutesAgo ORDER BY CreatedDate DESC LIMIT 1
        ];

        return newContracts;
    }


    /**
    * @description -> Method to reassign managed lookup fields on Assets and Subscriptions
    *  Example: for the Generate Large Contract scenario, we need to align the managed lookups (SBQQ__QuoteLine__c, SBQQ__OrderProduct__c) with the Order Products
    *  on the main (large) Order.
    * @param line SObject - Asset or Subscription to assign the correct managed lookup values on
     * @param orderItemSourceField String - field name that is the source of the lookup
    * @return SObject line -> an Asset or Subscription with correctly assigned managed lookups
    */
    private SObject reassignManagedLookupFieldsOnObj(SObject line, String orderItemSourceField) {
        // for the Generate Large Contract scenario, we need to re-assign several of the managed lookups on subscriptions and assets,
        // to point to their associated main line lookups (instead of the subset line lookups):
        OrderItem relatedOrderItem = (OrderItem) line.getSObject('SBQQ__OrderProduct__r'); // relatedOrderItem is an Order Item from a subset (small) order
        if(relatedOrderItem != null) {
            // get the main Order Item Id (which came from the main aka large order) associated to the subset Order Item (which came from a subset aka small order):
            Id mainOrderItemId = cpqxlSourceToMainOrderItemId.get(relatedOrderItem.Id);
            if(mainOrderItemId != null) {
                // Re-assign SBQQ__OrderProduct__c on assets and subscriptions, from the subset order product, to the order product on the main (large) order:
                line.put('SBQQ__OrderProduct__c', mainOrderItemId);
            }
        }

        // Re-assign SBQQ__QuoteLine__c on subscriptions, from traversing through to SBQQ__QuoteLine__r.SBQQ__Source__c
        if(line instanceof SBQQ__Subscription__c) {
            SBQQ__Subscription__c subscription = (SBQQ__Subscription__c) line;
            line.put('SBQQ__QuoteLine__c', subscription.SBQQ__QuoteLine__r.SBQQ__Source__c);
        } else if(line instanceof Asset) {
            // Also re-assign SBQQ__QuoteLine__c on assets the same way, but only if SBQQ__LatestQuoteLine__c matches the SBQQ__QuoteLine__c.
            // We want to avoid overwriting SBQQ__QuoteLine__c on existing assets when the customer hits their 2nd and subsequent cycles.
            Asset asset = (Asset) line;
            if(asset.SBQQ__LatestQuoteLine__c == asset.SBQQ__QuoteLine__c) {
                line.put('SBQQ__QuoteLine__c', asset.SBQQ__QuoteLine__r.SBQQ__Source__c);
                line.put('SBQQ__LatestQuoteLine__c', asset.SBQQ__QuoteLine__r.SBQQ__Source__c);
            } else {
                line.put('SBQQ__LatestQuoteLine__c', asset.SBQQ__LatestQuoteLine__r.SBQQ__Source__c);
            }
        }

        return line;
    }

    // variable to retrieve the order items from the main (large) order. This is the order the user is generating a large contract for.
    private Map<Id, OrderItem> mainOrderItems {
        get {
            if(mainOrderItems == null) {
                mainOrderItems = new Map<Id, OrderItem>([
                    SELECT Id, CPQXL_SourceId__c FROM OrderItem WHERE OrderId = :mainOrderId
                ]);
            }
            return mainOrderItems;
        }
        set;
    }

    // variable to map the source order item (source clone) to the cloned order item (subset aka small order item)
    private Map<Id, Id> cpqxlSourceToMainOrderItemId {
        get {
            if(cpqxlSourceToMainOrderItemId == null) {
                cpqxlSourceToMainOrderItemId = new Map<Id, Id>();
                for(OrderItem OrderItem : mainOrderItems.values()) {
                    cpqxlSourceToMainOrderItemId.put(OrderItem.CPQXL_SourceId__c, OrderItem.Id);
                }
            }
            return cpqxlSourceToMainOrderItemId;
        }
        set;
    }

    /**
     * @description -> Method to publish the next G.L.C. event in the platform event chain
    **/
    private void publishNextGlcEvent(CPQXL_GenerateLargeContractEvent__e nextGlcEvent, Integer numOfEventsAccumulatedForOrder, Savepoint sp) {
        System.debug(LoggingLevel.WARN, 'CPQXL_OrderContractXLTriggerHandler.publishNextGlcEvent()...');
        // If something goes very wrong in the process, we need an insurance policy to terminate the event chain. Here it is:
        Integer maxNumOfEventsToAllow = 500;

        if(numOfEventsAccumulatedForOrder <= maxNumOfEventsToAllow) {
            Long startingTime = System.now().getTime();
            while (System.now().getTime() - startingTime < 500) {
                // Do nothing - workaround for not having a sleep or wait function
            }

            EventBus.publish(nextGlcEvent);
        } else {
            Database.rollback(sp);
            System.debug(LoggingLevel.WARN, 'CPQXL_OrderContractXLTriggerHandler.publishNextGlcEvent(): too many Generate Large Contract events ran. Bailing out!');
            // create an error log record so we can query it from the VFP and show the error on the page:
            CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
            Database.update(new Order(Id = mainOrderId, CPQXL_HeavyProcessingInFlight__c = false), false); // this essentially unlocks the record (since we hit an exception)
            CPQU_ErrorLogUtils.createErrorLog(EVENT_CLASSNAME, 'Exceeded the number of events to allow. ' ,null,  nextGlcEvent.CPQXL_MainContractId__c);
        }
    }

    /**
     * @description method to create the main (and what will eventually be large) contract:
     * @param newlyGeneratedSubsetContract Id - new subset contract
     * @param mainOrderId Id - the order id of the main contract
     * @param primaryQuoteId Id - the quote id of the primary quote
     *
     * @return Contract which was newly created
     */
    private Contract createMainContract(Contract newlyGeneratedSubsetContract, Id mainOrderId, Id primaryQuoteId) {
        // If this is the first subset contract, clone the header to another contract (which will be designated as the main aka large contract):
        Contract mainContract = ((Contract) CPQU_BundleStructureUtils.cloneXObjectHeader(newlyGeneratedSubsetContract.Id /*sourceXObjectId*/, false /*doInsert*/));
        mainContract.CPQXL_GenerateLargeContractApplicable__c = true;
        mainContract.SBQQ__Order__c = mainOrderId;
        mainContract.SBQQ__Quote__c = primaryQuoteId; ////
        mainContract.Status = CPQU_Constants.STATUS_DRAFT;
        insert mainContract;
        // Commenting out the next line to avoid the following error: 'You can't edit Contract Number on activated orders'
        //update new Order(Id = mainOrderId, contractId = mainContractId); //// establish linkage of main (large) order to main (soon to be large) contract
        return mainContract;
    }

    /**
     * @description -> method to stamp the subset contract with a few field values to denote it is a subset contract n the system.
     * @param mainContractId Id -> the id of the main (aka large, not a subset) contract
     * @param newlyGeneratedSubsetContract  Contract  -> the subset contract to stamp
     * @return Contract newlyGeneratedSubsetContract -> the subset contract that gets stamped in this method
    **/
    private Contract stampSubsetContractWithCPQXLValues(Id mainContractId, Contract newlyGeneratedSubsetContract) {
        newlyGeneratedSubsetContract.CPQXL_LargeContractId__c = mainContractId;
        newlyGeneratedSubsetContract.CPQXL_GenerateLargeContractApplicable__c = true;
        CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
        // no need for triggers to run on this update, since we are simply stamping CPQXL_LargeContractId__c and CPQXL_GenerateLargeContractApplicable__c on the contract:
        update newlyGeneratedSubsetContract;
        CPQU_BundleStructureUtils.enableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);

        return newlyGeneratedSubsetContract;
    }


    /**
     * @description -> Method to reassign customer assets to the large contract, and delete the smaller subset contracts
     * @param mainOrderId Id -> the Id of the large Order
     * @param mainContractId Id -> the Id of the Large Contract
    **/
    private void cleanupSubsetContractsAndOrders(Id mainOrderId, Id mainContractId) {
        if (!CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_KEEP_SUBSET_CONTRACTS).BooleanValue__c) {
            // we have finished creating the subset contracts AND have shuttled their bundles to the main (large contract)
            // Delete the subset contracts... they are no longer needed.
            List<Contract> contractsToDelete = [
                    SELECT Id
                    FROM Contract
                    WHERE CPQXL_GenerateLargeContractApplicable__c = TRUE AND CPQXL_LargeContractId__c != NULL AND SBQQ__Order__c != :mainOrderId
                    AND CPQXL_LargeContractId__c != NULL AND CPQXL_LargeContractId__c = :mainContractId
            ];
            System.debug('CPQXL_OrderContractXLTriggerHandler.cleanupSubsetContractsAndOrders() contractsToDelete.size() ' + contractsToDelete.size());

            if (!contractsToDelete.isEmpty() && !CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_KEEP_SUBSET_CONTRACTS).BooleanValue__c) {
                List<Database.DeleteResult> updateResult = Database.delete(contractsToDelete, false);
                for (Database.DeleteResult sr : updateResult) {
                    List<Database.Error> errList = sr.getErrors();
                    if (!errList.isEmpty()) {
                        for (Database.Error anError : errList) {
                            String msg = 'CPQXL_OrderContractXLTriggerHandler.cleanupSubsetContractsAndOrders: ' + anError.getStatusCode() + ' : ' + anError.getMessage();
                            System.debug(LoggingLevel.WARN, msg);
                            CPQU_ErrorLogUtils.createErrorLog(msg + ' : failed to generate large contract .', EVENT_CLASSNAME, null, mainOrderId);
                        }
                    }
                }
            }
        }

        if(!CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_KEEP_SUBSET_ORDERS).BooleanValue__c) {
            List<Order> subsetOrdersToDelete = [SELECT Id FROM Order WHERE CPQXL_LargeOrderId__c = :mainOrderId];
            System.debug('CPQXL_OrderContractXLTriggerHandler.cleanupSubsetContractsAndOrders() subsetOrdersToDelete.size() ' + subsetOrdersToDelete.size());

            if (!subsetOrdersToDelete.isEmpty()) {
                List<Database.DeleteResult> updateResult = Database.delete(subsetOrdersToDelete, false);
                for (Database.DeleteResult sr : updateResult) {
                    List<Database.Error> errList = sr.getErrors();
                    if (!errList.isEmpty()) {
                        for (Database.Error anError : errList) {
                            String msg = 'CPQXL_OrderContractXLTriggerHandler.cleanupSubsetContractsAndOrders: ' + errList[0].getStatusCode() + ' : ' + errList[0].getMessage();
                            System.debug(LoggingLevel.WARN, msg);
                            CPQU_ErrorLogUtils.createErrorLog(msg + ' : failed to generate large contract. 1 ', EVENT_CLASSNAME, null, mainOrderId);
                        }
                    }
                }
            }
        }
    }

}
