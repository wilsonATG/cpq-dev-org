/**
 * 
 * CPQXL_QuoteOrderXLTriggerHandler class
 *
 * Versioning: 
 *   3/22/21 : Steve Lohrenz : File Created
 */

public without sharing class CPQXL_QuoteOrderXLTriggerHandler extends CPQU_EventTriggerHandler {

    public static final String EVENT_CLASSNAME = 'CPQXL_QuoteOrderXLTriggerHandler';
    public static final String EVENT_CLASSNAME_IN_FLIGHT = 'CPQXL_QuoteOrderXLTriggerHandler' + CPQU_Constants.ERROR_INFLIGHT_INDICATOR;

    // For the G.L.O process, if you want to disable custom Opportunity trigger handlers and Quote trigger handlers, 
    //  you can define those trigger handlers in CPQXL Settings.
    public static Set<String> oppAndQuoteTriggerHandlersToToggle = CPQU_ApexUtils.consolidateTriggerHandlerNames(new Set<String>{
      CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_QUOTE_TRIGGER_HANDLERS).TextValue__c, CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_OPPORTUNITY_TRIGGER_HANDLERS).TextValue__c
    });
    // For the G.L.O process, if you want to disable custom Order trigger handlers and Order item trigger handlers, 
    //  you can define those trigger handlers in CPQXL Settings.
    public static Set<String> orderAndOrderItemTriggerHandlersToToggle = CPQU_ApexUtils.consolidateTriggerHandlerNames(new Set<String>{
      CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_ORDER_TRIGGER_HANDLERS).TextValue__c, CPQU_TriggerHandler.utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_CUSTOM_ORDER_ITEM_TRIGGER_HANDLERS).TextValue__c
    });

    public static String sourceContext; // whether we're ordering from opportunity, or quote. Currently only ordering from the opportunity is supported for G.L.O.
    public static Id sourceQuoteId;
    public static Id opportunityId;
    public static Set<Id> remainingSubSetQuoteIds;
    public static Map<String, Id> orderSplitCategoryToMainOrderId;

    // Constructor Variation 1:    
    public CPQXL_QuoteOrderXLTriggerHandler() {
        super(EVENT_CLASSNAME);
    }

    // Constructor Variation 2:
    public CPQXL_QuoteOrderXLTriggerHandler(Integer retries, Integer delay) {
        super(EVENT_CLASSNAME);
        delayInMilliseconds = delay;
        numberRetries = retries;
    }

    protected override void afterEventInsert(List<SObject> events) {
        processEvents((List<CPQXL_GenerateLargeOrderEvent__e>) events);
    }

    /**
     * @description -> Method to create smaller orders (aka subset order) to assist in creating a large order or series of large orders.
     * @param generateLargeOrderEvents List<CPQXL_GenerateLargeOrderEvent__e> -> a list of Generate Large Order Events.
     *  Note: There will only ever be one per 'execution/thread'.
     *  There will almost always be multiple events in the chain, per large order generation 'process'.
    **/
    public void processEvents(List<CPQXL_GenerateLargeOrderEvent__e> generateLargeOrderEvents) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() generateLargeOrderEvents 1:' + generateLargeOrderEvents);
        CPQXL_GenerateLargeOrderEvent__e currentGloEvent = generateLargeOrderEvents[0];

        sourceContext = currentGloEvent.CPQXL_SourceContext__c;
        sourceQuoteId = currentGloEvent.CPQXL_SourceQuoteId__c;
        opportunityId = currentGloEvent.CPQXL_OpportunityId__c;

        // Initialize additional Generate Large Order platform event in memory (do not publish yet, we'll do that later in the execution):
        CPQXL_GenerateLargeOrderEvent__e nextGloEvent = initializeNextGloEvent(currentGloEvent);

        remainingSubSetQuoteIds = currentGloEvent.CPQXL_RemainingSubsetQuoteIds__c == null
            ? new Set<Id>() : (Set<Id>) JSON.deserialize(currentGloEvent.CPQXL_RemainingSubsetQuoteIds__c, Set<Id>.class);
        orderSplitCategoryToMainOrderId = currentGloEvent.CPQXL_OrderSplitCategorytoMainOrderId__c == null
            ? new Map<String, Id>() : (Map<String, Id>) JSON.deserialize(currentGloEvent.CPQXL_OrderSplitCategorytoMainOrderId__c, Map<String, Id>.class);

        Savepoint sp = Database.setSavepoint();
        try{
            Map<Id, SBQQ__Quote__c> oppQuotes = new Map<Id, SBQQ__Quote__c>([
                SELECT Id, ApprovalStatus__c, SBQQ__Status__c, SBQQ__Opportunity2__c, SBQQ__OrderBy__c, SBQQ__Primary__c
                FROM SBQQ__Quote__c WHERE SBQQ__Opportunity2__c = :opportunityId
            ]);

            SBQQ__Quote__c sourceQuote = oppQuotes.get(sourceQuoteId); // the quote that we are deriving a large order from

            // Query existing subset orders already on the opportunity:
            List<Order> existingOrders;
            if(sourceContext == CPQXL_Constants.OPPORTUNITY_OBJ_NAME) { // ordering from Opportunity
                existingOrders = [SELECT Id, SBQQ__Quote__c FROM Order WHERE OpportunityId = :opportunityId];
            } else if(sourceContext == CPQXL_Constants.QUOTE_OBJ_NAME) { // ordering from Quote
                existingOrders = [SELECT Id, SBQQ__Quote__c FROM Order WHERE SBQQ__Quote__c = :sourceQuoteId];
            }

            System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() remainingSubSetQuoteIds 1:' + remainingSubSetQuoteIds);
            System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() existingOrders size:' + existingOrders.size());
            System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() existingOrders:' + existingOrders);

            // Map existing order ids to associated quote ids, so that we can re-establish the relationship later:
            Map<Id, Id> existingOrderIdToSubsetQuoteId = new Map<Id, Id>();
            for(Order order : existingOrders) {
                existingOrderIdToSubsetQuoteId.put(order.Id, order.SBQQ__Quote__c);
            }

            SBQQ__Quote__c subsetQuoteToProcess;
            // if we have remaining subset quotes to process (meaning we need to generate orders for them):
            if(!remainingSubSetQuoteIds.isEmpty()) {
                Id quoteIdToProcess = (new List<Id>(remainingSubSetQuoteIds))[0];

                subsetQuoteToProcess = oppQuotes.get(quoteIdToProcess) == null
                    ? [SELECT Id, SBQQ__Primary__c FROM SBQQ__Quote__c WHERE Id = :quoteIdToProcess] : oppQuotes.get(quoteIdToProcess);

                //We need to temporarily clear the SBQQ__Quote__c and SBQQ__Opportunity fields on the master Order, as to avoid the following managed validation error:
                // 'The primary quote cannot be changed for the opportunity because an order has been created from the quote.'
                existingOrders = handleLookupsOnExistingOrders(existingOrders, null, null, true, true, false);
                System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() existingOrders: ' + existingOrders);

                // manipulate the Primary checkbox on the subset quotes. Each event in the platform event chain will mark a different subset quote as primary:
                togglePrimaryOnQuotes(sourceQuote, subsetQuoteToProcess, oppQuotes);

                // repopulate quote and opp fields on existing orders:
                for(Order order : existingOrders) {
                    order.SBQQ__Quote__c = existingOrderIdToSubsetQuoteId.get(order.Id);
                    order.OpportunityId = opportunityId;
                }
                if(!existingOrders.isEmpty()) {
                    List<Database.SaveResult> saveResults = Database.update(existingOrders, false);

                    Integer saveResultCounter = 0;
                    for(Database.SaveResult saveResult: saveResults) {
                        if (saveResult.isSuccess()) {
                            // Operation was successful, so get the ID of the record that was processed
                            //System.debug('CPQXL_QuoteOrderXLTriggerHandler.handleLookupsOnExistingOrders(): Successfully updated target line item. : ' + saveResult.getId());
                        } else {
                            // Operation failed, so get all errors
                            String errorMessages;
                            Integer i = 0;
                            for (Database.Error err : saveResult.getErrors()) {
                                System.debug('CPQXL_QuoteOrderXLTriggerHandler.processEvents():  The following error has occurred.');
                                System.debug('CPQXL_QuoteOrderXLTriggerHandler.processEvents(): ' + err.getStatusCode() + ': ' + err.getMessage());
                                System.debug('CPQXL_QuoteOrderXLTriggerHandler.processEvents():  fields that affected this error: ' + err.getFields());
                                errorMessages +=  '{' + err.getStatusCode() + ': ' + err.getMessage() + ' : ' + err.getFields() + ' }, ';
                                i++;
                            }
                            CPQU_ErrorLogUtils.createErrorLog('Updating existing orders with the order and opp ids.', EVENT_CLASSNAME,  saveResult.getErrors(), saveResult.getId());
                        }
                        saveResultCounter++;
                    }
                }

                orderOppOrQuote(sourceContext, opportunityId, sourceQuoteId);

                // get the opportunity's most recent orders that were created via the CPQ package, within this event of the platform event chain:
                List<Order> newlyCreatedOrders = processNewlyCreatedOrders(sourceQuote);
                processMainOrders(newlyCreatedOrders);
                Map<Id, Id> subsetOrderIdToMainOrderId = buildSubsetOrderIdToMainOrderId(newlyCreatedOrders);

                CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
                update newlyCreatedOrders; // no need for triggers to run here; we're simply stamping the order(s) with some 'Generate Large Order' applicable field values
                CPQU_BundleStructureUtils.enableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);

                // clone the bundles from the subset orders to the main orders. 
                // The number of order products on each main order will grow in size as the platform event chain progresses.
                Map<Id, OrderItem> subSetBundleOrderProducts = new Map<Id, OrderItem>([
                    SELECT Id FROM OrderItem WHERE SBQQ__RequiredBy__c = NULL AND OrderId IN :newlyCreatedOrders
                ]);
                Set<Id> bundleOrderProductIds = subSetBundleOrderProducts.keySet();
                System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() subSetBundleOrderProducts size: ' + subSetBundleOrderProducts.size());

                CPQU_BundleStructureUtils.ORDER_ITEM_SOURCE_FIELD_REF = 'CPQXL_CloneSourceId__c';
                // Disable Order triggers, and Order Item triggers since we are simply cloning Order Products to the main (large) Order(s).
                // (CPQ and custom Triggers have already run on those Order Products, as well as the Orders):
                CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
                //Map<Id, SObject> orderItemClones = CPQU_BundleStructureUtils.cloneBundles(newlyCreatedOrder.Id, mainOrderId, null, bundleOrderProductIds);
                Map<Id, SObject> orderItemClones = CPQU_BundleStructureUtils.cloneBundles(subsetOrderIdToMainOrderId, bundleOrderProductIds);
                reassignOrderProductQuoteLineFields(orderItemClones);
                CPQU_BundleStructureUtils.enableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
                System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() orderItemClones: ' + orderItemClones);

                //Clone the related lists we know we need. 
                Map<Id, Id> targetXObjectIdToOriginalXObjectId = new Map<Id, Id>();
                for(SObject clonedSObject: orderItemClones.values()) {
                    targetXObjectIdToOriginalXObjectId.put(clonedSObject.Id, (Id) clonedSObject.get(CPQU_BundleStructureUtils.ORDER_ITEM_SOURCE_FIELD_REF));
                    System.debug(LoggingLevel.DEBUG, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() targetXObjectIdToOriginalXObjectId Id: ' + targetXObjectIdToOriginalXObjectId.get(clonedSObject.Id));
                }
                System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() targetXObjectIdToOriginalXObjectId: ' + targetXObjectIdToOriginalXObjectId);

                //clone the PriceSchedules over to the new order products
                CPQU_BundleStructureUtils.cloneRelatedListToXObject('SBQQ__PriceSchedule__c', targetXObjectIdToOriginalXObjectId,  SBQQ__PriceSchedule__c.SBQQ__OrderProduct__c.getDescribe().getSobjectField(),
                    null, null, true);

                //clone the UsageSummaries over to the new order products
                CPQU_BundleStructureUtils.cloneRelatedListToXObject('blng__UsageSummary__c',targetXObjectIdToOriginalXObjectId,  blng__UsageSummary__c.blng__OrderProduct__c.getDescribe().getSobjectField(),
                    subsetOrderIdToMainOrderId, blng__UsageSummary__c.blng__Order__c.getDescribe().getSobjectField(), true);

                // remove the subset quote id here so that the next platform event in the G.L.O. chain processes the next subset quote:
                remainingSubSetQuoteIds.remove(quoteIdToProcess);

                //nextGloEvent.Master_Order_Id__c = mainOrderId; // 
                nextGloEvent.CPQXL_RemainingSubsetQuoteIds__c = JSON.serialize(remainingSubSetQuoteIds); // dynamic
                nextGloEvent.CPQXL_OrderSplitCategorytoMainOrderId__c = JSON.serialize(orderSplitCategoryToMainOrderId); // dynamic

                // publish the next Generate Large Order event in the chain:
                publishNextGloEvent(nextGloEvent);
            } else {
                // we're now done creating the subset orders. perform some final housekeeping items:
                togglePrimaryOnQuotes(sourceQuote, sourceQuote, oppQuotes);
                finishEventChain(existingOrders, sourceQuoteId, opportunityId);
            }
        } catch(Exception e) {
            Id referenceId = sourceContext == CPQXL_Constants.OPPORTUNITY_OBJ_NAME ? opportunityId : sourceQuoteId;
            if(e.getMessage().contains('UNABLE_TO_LOCK_ROW')) {
                Database.rollback(sp);
                CPQU_ErrorLogUtils.createErrorLog(e, EVENT_CLASSNAME + ': failed (UNABLE_TO_LOCK_ROW). Reattempting...', EVENT_CLASSNAME, referenceId);
                publishNextGloEvent(nextGloEvent); // try the same event again in another thread
            } else {
                System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents(): FATAL error occurred: ' + e.getMessage() + '. stack trace: ' + e.getStackTraceString());
                // create an error log record so we can query it from the VFP and show the error on the page:
                CPQU_BundleStructureUtils.disableTriggers(true, oppAndQuoteTriggerHandlersToToggle);
                Database.update(new SBQQ__Quote__c(Id = sourceQuoteId, CPQXL_HeavyProcessingInFlight__c = false), false); // this essentially unlocks the record (since we hit an exception)
                Database.update(new Opportunity(Id = opportunityId, CPQXL_HeavyProcessingInFlight__c = false), false); // this essentially unlocks the record (since we hit an exception)
                CPQU_ErrorLogUtils.createErrorLog(e, EVENT_CLASSNAME + ': failed to generate large order.', EVENT_CLASSNAME_IN_FLIGHT, referenceId);
            }
        }
    }

    /**
     * @description -> Method to initialize the next G.L.O. event in the platform event chain
     * @param currentGloEvent CPQXL_GenerateLargeOrderEvent__e -> the current G.L.O. event (not the next one) in the platform event chain
     * @return CPQXL_GenerateLargeOrderEvent__e nextGloEvent -> the next G.L.O. event to be published.
    **/
    private CPQXL_GenerateLargeOrderEvent__e initializeNextGloEvent(CPQXL_GenerateLargeOrderEvent__e currentGloEvent) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.initializeNextGloEvent()...');
        // Initialize additional Generate Large Quote platform event in memory (do not publish yet, we'll do that later in the execution):
        return new CPQXL_GenerateLargeOrderEvent__e(
            CPQXL_SourceContext__c = currentGloEvent.CPQXL_SourceContext__c, // static per chain
            CPQXL_SourceQuoteId__c = currentGloEvent.CPQXL_SourceQuoteId__c, // static per chain
            CPQXL_OpportunityId__c = currentGloEvent.CPQXL_OpportunityId__c, // static per chain
            CPQXL_RemainingSubsetQuoteIds__c = currentGloEvent.CPQXL_RemainingSubsetQuoteIds__c , // dynamically shrinks as the chain progresses
            CPQXL_OrderSplitCategorytoMainOrderId__c = currentGloEvent.CPQXL_OrderSplitCategorytoMainOrderId__c // dynamic
        );
    }

    /**
     * @description -> Method to publish the next G.L.O. event in the platform event chain
     * return void
    **/
    private void publishNextGloEvent(CPQXL_GenerateLargeOrderEvent__e nextGloEvent) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.publishNextGloEvent()...');

        Long startingTime = System.now().getTime();
        while (System.now().getTime() - startingTime < 500) {
            // Do nothing - workaround for not having a sleep or wait function
        }

        EventBus.publish(nextGloEvent);
    }

    /**
     * @description -> Method to reassign the quote line fields on the subset order products. 
     * This will link the Order Products to their appropriate quote lines on the large quote.
     * @param orderItemClones Map<Id, SObject> -> a map of Order Products in which to update
    **/
    private void reassignOrderProductQuoteLineFields(Map<Id, SObject> orderItemClones) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.reassignOrderProductQuoteLineFields()...');
        List<OrderItem> orderItemsWithRelated = [
            SELECT Id, SBQQ__QuoteLine__r.SBQQ__Source__c FROM OrderItem WHERE Id IN :orderItemClones.keySet()
        ];

        for(OrderItem orderItem : orderItemsWithRelated) {
            orderItem.SBQQ__QuoteLine__c = orderItem.SBQQ__QuoteLine__r.SBQQ__Source__c;
        }

        if(!orderItemsWithRelated.isEmpty()) {
            update orderItemsWithRelated;
        }
    }

    /**
     * @description -> toggle nulling out vs populating the SBQQ__Quote__c and OpportunityId fields on Orders
     * @param existingOrders List<Order>
     * @param opportunityId Id
     * @param quoteId Id
     * @param updateOppField Boolean
     * @param updateQuoteField Boolean
     * @param updateHeavyFlightField Boolean
     * @return existingOrders List<Order> -> the list of existing orders updated
    **/
    private List<Order> handleLookupsOnExistingOrders(List<Order> existingOrders, Id opportunityId, Id quoteId, Boolean updateOppField, Boolean updateQuoteField, Boolean updateHeavyFlightField) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.handleLookupsOnExistingOrders()...');

        CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
        for(Order order : existingOrders) {
            if(updateOppField) {
                order.OpportunityId = opportunityId;
            }
            if(updateQuoteField) {
                order.SBQQ__Quote__c = quoteId;
            }
            if(updateHeavyFlightField) {
                order.CPQXL_HeavyProcessingInFlight__c = false;
            }
        }

        if(!existingOrders.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.update(existingOrders, false);

            Integer saveResultCounter = 0;
            for(Database.SaveResult saveResult: saveResults) {
                if (saveResult.isSuccess()) {
                    // Operation was successful, so get the ID of the record that was processed
                    //System.debug('CPQXL_QuoteOrderXLTriggerHandler.handleLookupsOnExistingOrders(): Successfully updated target line item. : ' + saveResult.getId());
                } else {
                    // Operation failed, so get all errors
                    String errorMessages;
                    Integer i = 0;
                    for (Database.Error err : saveResult.getErrors()) {
                        System.debug('CPQXL_QuoteOrderXLTriggerHandler.handleLookupsOnExistingOrders():  The following error has occurred.');
                        System.debug('CPQXL_QuoteOrderXLTriggerHandler.handleLookupsOnExistingOrders(): ' + err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('CPQXL_QuoteOrderXLTriggerHandler.handleLookupsOnExistingOrders():  fields that affected this error: ' + err.getFields());
                        errorMessages +=  '{' + err.getStatusCode() + ': ' + err.getMessage() + ' : ' + err.getFields() + ' }, ';
                        i++;
                    }
                    CPQU_ErrorLogUtils.createErrorLog('handleLookupsOnExistingOrders ', EVENT_CLASSNAME,  saveResult.getErrors(), saveResult.getId());
                }
                saveResultCounter++;
            }

        }
        CPQU_BundleStructureUtils.enableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
        return existingOrders;
    }

    /**
     * @description -> method to toggle the primary checkbox on the subset (smaller) quotes
     * @param sourceQuote SBQQ__Quote__c -> the large quote we are deriving a large order from
     * @param subsetQuoteToProcess SBQQ__Quote__c -> the subset (smaller) quote we are processing within this event in the platform event chain
     * @param oppQuotes Map<Id, SBQQ__Quote__c> -> all quotes on the opportunity
    **/
    private void togglePrimaryOnQuotes(SBQQ__Quote__c sourceQuote, SBQQ__Quote__c subsetQuoteToProcess, Map<Id, SBQQ__Quote__c> oppQuotes) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.togglePrimaryOnQuotes() subsetQuoteToProcess: ' + subsetQuoteToProcess);
        // Mark the subset quote as primary so we can generate order products for its quote lines:
        if(!subsetQuoteToProcess.SBQQ__Primary__c) {
            subsetQuoteToProcess.SBQQ__Primary__c = true;
            subsetQuoteToProcess.ApprovalStatus__c = sourceQuote.ApprovalStatus__c; // IB Specific
            subsetQuoteToProcess.SBQQ__Status__c = sourceQuote.SBQQ__Status__c; // IB Specific
            SBQQ.TriggerControl.disable(); // prevent recalc on the quote
            // with triggers disabled (to avoid recalc), we need to ensure all the other quotes are not marked primary,
            // or else we get the following error when attempting to create the order:
            // 'Opportunity must have a primary quote in order to create an order.'
            List<SBQQ__Quote__c> quotesToTogglePrimary = new List<SBQQ__Quote__c>();
            for(SBQQ__Quote__c oppQuote : oppQuotes.values()) {
                if(oppQuote.Id != subsetQuoteToProcess.Id && oppQuote.SBQQ__Primary__c == true) {
                    oppQuote.SBQQ__Primary__c = false;
                    quotesToTogglePrimary.add(oppQuote);
                }
            }
            quotesToTogglePrimary.add(subsetQuoteToProcess);
            update quotesToTogglePrimary;
            update new Opportunity(Id = opportunityId, SBQQ__PrimaryQuote__c = subsetQuoteToProcess.Id);
            SBQQ.TriggerControl.enable();
        }
    }

    /**
     * @description -> method to to process orders created by the CPQ package
     * @param sourceQuote SBQQ__Quote__c -> the large quote we are deriving a large order from
     * @return List<Order> newlyCreatedOrders -> the processed newly created orders
    **/
    private List<Order> processNewlyCreatedOrders(SBQQ__Quote__c sourceQuote) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processNewlyCreatedOrders() sourceQuote: ' + sourceQuote);
        // get the opportunity's most recent orders that were created via the CPQ package, within the event chain and within the last 5 minutes
        // sort by most recently created to oldest. CPQXL_GenerateLargeOrderApplicable__c will be false until later in the execution.
        // this will in most cases only have one order returned. However, for the SBQQ__OrderBy__c (order split) use cases, multiple orders will be returned:
        String orderSplitFieldAPIName = sourceQuote.SBQQ__OrderBy__c;
        String quoteLineOrderSplitField = 'SBQQ__QuoteLine__r.' + orderSplitFieldAPIName;
        String orderQuery = 'SELECT Id, CPQXL_OrderSplitCategory__c ';
        Datetime fiveMinutesAgo = (System.now() - 0.003454);
        if(orderSplitFieldAPIName != null) {
            // conditionally query order products for order split scenarios:
            orderQuery += ', (SELECT ' + quoteLineOrderSplitField + ' FROM OrderItems WHERE SBQQ__QuoteLine__c != null) ';
        }
        orderQuery += 'FROM Order ';
        orderQuery += 'WHERE OpportunityId = :opportunityId AND CPQXL_GenerateLargeOrderApplicable__c = false AND CreatedDate > :fiveMinutesAgo ORDER BY CreatedDate DESC';

        // get the orders that were created by OOB CPQ, on the opportunity/quote:
        List<Order> newlyCreatedOrders = Database.query(orderQuery);
        // loop through and map order split category from order product's quote line, to the order itself:
        for(Order newlyCreatedOrder : newlyCreatedOrders) {
            if(newlyCreatedOrders.size() > 1) { // newlyCreatedOrders will be greater than 1 in size, when SBQQ__OrderBy__c drives an order split via OOB CPQ.
                if(newlyCreatedOrder.OrderItems != null && !newlyCreatedOrder.OrderItems.isEmpty()) {
                    SBQQ__QuoteLine__c quoteLineOfFirstOrderItem = newlyCreatedOrder.OrderItems[0].SBQQ__QuoteLine__r;
                    String orderSplitCategory = quoteLineOfFirstOrderItem.get(orderSplitFieldAPIName) == null
                        ? 'placeholder' : String.valueOf(quoteLineOfFirstOrderItem.get(orderSplitFieldAPIName));

                    newlyCreatedOrder.CPQXL_OrderSplitCategory__c = orderSplitCategory;
                } else {
                    newlyCreatedOrder.CPQXL_OrderSplitCategory__c = 'placeholder';
                }
            } else {
                newlyCreatedOrder.CPQXL_OrderSplitCategory__c = 'placeholder';
            }
            newlyCreatedOrder.CPQXL_GenerateLargeOrderApplicable__c = true;
            newlyCreatedOrder.CPQXL_HeavyProcessingInFlight__c = true;
        }

        CPQU_BundleStructureUtils.disableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);
        update newlyCreatedOrders; // no need for triggers to run here; we're simply stamping the order(s) with some 'Generate Large Order' applicable field values
        CPQU_BundleStructureUtils.enableTriggers(true, orderAndOrderItemTriggerHandlersToToggle);

        return newlyCreatedOrders;
    }

    /**
     * @description -> method to process the main (aka large) orders. In cases of OOB order split, there will be multiple orders for the
     *  Generate Large Order process, else there will only be one main (aka large) order with all the order products derived from the primary quote.
     * @param newlyCreatedOrders List<Order> -> orders created by the CPQ package in this event of the platform event chain
     * @return List<Order> mainOrders -> the processed main orders
    **/
    private List<Order> processMainOrders(List<Order> newlyCreatedOrders) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processMainOrders() newlyCreatedOrders: ' + newlyCreatedOrders);
        List<Order> mainOrders = new List<Order>();
        for(Order newlyCreatedOrder : newlyCreatedOrders) {
            // If we have yet to create the main (large) order for a particular order split category, create a main (large) order for that category.
            // Later we will route clone order products to their respective main Orders using the category as a means to route.
            if(!orderSplitCategoryToMainOrderId.containsKey(newlyCreatedOrder.CPQXL_OrderSplitCategory__c)) {
                Order mainOrder = ((Order) CPQU_BundleStructureUtils.cloneXObjectHeader(newlyCreatedOrder.Id, false /*doInsert*/));
                mainOrder.CPQXL_GenerateLargeOrderApplicable__c = true;
                mainOrders.add(mainOrder);
            }
        }
        if(!mainOrders.isEmpty()) {
            insert mainOrders;
            for(Order mainOrder : mainOrders) {
                mainOrder.SBQQ__Quote__c = sourceQuoteId; // assign the large quote to what will soon be the large order
                mainOrder.CPQXL_HeavyProcessingInFlight__c = true;
                mainOrder.CPQXL_IsSubset__c = false;
                mainOrder.SBQQ__PriceCalcStatus__c = 'Completed';
                orderSplitCategoryToMainOrderId.put(mainOrder.CPQXL_OrderSplitCategory__c, mainOrder.Id);
            }
            update mainOrders;
        }
        return mainOrders;
    }

    /**
     * @description -> method to map subset (smaller) order id to main (aka large) order id:
     * @param newlyCreatedOrders List<Order>  -> orders created by OOB CPQ in this event within the platform event chain
     * @return Map<Id, Id> subsetOrderIdToMainOrderId -> a map of subset (smaller) order ids to main (aka large) order ids:
    **/
    private Map<Id, Id> buildSubsetOrderIdToMainOrderId(List<Order> newlyCreatedOrders) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.buildSubsetOrderIdToMainOrderId() newlyCreatedOrders: ' + newlyCreatedOrders);
        Map<Id, Id> subsetOrderIdToMainOrderId = new Map<Id, Id>();
        for(Order newlyCreatedOrder : newlyCreatedOrders) {
            // get the main order for the newly created order's order split category. If SBQQ__OrderBY__c is not
            // populated on the quote, then there will only be 1 category
            Id mainOrderId = orderSplitCategoryToMainOrderId.get(newlyCreatedOrder.CPQXL_OrderSplitCategory__c);
            newlyCreatedOrder.CPQXL_LargeOrderId__c = mainOrderId;
            subsetOrderIdToMainOrderId.put(newlyCreatedOrder.Id, mainOrderId);
        }
        return subsetOrderIdToMainOrderId;
    }

    /**
     * @description -> method to order an Opportunity or Quote
     * @param sourceContext String -> whether we are ordering from Opportunity or Quote
     * @param opportunityId Id -> Id of the Opportunity (applicable if we are ordering from Opportunity)
     * @param sourceQuoteId Id -> Id of the Quote (applicable if we are ordering from Quote)
    **/
    private void orderOppOrQuote(String sourceContext, Id opportunityId, Id sourceQuoteId) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.orderOppOrQuote() sourceQuoteId: ' + sourceQuoteId + ' sourceContext: ' + sourceContext);
        SObject oppOrQuote;
        if(sourceContext == CPQXL_Constants.OPPORTUNITY_OBJ_NAME) { // ordering from Opportunity
            Opportunity opportunity = new Opportunity(Id = opportunityId, SBQQ__Ordered__c = false);
            oppOrQuote = (Opportunity) opportunity;
        } else if(sourceContext == CPQXL_Constants.QUOTE_OBJ_NAME) { // ordering from Quote
            SBQQ__Quote__c quote = new SBQQ__Quote__c(Id = sourceQuoteId, SBQQ__Ordered__c = false);
            oppOrQuote = (SBQQ__Quote__c) quote;
        }

        // unmark the Ordered Checkbox on the Opportunity (or quote, depending on context):
        update oppOrQuote;
        // mark the Ordered Checkbox on the Opportunity (or quote, depending on context), so that CPQ generates a subset Order for it:
        oppOrQuote.put('SBQQ__Ordered__c', true);
        // disable custom opp and quote triggers while leaving CPQ managed triggers enabled.
        // we don't want all the custom order functionality running for the subset orders (ex: flatten lines, Order Acknowledgement, Shipping notification, etc)
        CPQU_BundleStructureUtils.disableTriggers(false, oppAndQuoteTriggerHandlersToToggle);
        update oppOrQuote;
        CPQU_BundleStructureUtils.enableTriggers(false, oppAndQuoteTriggerHandlersToToggle);
    }

    /**
     * @description -> method to finish up the G.L.O. event chain. 
     * Notes: this method will mark the source quote as primary (like it was originally) and assign the primary quote back to the opportunity.
     *  This method will also populate the SBQQ__Quote__c and OpportunityId lookups on the subset orders, as well as unflag the quote and opportunity
     *  from being in-flight so they can be edited by the user again.
     * @param existingOrders -> orders residing on the opportunity. At this point, the opportunity will contain all the subset (smaller orders) and main (large) orders
     * @param sourceQuoteId -> Id of the source quote in which we're deriving large order(s) for
     * @param opportunityId -> Id of the source quote's opportunity
    **/
    private void finishEventChain(List<Order> existingOrders, Id sourceQuoteId, Id opportunityId) {
        System.debug(LoggingLevel.WARN, 'CPQXL_QuoteOrderXLTriggerHandler.processEvents() done creating subset orders... performing final operations.');
        // Temporarily null the opportunity to prevent CPQ managed package validation errors
        //existingOrders = handleLookupsOnExistingOrders(existingOrders, null, null, true, false);

        /*SBQQ.TriggerControl.disable(); // prevent recalc on the quote
        // set the source quote back to the primary quote:
        update new SBQQ__Quote__c(Id = sourceQuoteId, SBQQ__Primary__c = true);
        update new Opportunity(Id = opportunityId, SBQQ__PrimaryQuote__c = sourceQuoteId);
        SBQQ.TriggerControl.enable();*/

        // repopulate opportunity id on the subset orders and large order
        existingOrders = handleLookupsOnExistingOrders(existingOrders, opportunityId, null, true, false, true);

        CPQU_BundleStructureUtils.disableTriggers(true, oppAndQuoteTriggerHandlersToToggle);
        update new SBQQ__Quote__c(Id = sourceQuoteId, CPQXL_HeavyProcessingInFlight__c = false);
        update new Opportunity(Id = opportunityId, CPQXL_HeavyProcessingInFlight__c = false);
        CPQU_BundleStructureUtils.enableTriggers(true, oppAndQuoteTriggerHandlersToToggle);
    }
}
