/**
 * Title: CPQU_BundleStructureUtils
 * Purpose: utility class to gather extended information about Contracts and/or Quotes/ and/or Orders including their bundle structure.
 * 
 * This class is essentially a better version of the LineNumberPatcher class. 
 *
 * Notes on variables:
 *  xObject means a high level object such as Contract, Quote, or Order.
 *  yObject means a lower level object such as Asset, Subscription, Quote Line, or Order Product
 *
 * TODO: Accomodate for if the developer/user wants to track the source on Asset and Subscription. 
 *
 *
 * Created by : Kevin Antonioli : 05.09.2019
**/
public without sharing class CPQU_BundleStructureUtils {
    private static final String CONTRACT_STR = 'Contract';
    private static final String SUBSCRIPTION_CONTRACT_ID_FIELD_REF = 'SBQQ__Contract__c';
    private static final String QUOTE_FIELD_REF = 'SBQQ__Quote__c';
    private static final String QUOTE_OBJ_TYPE_STR = 'SBQQ__Quote__c';
    private static final String QUOTE_SOURCE_FIELD_REF = 'SBQQ__Source__c';
    private static final String QUOTELINE_SOURCE_FIELD_REF = 'SBQQ__Source__c';
    private static final String QUOTE_PRIMARY_FIELD = 'SBQQ__Primary__c';
    
    private static final String ORDER_STR = 'Order';
    private static final String ORDER_ID_FIELD_REF = 'OrderId';
    private static final String ID_STR = 'Id';
    private static final String ASSET_OBJ_TYPE_STR = 'Asset';
    private static final String SUBSCRIPTION_OBJ_TYPE_STR = 'SBQQ__Subscription__c';
    private static final String ORDERITEM_OBJ_TYPE_STR = 'OrderItem';

    private static final String PRODUCT2_STANDARD_FIELD_REF = 'Product2';
    private static final String QUOTELINE_OBJ_NAME_STR = 'SBQQ__QuoteLine__c';
    private static final String QUOTELINE_GROUP_FIELD_REF = 'SBQQ__Group__c';
    private static final String PRODUCT2_CPQ_RELATIONSHIP = 'SBQQ__Product__r';

    private static final String REQUIRED_BY_FIELD_REF = 'SBQQ__RequiredBy__c';
    private static final String REQUIRED_BY_ID_FIELD_REF = 'SBQQ__RequiredById__c';
    private static final String REQUIRED_BY_ASSET_FIELD_REF = 'SBQQ__RequiredByAsset__c';
    private static final String REQUIRED_BY_SUB_FIELD_REF = 'SBQQ__RequiredBySubscription__c';
    private static final String ROOT_ID_FIELD_REF = 'SBQQ__RootId__c';
    private static final String BUNDLE_ROOT_FIELD_REF = 'SBQQ__BundleRoot__c';
    private static final String SBQQNUMBER_FIELD_REF = 'SBQQ__Number__c';
    private static final String COMBINE_KEY_FIELD_REF = 'SBQQ__CombineKey__c';
    private static final String ROOT_ASSET_FIELD_REF = 'SBQQ__RootAsset__c';
    private static final String STANDARD_ACCOUNT_FIELD_REF = 'AccountId';
    private static final String CPQ_ACCOUNT_FIELD_REF = 'SBQQ__Account__c';
    private static final String STANDARD_QUANTITY_FIELD_REF = 'Quantity';
    private static final String CPQ_QUANTITY_FIELD_REF = 'SBQQ__Quantity__c';

    private static final String NEW_QTY_MAPKEY = '*newQuantity';
    private static final String DECOMMISSIONED_QTY_MAPKEY = '*decommissionedQuantity';

    // Note: be careful as to not put too many Ids into xObjectIdSet as to avoid the 50000 query row limit.
    public static Set<Id> xObjectIdSet = new Set<Id>();
    public static Set<Id> subscriptionIdSet = new Set<Id>();
    public static Set<Id> requiredByIdSet = new Set<Id>();
    // optionally populate Ids of lines into the following Set, from the class using CPQU_BundleStructureUtils,
    // to tell CPQU_BundleStructureUtils to query certain lines:
    public static Set<Id> linesToQuery = new Set<Id>(); 

    public static Map<Id, XObjectData> xObjectIdTo_xObjectDataMap = new Map<Id, XObjectData>();
    public static Map<Id, YObjectInfo> yObjectIdTo_yObjectInfoMap = new Map<Id, YObjectInfo>();
    public static Map<Id, Id> topBundleIdToMasterParentIdMap = new Map<Id, Id>();
    public static Map<Integer, Set<Id>> bundleAggregationsMapStatic = new Map<Integer, Set<Id>>();

    // maps to aid in cloning:
    public static Map<String, SObject> sourceLineIdToClonedLine = new Map<String, SObject>();
    public static Map<Id, SBQQ__QuoteLineGroup__c> sourceQlGroupIdToQlGroupClone = new Map<Id, SBQQ__QuoteLineGroup__c>();

    // set these 'reduce heap' variables to false, from the source code calling this class, if you need to query all fields (ex: cloning:)
    public static Boolean reduceSubscriptionHeap = true;
    public static Boolean reduceAssetHeap = true;
    public static Boolean reduceQuoteLineHeap = true;
    public static Boolean reduceOrderProductHeap = true;

    public static Map<Id, SObject> yObjectMap = new Map<Id, SObject>();
    public static Schema.SObjectField subGroupingField = SBQQ__Subscription__c.SBQQ__Contract__c.getDescribe().getSobjectField();
    public static Schema.SObjectField quoteLineGroupingField = SBQQ__QuoteLine__c.SBQQ__Quote__c.getDescribe().getSobjectField();
    public static Schema.SObjectField orderProductGroupingField = OrderItem.OrderId.getDescribe().getSobjectField();

    public static String ORDER_ITEM_SOURCE_FIELD_REF;
    public static Boolean assetsAccrued = false;

    // Constructor:
    public CPQU_BundleStructureUtils() {
        
    }

    /**
     * @description: Method to disable desired triggers.
     * @param Boolean disableCPQTriggers -> whether to disable CPQ triggers
     * @param Set<String> customTriggerHandlerName -> a set of custom trigger handlers to disable
     */
    public static void disableTriggers(Boolean disableCPQTriggers, Set<String> customTriggerHandlerNames) {
        if(disableCPQTriggers) {
            SBQQ.TriggerControl.disable();
        }
        if(customTriggerHandlerNames != null) {
            for(String customTriggerHandlerName : customTriggerHandlerNames) {
                CPQU_TriggerHandler.bypass(customTriggerHandlerName);
            }
        }
    }

    /**
     * @description: Method to enable desired triggers.
     * @param Boolean enableCPQTriggers -> whether to enable CPQ triggers
     * @param Set<String> customTriggerHandlerName -> a set of custom trigger handlers to enable
     */
    public static void enableTriggers(Boolean enableCPQTriggers, Set<String> customTriggerHandlerNames) {
        if(enableCPQTriggers) {
            SBQQ.TriggerControl.enable();
        }
        if(customTriggerHandlerNames != null) {
            for(String customTriggerHandlerName : customTriggerHandlerNames) {
                CPQU_TriggerHandler.clearBypass(customTriggerHandlerName);
            }
        }
    }

    /**
     * @description: Method to tell the line queries to query all fields on those lines.
     * @param null
     */
    public static void signalToQueryAllLineFields() {
        reduceAssetHeap = false;
        reduceSubscriptionHeap = false;
        reduceQuoteLineHeap = false;
        reduceOrderProductHeap = false;
    }

    /**
     * @description: Method to build query string for Subscriptions:
     * @param Boolean reduceSubscriptionHeapParam -> whether or not to query the essential Subscription managed fields vs EVERY Subscription field.
     * @return String -> a query string for Subscriptions. Could be the essential managed fields in this query, or EVERY field, depending on the reduceSubscriptionHeapParam param.
     */
    public static String getDynamicSubscriptionQueryString(Boolean reduceSubscriptionHeapParam) {
        String subscriptionBaseQueryStrReduced = 'SELECT Id, Name, SBQQ__Quantity__c, SBQQ__QuoteLine__c, SBQQ__RootId__c, SBQQ__RenewalQuantity__c, ' +
            'SBQQ__Account__c, SBQQ__TerminatedDate__c, SBQQ__RequiredById__c, SBQQ__Contract__c, SBQQ__Number__c, SBQQ__RenewedDate__c, SBQQ__OrderProduct__c';
        
        String subscriptionBaseQueryStr = !reduceSubscriptionHeapParam ? 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('SBQQ__Subscription__c') : subscriptionBaseQueryStrReduced;
        String additionalSubFields = ', SBQQ__Product__r.Name ';
        additionalSubFields += ', SBQQ__QuoteLine__r.SBQQ__Source__c ';

        if(ORDER_ITEM_SOURCE_FIELD_REF != null) {
            additionalSubFields += ', SBQQ__OrderProduct__r.' + ORDER_ITEM_SOURCE_FIELD_REF;
        }

        String subscriptionEndOfQueryString = ' FROM SBQQ__Subscription__c WHERE SBQQ__Contract__c IN :xObjectIdSet ORDER BY CreatedDate';
        return subscriptionBaseQueryStr + additionalSubFields + subscriptionEndOfQueryString;
    }

    /**
     * @description: Method to build query string for assets:
     * @param Boolean reduceAssetHeapParam -> whether or not to query the essential asset managed fields vs EVERY asset field.
     * @return String -> a query string for assets. Could be the essential managed fields in this query, or EVERY field, depending on the reduceAssetHeap param.
     */
    public static String getDynamicAssetQueryString(Boolean reduceAssetHeapParam) {
        String assetBaseQueryStrReduced = 'SELECT Id, AccountId, Quantity, SBQQ__RootAsset__c, SBQQ__QuoteLine__c, SBQQ__LatestQuoteLine__c, SBQQ__RequiredByAsset__c, ' +
        ' SBQQ__RootId__c, SBQQ__RequiredById__c, SBQQ__Number__c, SBQQ__OrderProduct__c';

        String assetBaseQueryStr = !reduceAssetHeapParam 
            ? 'SELECT ' + CPQU_ApexUtils.getAllFieldsExceptBlacklistAsStr('Asset', CPQU_Constants.assetQueryBlacklistFields) : assetBaseQueryStrReduced;

        String additionalAssetFieldsStr = ', SBQQ__RequiredByAsset__r.SBQQ__RequiredByAsset__c, Product2.Name, ' +
            'SBQQ__CurrentSubscription__r.SBQQ__Contract__c, ' +
            'SBQQ__RequiredBySubscription__r.SBQQ__Contract__c, ' +
            'SBQQ__RequiredByAsset__r.SBQQ__CurrentSubscription__c, ' +
            'SBQQ__RequiredByAsset__r.SBQQ__CurrentSubscription__r.SBQQ__Contract__c, ' +
            'SBQQ__QuoteLine__r.SBQQ__Source__c, SBQQ__LatestQuoteLine__r.SBQQ__Source__c ';

        if(ORDER_ITEM_SOURCE_FIELD_REF != null) {
            additionalAssetFieldsStr += ', SBQQ__OrderProduct__r.' + ORDER_ITEM_SOURCE_FIELD_REF;
        }

        String assetEndOfQueryString = '' +
            ' FROM Asset WHERE (SBQQ__CurrentSubscription__c IN :subscriptionIdSet OR Id IN :requiredByIdSet OR SBQQ__RequiredBySubscription__c IN :subscriptionIdSet) ORDER BY CreatedDate' +
        '';
        return assetBaseQueryStr + additionalAssetFieldsStr + assetEndOfQueryString;
    }

    /**
     * @description: Method to build query string for quote lines:
     * @param Boolean reduceQuoteLineHeapParam -> whether or not to query the essential quote line managed fields vs EVERY quote line field.
     * @return String -> a query string for quote line. Could be the essential managed fields in this query, or EVERY field, depending on the reduceQuoteLineHeapParam param.
     */
    public static String getDynamicQuoteLineQueryString(Boolean reduceQuoteLineHeapParam) {
        String quoteLineBaseQueryStrReduced = 'SELECT Id, SBQQ__Quote__c, SBQQ__RequiredBy__c, SBQQ__Number__c ';
        String quoteLineBaseQueryStr = !reduceQuoteLineHeapParam ? 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('SBQQ__QuoteLine__c') : quoteLineBaseQueryStrReduced;
        String additionalQuoteLineFieldsStr = ', SBQQ__RenewedSubscription__r.SBQQ__Contract__c, SBQQ__Product__r.Name'; // specify additional fields in this variable if desired.
        String quoteLineEndOfQueryStr = linesToQuery.isEmpty() 
            ? ' FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :xObjectIdSet ORDER BY SBQQ__Number__c '
            : ' FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c IN :xObjectIdSet AND Id IN :linesToquery ORDER BY SBQQ__Number__c ';
        
        return quoteLineBaseQueryStr + additionalQuoteLineFieldsStr + quoteLineEndOfQueryStr;
    }

    /**
     * @description: Method to build query string for Order Products:
     * @param Boolean reduceOrderProductHeapParam -> whether or not to query the essential Order Product managed fields vs EVERY Order Product field.
     * @return String -> a query string for Order Products. Could be the essential managed fields in this query, or EVERY field, depending on the reduceOrderProductHeapParam param.
     */
    public static String getDynamicOrderProductQueryString(Boolean reduceOrderProductHeapParam) {
        String orderProductBaseQueryStrReduced = 'SELECT Id, SBQQ__BundleRoot__c, SBQQ__RequiredBy__c ';
        String orderProductBaseQueryStr = !reduceOrderProductHeapParam ? 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('OrderItem') : orderProductBaseQueryStrReduced;
        String additionalOrderProductFieldsStr = ', Product2.Name, Order.SBQQ__Quote__c, SBQQ__QuoteLine__r.SBQQ__RenewedSubscription__r.SBQQ__Contract__c '; // specify additional fields in this variable if desired.
        String orderProductEndOfQueryStr = (linesToQuery ==null || linesToQuery.isEmpty()) 
            ? ' FROM OrderItem WHERE OrderId IN :xObjectIdSet ORDER BY CreatedDate '
            : ' FROM OrderItem WHERE OrderId IN :xObjectIdSet AND Id IN :linesToquery ORDER BY CreatedDate ';

        return orderProductBaseQueryStr + additionalOrderProductFieldsStr + orderProductEndOfQueryStr;
    }

    /**
     * Inner class to store an extended version of the contract (or Quote or Order) data, including its bundle structure.
     * Be careful not to construct too many of these objects, as to avoid query row limits.
     */
    public class XObjectData {
        public Id xObjectId; // the Id of the Contract or Quote or Order that is being passed into this class.
        public String xObjectType; // the object type pertaining to the Id param we pass to this inner class.
        public BundleStructure xObjectBundleStructure; // bundle structure info
        public List<SBQQ__Subscription__c> subscriptions; // subscriptions on the contract
        public List<Asset> assets; // assets related to contract
        public List<SBQQ__QuoteLine__c> quoteLines; // quote lines related to quote
        public List<OrderItem> orderProducts; // Order products related to quote
        public List<SObject> yObjectsList; // subscriptions and assets related to contract, quote lines related to quote, or order products related to order
        public Boolean hasBundleStructureIssues = false;

        public XObjectData(Id xObjectIdParam) {
            xObjectIdSet.add(xObjectIdParam);
            this.xObjectId = xObjectIdParam;
            this.xObjectType = String.valueOf(xObjectIdParam.getSobjectType());
            if(xObjectType != CONTRACT_STR && xObjectType != QUOTE_FIELD_REF && xObjectType != ORDER_STR) {
                StringException e = new StringException();
                e.setMessage('The object type for the Id passed to XObjectData is not a Contract, SBQQ__Quote__c, or Order. It must be one of those three.');
                throw e;
            }

            this.xObjectBundleStructure = getxObjectBundleStructure(xObjectIdParam, xObjectType);
            if(this.xObjectBundleStructure != null) {
                this.subscriptions = this.xObjectBundleStructure.subscriptions;
                this.assets = this.xObjectBundleStructure.assets;
                this.quoteLines = this.xObjectBundleStructure.quoteLines;
                this.orderProducts = this.xObjectBundleStructure.orderProducts;
                this.yObjectsList = this.xObjectBundleStructure.yObjectsList;
            } else {
                this.hasBundleStructureIssues = true;
            }
        }
    }

    /**
     * @description: method to populate a map of xObjectIds (ex: Contract, Quote, Order) to associated xObjectData.
     * @param Set<Id> xObjectIdSetParam -> ids of XObjects in which to build the data structures for
     * @return void
     */
    public static void populateXObjectDataMap(Set<Id> xObjectIdSetParam) {
        xObjectIdSet.addAll(xObjectIdSetParam);
        for(Id xObjectId : xObjectIdSetParam) {
            XObjectData xobjectData = getXObjectData(xObjectId);
        }

        System.debug('CPQU_BundleStructureUtils.populateXObjectDataMap: xObjectIdTo_xObjectDataMap' + xObjectIdTo_xObjectDataMap);
    }

    /**
     * @description: method to build an XObject data structure (given an XObject Id). 
     *  Note: The data structure is built if it does not already exist in the xObjectIdTo_xObjectDataMap.
     * @param Id xObjectIdParam -> the id in which to build the XObject data structure for (if it doesn't already exist in the xObjectIdTo_xObjectDataMap)
     * @param (optional) rebuildXObjectData -> optionally specify whether or not to RE-build the XObject data structure for the given id passed in the params
     * @return XObjectData -> the XObject data structure for the id specified in the params
     */
    public static XObjectData getXObjectData(Id xObjectIdParam) {
        return(getXObjectData(xObjectIdParam, false));
    }
    public static XObjectData getXObjectData(Id xObjectIdParam, Boolean rebuildXObjectData) {
        xObjectIdSet.add(xObjectIdParam);
        XObjectData xObjectData = (!xObjectIdTo_xObjectDataMap.containsKey(xObjectIdParam) || rebuildXObjectData)
            ? new XObjectData(xObjectIdParam) : xObjectIdTo_xObjectDataMap.get(xObjectIdParam);

        if(!xObjectIdTo_xObjectDataMap.containsKey(xObjectIdParam)) {
            xObjectIdTo_xObjectDataMap.put(xObjectIdParam, xObjectData);
        }

        return xObjectData;
    }
    
    // Variable to get subscriptions on a set of contracts.
    // Note: we're not using Contract query with embedded subscription subquery because subscriptions' covered assets do not have 
    //   a direct linkage to contract.
    // Note: be careful as to not put too many Ids into xObjectIdSet as to avoid the 50000 query row limit.
    public static Map<Id, SBQQ__Subscription__c> contractSubsMap {
        get {
            if(contractSubsMap == null) {
                contractSubsMap = new Map<Id, SBQQ__Subscription__c>((List<SBQQ__Subscription__c>)Database.query(getDynamicSubscriptionQueryString(reduceSubscriptionHeap)));
                subscriptionIdSet.addAll(contractSubsMap.keySet());
                for(SBQQ__Subscription__c subscription : contractSubsMap.values()) {
                    requiredByIdSet.add(subscription.SBQQ__RequiredById__c);
                }
                yObjectMap.putAll(contractSubsMap);
            }
            return contractSubsMap;
        }
        set;
    }
    
    // get assets that are somehow related to the subscriptions above.
    // Note: we're not using Contract query with embedded asset subquery because the subscriptions' assets do not have
    //   a direct linkage to contract
    // Note: be careful as to not put too many Ids into xObjectIdSet as to avoid the 50000 query row limit.
    private static Map<Id, Asset> relatedAssetsMap {
        get {
           if(relatedAssetsMap == null) {
                Set<Id> accountIds = new Set<Id>();
                for(SBQQ__Subscription__c subscription : contractSubsMap.values()) {
                    accountIds.add(subscription.SBQQ__Account__c);
                }

                relatedAssetsMap = new Map<Id, Asset>((List<Asset>)Database.query(getDynamicAssetQueryString(reduceAssetHeap)));
                System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.relatedAssetsMap: ' + JSON.serialize(relatedAssetsMap));
                yObjectMap.putAll(relatedAssetsMap);
                assetsAccrued = true;
            }
            return relatedAssetsMap;
        }
        set;
    }

    // variable to build map of contract id to list of subscriptions (only applies to renewals)
    public static Map<String, List<SBQQ__Subscription__c>> contractIdToSubsMap {
        get {
            if(contractIdToSubsMap == null) {
                contractIdToSubsMap = CPQU_ApexUtils.groupBy(contractSubsMap.values(), subGroupingField);
            }
            return contractIdToSubsMap;
        }
        set;
    }

    // variable to build a map of contract id to associated list of assets (only applies to renewals)
    // Note: assets do not have a direct linkage to Contract like subscriptions do, so building this map is more difficult:
    public static Map<String, List<Asset>> contractIdToAssetsMap {
        get {
            if(contractIdToAssetsMap == null) {
                contractIdToAssetsMap = new Map<String, List<Asset>>();

                if(!assetsAccrued) {
                    yObjectMap.putAll(relatedAssetsMap);
                }

                  // loop through the contracts' subscriptions and get the extended Info for each subscription (while building a few key maps):
                for(SBQQ__Subscription__c subscription : contractSubsMap.values()) {
                    YObjectInfo yObjectInfo = getYObjectInfo(subscription);
                    if(yObjectInfo != null) {
                        yObjectIdTo_yObjectInfoMap.put(yObjectInfo.recordId, yObjectInfo);
                    }
                }

                // gather assets to put in the map, in which the assets are a direct or indirect child of a subscription:
                for(Asset asset : relatedAssetsMap.values()) {
                    Id contractId = findContractIdForAsset(asset);
                    if(contractId != null) {
                        List<Asset> contractAssets = contractIdToAssetsMap.get(contractId) == null ? new List<Asset>() : contractIdToAssetsMap.get(contractId);
                        contractAssets.add(asset);
                        contractIdToAssetsMap.put(contractId, contractAssets);
                    }
                }
            }
            System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.contractIdToAssetsMap.size(): ' + contractIdToAssetsMap.size());
            return contractIdToAssetsMap;
        }
        set;
    }

    /**
     * Method to find the contract associated to asset, by scanning the rest of the bundle for subscriptions
     *  and getting the SBQQ__Contract__c value from one of those subscriptions:
     */
    public static Id findContractIdForAsset(Asset asset) {
        YObjectInfo assetInfo = getYObjectInfo(asset);
        Id contractId;
        if(assetInfo != null) {
            yObjectIdTo_yObjectInfoMap.put(asset.Id, assetInfo);
            
            if(asset.SBQQ__CurrentSubscription__c != null) { // asset has a direct child subscription covering it
                contractId = asset.SBQQ__CurrentSubscription__r.SBQQ__Contract__c;
            } else if(asset.SBQQ__RequiredBySubscription__c != null) { // asset's direct parent is a subscription
                contractId = asset.SBQQ__RequiredBySubscription__r.SBQQ__Contract__c;
            } else if(asset.SBQQ__RequiredByAsset__r.SBQQ__CurrentSubscription__c != null) { // asset's direct parent is an asset that has a direct child sub covering it
                contractId = asset.SBQQ__RequiredByAsset__r.SBQQ__CurrentSubscription__r.SBQQ__Contract__c;
            } else { // else, the asset does not have a subscription directly above or below it in the hierarchy.
                Id topBundleId = assetInfo.topBundleId;
                if(topBundleId != null) {
                    contractId = topBundleIdToMasterParentIdMap.get(topBundleId);
                }
            }
        } else {
            System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.findContractIdForAsset assetInfo is null. Asset Id: ' + asset.Id);
        }
    
        return contractId;
    }

    // variable to get quote lines for a quote id passed in to the XObjectData inner class
    public static Map<Id, SBQQ__QuoteLine__c> quoteLinesMap {
        get {
            if(quoteLinesMap == null) {
                quoteLinesMap = new Map<Id, SBQQ__QuoteLine__c>((List<SBQQ__QuoteLine__c>)Database.query(getDynamicQuoteLineQueryString(reduceQuoteLineHeap)));
                yObjectMap.putAll(quoteLinesMap);
            }

            return quoteLinesMap;
        }
        set;
    }

    // variable to build map of quote id to list of quote lines
    public static Map<String, List<SBQQ__QuoteLine__c>> quoteIdToQuoteLinesMap {
        get {
            if(quoteIdToQuoteLinesMap == null) {
                  quoteIdToQuoteLinesMap = CPQU_ApexUtils.groupBy(quoteLinesMap.values(), quoteLineGroupingField);
            }
            return quoteIdToQuoteLinesMap;
        }
        set;
    }

    // variable to get order products for an Order id passed in to the XObjectData inner class
    public static Map<Id, OrderItem> orderProductsMap {
        get {
            if(orderProductsMap == null) {
                orderProductsMap = new Map<Id, OrderItem>((List<OrderItem>)Database.query(getDynamicOrderProductQueryString(reduceOrderProductHeap)));
                yObjectMap.putAll(orderProductsMap);
            }
            return orderProductsMap;
        }
        set;
    }

    // variable to build map of quote id to list of quote lines
    public static Map<String, List<OrderItem>> orderIdToOrderLinesMap {
        get {
            if(orderIdToOrderLinesMap == null) {
                  orderIdToOrderLinesMap = CPQU_ApexUtils.groupBy(orderProductsMap.values(), orderProductGroupingField);
            }
            return orderIdToOrderLinesMap;
        }
        set;
    }

    /**
     * Inner class to store an extended version of the contract (or quote or order) bundle structure
     */
    public class BundleStructure {
        public Id xObjectId;
        public String xObjectType;
        public Integer numOfTiers = 0;
        public List<SBQQ__Subscription__c> subscriptions; // subscriptions on a contract
        public List<Asset> assets; // assets related to a contract
        public List<SObject> yObjectsList = new List<SObject>(); // subscriptions and assets related to a contract
        public List<SBQQ__QuoteLine__c> quoteLines = new List<SBQQ__QuoteLine__c>(); // quote lines related to q quote
        public List<OrderItem> orderProducts = new List<OrderItem>(); // order products related to an order
        public Map<Id, Map<Id, SObject>> topBundleIdToLinesInBundle = new Map<Id, Map<Id, SObject>>(); // map top bundle id to associated list of lines
        public Map<Id, Set<Id>> topBundleIdToLineIdsInBundle = new Map<Id, Set<Id>>(); // map top bundle id to associated list of lines
        public Map<Id, List<SObject>> topBundleIdToListOfLinesInBundle = new Map<Id, List<SObject>>(); // map top bundle id to associated list of lines
        public Map<Id, YObjectInfo> yObjectIdTo_yObjectInfoMap = new Map<Id, YObjectInfo>(); // map yObject (asset, sub, quote line, or order product) id to associated extended info for that yObject
        public Map<Id, SObject> yObjectIdTo_YObject = new Map<Id, SObject>(); // map yObject (asset, sub, quote line, or order product) id to associated yObject
    }

    /**
     * @description: Method to build a bundle structure for a particular contract
     * 
     * @param Id xObjectId -> the Id of the contract (or Quote or Order) in which to pull bundles from
     * @return BundleStructure xObjectBundleStructure  -> the bundle structure for a particular contract, quote, order, etc.
     */
    public static BundleStructure getxObjectBundleStructure(Id xObjectId) {
        String xObjectType = String.valueOf(xObjectId.getSobjectType());
        return(getxObjectBundleStructure(xObjectId, xObjectType));
    }

    public static BundleStructure getxObjectBundleStructure(Id xObjectId, String xObjectTypeParam) {
        xObjectIdSet = xObjectIdSet.isEmpty() ? new Set<Id>{xObjectId} : xObjectIdSet;
        String xObjectTypeVar = xObjectTypeParam == null ? String.valueOf(xObjectId.getSobjectType()) : xObjectTypeParam;
        BundleStructure xObjectBundleStructure = new BundleStructure();
        xObjectBundleStructure.xObjectId = xObjectId;
        xObjectBundleStructure.xObjectType = xObjectTypeVar;

        if(xObjectTypeVar == CONTRACT_STR) {
            xObjectBundleStructure.subscriptions = !contractIdToSubsMap.containsKey(xObjectId) ? new List<SBQQ__Subscription__c>() : contractIdToSubsMap.get(xObjectId);
            xObjectBundleStructure.assets = contractIdToAssetsMap.get(xObjectId) == null ? new List<Asset>() : contractIdToAssetsMap.get(xObjectId);
            xObjectBundleStructure.yObjectsList.addAll(xObjectBundleStructure.subscriptions);
            xObjectBundleStructure.yObjectsList.addAll(xObjectBundleStructure.assets);
        } else if(xObjectTypeVar == QUOTE_FIELD_REF) {
            xObjectBundleStructure.quoteLines = quoteIdToQuoteLinesMap.get(xObjectId) == null ? new List<SBQQ__QuoteLine__c>() : quoteIdToQuoteLinesMap.get(xObjectId);
            xObjectBundleStructure.yObjectsList.addAll(xObjectBundleStructure.quoteLines);
        } else if(xObjectTypeVar == ORDER_STR) {
            xObjectBundleStructure.orderProducts = orderIdToOrderLinesMap.get(xObjectId) == null ? new List<OrderItem>() : orderIdToOrderLinesMap.get(xObjectId);
            xObjectBundleStructure.yObjectsList.addAll(xObjectBundleStructure.orderProducts);
        }

        return getxObjectBundleStructure(xObjectId, xObjectBundleStructure);
    }

    public static BundleStructure getxObjectBundleStructure(Id xObjectId, BundleStructure xObjectBundleStructure) {
        // Loop through Y Products (assets, subs, or quote lines, or order products) on this contract:
        for(SObject yObject : xObjectBundleStructure.yObjectsList) {
            Id yObjectId = (Id) yObject.get(ID_STR);
            YObjectInfo yObjectInfo = xObjectBundleStructure.yObjectIdTo_YObject.containsKey(yObjectId) ? yObjectIdTo_yObjectInfoMap.get(yObjectId) : getYObjectInfo(yObject);
            xObjectBundleStructure.yObjectIdTo_yObjectInfoMap.put(yObjectId, yObjectInfo);
            
            xObjectBundleStructure.yObjectIdTo_YObject.put(yObjectId, yObject);
            // map top bundle id to its list of products (assets and subs, quote lines, or order products):
            if(yObjectInfo != null && yObjectInfo.topBundleId != null) {
                if(xObjectBundleStructure.numOfTiers < yObjectInfo.tier) {
                    xObjectBundleStructure.numOfTiers = yObjectInfo.tier;
                }
                // build multiple maps for greater flexability: Bundle Id to map of lines, bundle id to set of lids, bundle id to list of lines.
                Map<Id, SObject> sObjMap = xObjectBundleStructure.topBundleIdToLinesInBundle.get(yObjectInfo.topBundleId) == null ? new Map<Id, SObject>() : xObjectBundleStructure.topBundleIdToLinesInBundle.get(yObjectInfo.topBundleId);
                sObjMap.put(yObjectId, yObject);
                xObjectBundleStructure.topBundleIdToLinesInBundle.put(yObjectInfo.topBundleId, sObjMap);

                Set<Id> lineIdSet = xObjectBundleStructure.topBundleIdToLineIdsInBundle.get(yObjectInfo.topBundleId) == null ? new Set<Id>() : xObjectBundleStructure.topBundleIdToLineIdsInBundle.get(yObjectInfo.topBundleId);
                lineIdSet.add(yObjectId);
                xObjectBundleStructure.topBundleIdToLineIdsInBundle.put(yObjectInfo.topBundleId, lineIdSet);

                List<SObject> sObjList = xObjectBundleStructure.topBundleIdToListOfLinesInBundle.get(yObjectInfo.topBundleId) == null ? new List<SObject>() : xObjectBundleStructure.topBundleIdToListOfLinesInBundle.get(yObjectInfo.topBundleId);
                sObjList.add(yObject);
                xObjectBundleStructure.topBundleIdToListOfLinesInBundle.put(yObjectInfo.topBundleId, sObjList);                
            } else {
                System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getxObjectBundleStructure issue, erroneous Id: ' + (Id) yObject.get(ID_STR));
                System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getxObjectBundleStructure issue, yObjectInfo: ' + yObjectInfo);
                return null;
            }
        }

        System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getxObjectBundleStructure yObjectIdTo_yObjectInfoMap: ' + yObjectIdTo_yObjectInfoMap);
        System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getxObjectBundleStructure xObjectIdSet: ' + xObjectIdSet);

        //System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getxObjectBundleStructure xObjectBundleStructure: ' + JSON.serializePretty(xObjectBundleStructure));
        return xObjectBundleStructure;
    }

    /**
     * Inner class to gather info about a particular 'yObject' AKA Subscription, Asset, Quote Line, or Order Product.
     */
    public class YObjectInfo {
        public Integer loopCount = 0;				// variable to avoid infinite recursion of the getYObjectInfo method
        public SObject yObject;						// the actual yObject. Not yObject record, but asset, sub, quote line, order yObject, etc
        public Id recordId;							// record id of the yObject. Not yObject record, but asset, sub, quote line, order yObject, etc
        public String objectType;					// object type of the yObject, aka Asset, SBQQ__Subscription, SBQQ__QuoteLine__c, or OrderItem
        public String parentIdKey;					// parent Id key of the yObject; ex: SBQQ__RequiredById__c, SBQQ__RequiredBy__c.
        public String rootIdKey;					// root id key of the yObject; ex: SBQQ__RootId__c, SBQQ__BundleRoot__c
        public String rootId;						// actual root id of the record.
        public Integer lineNumber;					// optionally designate a different SBQQ__Number__c value for the sub/asset/quoteline/order yObject
        public Integer tier = 1;					// tier of the yObject. 1 means it's an ultimate yObject at the top of a bundle
        public SObject requiredByObject; 			// asset, subscription, quote line, or order yObject direct parent of the yObject
        public Id topBundleId;						// Id of the ultimate yObject at the top of the bundle
        public SObject topYObject; 					// Ultimate yObject at the top of the bundle
        public Product2 topYObjectProduct; 			// Ultimate yObject product record:
        public Boolean isTopLevelProduct = false;	// is this an ultimate yObject at the top of a bundle
        public List<YObjectInfo> directChildYObjectInfos = new List<YObjectInfo>();			// List to store the child yObjects for a particular yObject
        //public List<YObjectInfo> childAndGrandChildYObjectInfos = new List<YObjectInfo>();  // List to store children and grandchildren yObjects for a particular yObject
        
        public YObjectInfo(SObject yObjectParam, Id recordIdVar) {
            this.yObject = yObjectParam;
            this.recordId = recordIdVar;
        }
    }

    // inner class to get the CPQ field keys for a particular line (Quote Line, Contract Line aka asset/sub, Order Line)
    public class CPQFieldMapping {
        String objectType;
        Id recordIdVar;
        String parentIdKey;
        String requiredByIdKey;
        String requiredByAssetKey;
        String requiredBySubKey;
        String rootIdKey;
        String cpqMasterObjectIdKey;
        String product2Key;
        String xObjectId;
        String accountIdKey;
        String quantityKey;

        public CPQFieldMapping(SObject yObjectParam) {
            this.recordIdVar = (Id) yObjectParam.get(ID_STR) == null ? yObjectParam.getCloneSourceId() : (Id) yObjectParam.get(ID_STR);
            this.objectType = String.valueOf(this.recordIdVar.getSobjectType());
            if(objectType == QUOTELINE_OBJ_NAME_STR) {
                this.parentIdKey = REQUIRED_BY_FIELD_REF;
                this.requiredByIdKey = REQUIRED_BY_FIELD_REF;
                this.cpqMasterObjectIdKey = QUOTE_FIELD_REF;
                this.product2Key = PRODUCT2_CPQ_RELATIONSHIP;
                this.quantityKey = CPQ_QUANTITY_FIELD_REF;
            } else if(objectType == SUBSCRIPTION_OBJ_TYPE_STR) {
                this.parentIdKey = REQUIRED_BY_ID_FIELD_REF;
                this.requiredByIdKey = REQUIRED_BY_ID_FIELD_REF;
                this.rootIdKey = ROOT_ID_FIELD_REF;
                this.cpqMasterObjectIdKey = SUBSCRIPTION_CONTRACT_ID_FIELD_REF;
                this.product2Key = PRODUCT2_CPQ_RELATIONSHIP;
                this.accountIdKey = CPQ_ACCOUNT_FIELD_REF;
                this.quantityKey = CPQ_QUANTITY_FIELD_REF;
            } else if(objectType == ASSET_OBJ_TYPE_STR) {
                this.requiredByAssetKey = REQUIRED_BY_ASSET_FIELD_REF;
                this.requiredBySubKey = REQUIRED_BY_SUB_FIELD_REF;
                this.requiredByIdKey = REQUIRED_BY_ID_FIELD_REF;
                this.parentIdKey = REQUIRED_BY_ID_FIELD_REF;
                //this.parentIdKey = getParentIdKeyForAsset(yObjectParam);
                this.rootIdKey = ROOT_ID_FIELD_REF;
                this.product2Key = PRODUCT2_STANDARD_FIELD_REF;
                this.accountIdKey = STANDARD_ACCOUNT_FIELD_REF;
                this.quantityKey = STANDARD_QUANTITY_FIELD_REF;
            } else if(objectType == ORDERITEM_OBJ_TYPE_STR) {
                this.parentIdKey = REQUIRED_BY_FIELD_REF;
                this.requiredByIdKey = REQUIRED_BY_FIELD_REF;
                this.rootIdKey = BUNDLE_ROOT_FIELD_REF;
                this.cpqMasterObjectIdKey = ORDER_ID_FIELD_REF;
                this.product2Key = PRODUCT2_STANDARD_FIELD_REF;
                this.quantityKey = STANDARD_QUANTITY_FIELD_REF;
            }
        }
    }

    /**
     * Method to get parentIdKey for Asset. Notes: SBQQ__RequiredById__c on Asset isn't the most accurate, so 
     *  Assets get their own special method to retrieve the parent Id Key.
     */
    // private static String getParentIdKeyForAsset(SObject yObjectParam) {
    //     // last resort use SBQQ__RequiredById__c as the parent key. It isn't always the most reliable on assets.
    //     String parentIdKey = REQUIRED_BY_ID_FIELD_REF;
    //     if(yObjectParam instanceof Asset) {
    //         Asset asset = (Asset) yObjectParam;
    //         if(asset.SBQQ__RequiredByAsset__c != null) {
    //             parentIdKey = REQUIRED_BY_ASSET_FIELD_REF;
    //         } else if(asset.SBQQ__RequiredBySubscription__c != null) {
    //             parentIdKey = REQUIRED_BY_SUB_FIELD_REF;
    //         }
    //     }
    //     return parentIdKey;
    // }

    /**
     * Method to get information about a particular subscription, asset, quote line, or order yObject. 
     * Useful especially when there is a 3 or more tier bundle structure.
     * Note: if we start with a tier 5 subscription for example, this method will recall itself until it gets to the top via traversing through
     *   the SBQQ__RequiredById__c
     *
     * @param SObject yObjectParam -> the subscription, asset, quote line, or order yObject to get the info about
     * @return YObjectInfo -> the extended information about a subscription, asset, quote line, or order yObject
     *
     */
    public static YObjectInfo getYObjectInfo(SObject yObjectParam) {
        if(yObjectParam == null) { return null; }
        CPQFieldMapping cpqFieldMapping = new CPQFieldMapping(yObjectParam);

        return getYObjectInfo(
                yObjectParam, null, cpqFieldMapping.objectType, cpqFieldMapping.parentIdKey,
                cpqFieldMapping.cpqMasterObjectIdKey, cpqFieldMapping.rootIdKey, cpqFieldMapping.product2Key
        );
    }

    public static YObjectInfo getYObjectInfo(
            SObject yObjectParam, SObject nextUpperObject, String objectType, String parentIdKey, String cpqMasterObjectIdKey,
            String rootIdKey, String product2Key
    ) {
        if(cpqMasterObjectIdKey != null) {
            Id xObjectId = (Id) yObjectParam.get(cpqMasterObjectIdKey);
            if(xObjectId != null) {
                xObjectIdSet.add((Id) yObjectParam.get(cpqMasterObjectIdKey));
            }
        }

        if(parentIdKey == null) { return null; }
        Id recordIdVar = (Id) yObjectParam.get(ID_STR);
        
        Id rootIdVar;
        if(rootIdKey != null) {
            rootIdVar = (Id) yObjectParam.get(rootIdKey);
        }

        Id parentIdVar = (Id) yObjectParam.get(parentIdKey);
        Id cpqMasterObjectIdVar = cpqMasterObjectIdKey == null ? null : (Id) yObjectParam.get(cpqMasterObjectIdKey);
        if(cpqMasterObjectIdKey != null && cpqMasterObjectIdVar == null && nextUpperObject != null && nextUpperObject.get(cpqMasterObjectIdKey) != null) {
            cpqMasterObjectIdVar = (Id) nextUpperObject.get(cpqMasterObjectIdKey);
        }
        YObjectInfo yObjectInfo = yObjectIdTo_yObjectInfoMap.get(recordIdVar) == null ? new YObjectInfo(yObjectParam, recordIdVar) : yObjectIdTo_yObjectInfoMap.get(recordIdVar);
        yObjectInfo.loopCount += 1;
        yObjectInfo.parentIdKey = parentIdKey;
        yObjectInfo.rootIdKey = rootIdKey;
        if(yObjectInfo.loopCount >= 10) { // 10 means it supports up to a 10 tier bundle structure :). Feel free to increase it if you really want to...
            System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getYObjectInfo: hit the max loop count for yObject: ' + yObjectParam);
            return null; // avoid potential infinite recursion, since this method conditionally calls itself below.
        }

        // if top level yObject (sub, asset, quote line, order yObject, etc.)
        if(parentIdVar == null) {
            yObjectInfo.topBundleId = recordIdVar;
            yObjectInfo.rootId = recordIdVar;
            yObjectInfo.topYObject = yObjectParam;
            yObjectInfo.topYObjectProduct = (Product2) yObjectParam.getSObject(product2Key);
            yObjectInfo.isTopLevelProduct = true;
            yObjectIdTo_yObjectInfoMap.put(recordIdVar, yObjectInfo);
            if(cpqMasterObjectIdVar != null) { //  since this yObject is a top bundle, map it's id to the master object id (ex: contract, quote, order):
                topBundleIdToMasterParentIdMap.put(recordIdVar, cpqMasterObjectIdVar); 
            }
            return yObjectInfo;
        } else {
            // Note we cannot always count on SBQQ__RootId__c being populated (migrated data/ammendments), therefore we must traverse using SBQQ__RequiredById__c in some scenarios.
            Id objKey = nextUpperObject == null ? parentIdVar : (Id) nextUpperObject.get(parentIdKey);
            if(
                yObjectMap.containsKey(objKey) || relatedAssetsMap.containsKey(objKey) || contractSubsMap.containsKey(objKey)
                || quoteLinesMap.containsKey(objKey) || orderProductsMap.containsKey(objKey)
            ) {

                nextUpperObject = yObjectMap.get(objKey); 
                SObject requiredByObject = yObjectMap.get(parentIdVar); 
                yObjectInfo.requiredByObject = requiredByObject;

                if(nextUpperObject == null) {
                    System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getYObjectInfo issue obtaining the next upper object, probably an issue with the data. YObjectParam: ' + yObjectParam);
                    return null;
                }

                // if the next upper object doesn't have a required by id, we don't need to keep traversing. We can assume the next upper object is the ultimate parent:
                // Tier 2 products will always hit this condition first and never hit the else. Tier 3 and beyond will eventually hit this condition.
                if((Id) nextUpperObject.get(parentIdKey) == null) { // this means the nextUpperObject is the ultimate parent of the bundle
                    yObjectInfo.topBundleId = rootIdVar == null ? (Id) nextUpperObject.get(ID_STR) : rootIdVar;
                    yObjectInfo.isTopLevelProduct = false;
                    yObjectInfo.topYObject = nextUpperObject;
                    yObjectInfo.tier = 2;
                    yObjectInfo.topYObjectProduct = (yObjectInfo.topYObject instanceof Asset || yObjectInfo.topYObject instanceof OrderItem) ? 
                        (Product2) yObjectInfo.topYObject.getSObject(PRODUCT2_STANDARD_FIELD_REF) : (Product2) yObjectInfo.topYObject.getSObject(PRODUCT2_CPQ_RELATIONSHIP);
                    yObjectIdTo_yObjectInfoMap.put(recordIdVar, yObjectInfo);

                    if(cpqMasterObjectIdVar != null) { // map the top bundle id to cpq master object id (ex: contract, quote, order):
                        topBundleIdToMasterParentIdMap.put(yObjectInfo.topBundleId, cpqMasterObjectIdVar);
                    }

                    // get the ultimate parent yObject info, and add the yObject as a child of it:
                    YObjectInfo ultimateParentProductInfo = yObjectIdTo_yObjectInfoMap.get(yObjectInfo.topBundleId) == null ? new YObjectInfo(yObjectInfo.topYObject, yObjectInfo.topBundleId) : yObjectIdTo_yObjectInfoMap.get(yObjectInfo.topBundleId);
                    // insurance policy to set the ultimate parent's properties if they have not been set yet:
                    if(ultimateParentProductInfo.topBundleId == null) {
                        ultimateParentProductInfo.topBundleId = yObjectInfo.topBundleId;
                    }
                    if(ultimateParentProductInfo.rootId == null) {
                        ultimateParentProductInfo.rootId = yObjectInfo.topBundleId;
                    }
                    if(ultimateParentProductInfo.topYObject == null) {
                        ultimateParentProductInfo.topYObject = nextUpperObject;
                    }
                    if(ultimateParentProductInfo.topYObjectProduct == null) {
                        ultimateParentProductInfo.topYObjectProduct = yObjectInfo.topYObjectProduct;
                    }
                    ultimateParentProductInfo.isTopLevelProduct = true;

                    // if the yObject is directly underneath an ultimate parent bundle line:
                    if(parentIdVar == yObjectInfo.topBundleId) {
                        System.debug(LoggingLevel.FINE, 'CPQU_BundleStructureUtils.getYObjectInfo: directly under top bundle adding id to childAndGrandChildYObjectInfos ' + yObjectInfo);
                        ultimateParentProductInfo.directChildYObjectInfos.add(yObjectInfo);
                        
                    } /*else { // accumulate the children products and grandchildren products of the ultimate parent, on the ulimitate parent itself:
                        ultimateParentProductInfo.childAndGrandChildYObjectInfos.add(yObjectInfo);
                    }*/
                    
                    yObjectIdTo_yObjectInfoMap.put(yObjectInfo.topBundleId, ultimateParentProductInfo);
                    return yObjectInfo;
                } else { // if the next upper object has SBQQ__RequiredById__c (or SBQQ__RequiredBy__c) populated,
                    // gather some info and then keep traversing up through the bundle structure:
                    /*YObjectInfo directParentProductInfo = yObjectIdTo_yObjectInfoMap.get(parentIdVar) == null ? new yObjectInfo(nextUpperObject, parentIdVar) : yObjectIdTo_yObjectInfoMap.get(parentIdVar);
                    // add the yObject to its direct parent's list of direct children:
                    directParentProductInfo.directChildYobjectInfos.add(yObjectInfo);
                    //directParentProductInfo.directChildYobjectInfos.addAll(yObjectInfo.directChildYobjectInfos);
                    yObjectIdTo_yObjectInfoMap.put(parentIdVar, directParentProductInfo);

                    return getYObjectInfo(yObjectParam, nextUpperObject, objectType, parentIdKey, cpqMasterObjectIdKey, rootIdKey, product2Key); // recall the method to keep traversing up until we get to the top
*/
                    YObjectInfo directParentProductInfo = yObjectIdTo_yObjectInfoMap.get(parentIdVar) == null ? new YObjectInfo(nextUpperObject, parentIdVar) : yObjectIdTo_yObjectInfoMap.get(parentIdVar);
                    // add the yObject to its direct parent's list of direct children:
                    directParentProductInfo.directChildYObjectInfos.add(yObjectInfo);
                    yObjectIdTo_yObjectInfoMap.put(parentIdVar, directParentProductInfo);

                    YObjectInfo yObjectInfoParent = getYObjectInfo(yObjectParam, nextUpperObject, objectType, parentIdKey, cpqMasterObjectIdKey, rootIdKey, product2Key); // recall the method to keep traversing up until we get to the top
                    yObjectInfo.tier = yObjectInfoParent.tier + 1;
                    yObjectInfo.topBundleId = yObjectInfoParent.topBundleId;
                    System.debug(LoggingLevel.DEBUG, 'CPQXL_BundleStructureUtils.getYObjectInfo: child of child yObjectInfo.tier: ' + yObjectInfo.tier + ' yObjectInfo.topBundleId: ' + yObjectInfo.topBundleId);
                    //directParentProductInfo.directChildYobjectInfos.addAll(yObjectInfo.directChildYobjectInfos);
                    return yObjectInfo;
                }
            } else {
                System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getYObjectInfo: issue with yObjectMap, the following recordId was not found as a key in the map: ' + recordIdVar);
                return null;
            }
        } 
    }

    /**
     * Method to update SBQQ__RootId__c on Asset/Subscription, or SBQQ__BundleRoot__c on OrderProduct
     * Useful if SBQQ__RootId__c or SBQQ__BundleRoot__c are not populated on migrated data, or if these field values somehow get compromised.
     * Also useful in the ammendment scenario where CPQ somehow doesn't populate it.
     *
     * @param Set<Id> xObjectIdSet -> a set of Contract Ids or Order Ids in which to set the root id values on their children yObjects (Assets/Subs or Order Products)
     * @return void
     */
    public static void rootIdSetter(Id xObjectId) {
        rootIdSetter(new Set<Id>{xObjectId});
    }

    public static void rootIdSetter(Set<Id> xObjectIdSetParam) {
        List<BundleStructure> xObjectBundleStructureList = getListOfBundleStructures(xObjectIdSetParam);
        Map<Id, SObject> yObjectsToUpdateMap = new Map<Id, SObject>();

        // loop through each Contract (or Quote, or Order) bundle structure:
        for(BundleStructure xObjectBundleStructure : xObjectBundleStructureList) {
            if(xObjectBundleStructure != null) {
                if(xObjectBundleStructure.xObjectType == QUOTE_FIELD_REF) {
                    continue; // Quote Lines do not have a root id, so skip quote bundle structures
                }

                // loop through each bundle within the bundleStructure:
                for(Id topBundleId : xObjectBundleStructure.topBundleIdToLinesInBundle.keySet()) {
                    // loop through the bundle's products and find the utlimate bundle parent yObject for this bundle:
                    for(SObject yObject : xObjectBundleStructure.topBundleIdToLinesInBundle.get(topBundleId).values()) {
                        YObjectInfo yObjectInfo = yObjectIdTo_yObjectInfoMap.get((Id) yObject.get(ID_STR));
                        yObject.put(yObjectInfo.rootIdKey, yObjectInfo.topBundleId); // set the root id here
                        yObjectsToUpdateMap.put(yObject.Id, yObject);
                    }
                }
            }
        }

        if(!yObjectsToUpdateMap.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.rootIdSetter yObjectsToUpdateMap: ' + yObjectsToUpdateMap);
            yObjectsToUpdateMap = CPQU_ApexUtils.mapSorter(yObjectsToUpdateMap);
            update yObjectsToUpdateMap.values();
        }
    }

    /**
     * Method to update SBQQ__Number__c on products (subscriptions and their associated assets, or quote lines, or order products) based on their tier. 
     * Useful for when SBQQ__Number__c integrity on contract products (subs and associated assets, or quote lines, or order products) is compromised.
     *
     * @param Id xObjectIdParam -> an Contract Id (or Quote Id or Order Id) in which to resequence the line numbers and update their products (subs and associated assets, or quote lines, or order products)
     * @return void
     */
    public static void patchLineNumbersOnXobject(Id xObjectIdParam) {
        patchLineNumbersOnXobject(new Set<Id>{xObjectIdParam});
    }

    /**
     * Alternate version of patchLineNumbersOnXobject method.
     *
     * @param Set<Id> xObjectIdSetParam -> a set of Contract ids (or Quote Ids or Order Ids) in which to resequence the line numbers and update their products (subs and associated assets, or quote lines, or order products)
     * @return void
     */
    public static void patchLineNumbersOnXobject(Set<Id> xObjectIdSetParam) {
        Map<Id, List<SObject>> xObjectIdToSequencedyObjects = lineNumberSequencer(xObjectIdSetParam);
        if(xObjectIdToSequencedyObjects == null) { return; }

        Map<Id, SObject> yObjectsToUpdateMap = new Map<Id, SObject>();
        System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.patchLineNumbersOnXobject xObjectIdToSequencedyObjects size: ' + xObjectIdToSequencedyObjects.size());

        // loop through contracts ids passed into this method:
        for(Id xObjectId : xObjectIdToSequencedyObjects.keySet()) {
            Integer lineNumberIterator = 1;
            // At this point, Y products have been resequenced in memory within the lineNumberSequencer method.
            // loop through all the Y products on this xObject:
            for(SObject yObject : xObjectIdToSequencedyObjects.get(xObjectId)) {
                Id yObjectId = (Id) yObject.get(ID_STR);
                yObject.put(SBQQNUMBER_FIELD_REF, lineNumberIterator);
                yObjectsToUpdateMap.put(yObjectId, yObject);
                lineNumberIterator += 1;
            }
            if(!yObjectsToUpdateMap.isEmpty()) {
                yObjectsToUpdateMap = CPQU_ApexUtils.mapSorter(yObjectsToUpdateMap);
                update yObjectsToUpdateMap.values();
            }
            
        }
    }

    /**
     * Method to sequence products based on their tier. Useful for when SBQQ__Number__c integrity on contract subs and associated assets, or quote lines, is compromised.
     *
     * @param Id xObjectIdParam -> a Contract Id (or Quote Id or Order Id) in which to sequence its products (subs and associated assets, or quote lines, or order products)
     * @return Set<Id> sequencedAssetAndSubIds -> a sequenced set of yObject (sub and/or associated asset) ids. The sequence is based on the yObject tier.
     */
    public static Map<Id, List<SObject>> lineNumberSequencer(Id xObjectIdParam) {
        return lineNumberSequencer(new Set<Id>{xObjectIdParam});
    }

    /**
     * Alternate version of lineNumberSequencer method, that takes a set of ids as a param instead of a single id.
     *
     * @param Set<Id> xObjectIdSetParam -> a set of contract ids in which to sequence  their products (subs and associated assets)
     * @return Set<Id> sequencedAssetAndSubIds -> a sequenced set of yObject (sub and/or associated asset) ids. The sequence is based on the yObject tier.
     */
    public static Map<Id, List<SObject>> lineNumberSequencer(Set<Id> xObjectIdSetParam) {
        List<BundleStructure> xObjectBundleStructureList = getListOfBundleStructures(xObjectIdSetParam);

        // Map to store the line number sequence for a given xObject (Contract, Quote, or Order)
        Map<Id, List<SObject>> xObjectIdToSequencedyObjects = new Map<Id, List<SObject>>();
        // loop through each contract:
        for(BundleStructure xObjectBundleStructure : xObjectBundleStructureList) {
            if(xObjectBundleStructure.xObjectType == ORDER_STR) { return null; } // Order Products do not have an SBQQ__Number__c value
            // List to store the products (subscriptions and/or associated assets) in sequential order. 
            // Ex: Tier 1 yObject, Tier 2 Product, Tier 3 yObject, Tier 1 yObject, Tier 2 Product, Tier 1 Product, Tier 2 Product, Tier 2 Product...
            List<SObject> sequencedProducts = new List<SObject> (); 

            // loop through each bundle on the xObject (Contract, Quote, or Order)
            for(Id topBundleId : xObjectBundleStructure.topBundleIdToLinesInBundle.keySet()) {
                // loop through the and find the utlimate bundle parent yObject for this bundle:
                for(SObject yObject : xObjectBundleStructure.topBundleIdToLinesInBundle.get(topBundleId).values()) {
                    YObjectInfo yObjectInfo = yObjectIdTo_yObjectInfoMap.get((Id) yObject.get(ID_STR));
                    if(yObjectInfo.tier == 1) {
                        traverseDownThroughBundleStructure(yObjectInfo, sequencedProducts);
                    }
                }
            }

            xObjectIdToSequencedyObjects.put(xObjectBundleStructure.xObjectId, sequencedProducts);
        }

        return xObjectIdToSequencedyObjects;
    }

    // method to get the bundle structures for one or multiple contracts, quotes, or orders
    public static List<BundleStructure> getListOfBundleStructures(Set<Id> xObjectIdSetParam) {
        List<BundleStructure> xObjectBundleStructureList = new List<BundleStructure>();
        // Get the bundle structure for each contract (or Order, or Quote):
        for(Id xObjectId : xObjectIdSetParam) {
            XObjectData xObjectData = getXObjectData(xObjectId);
            xObjectIdTo_xObjectDataMap.put(xObjectId, xObjectData);
            xObjectBundleStructureList.add(xObjectData.xObjectBundleStructure);
        }

        return xObjectBundleStructureList;
    }

    /**
     * Helper method for lineNumberSequencer method.
     * Notes: call this method with an ultimate bundle parent yObject. What this method will subsquently do is traverse 
     *   all the way down to the last tier (by calling itself as many times as needed), and in the process, 
     *   build the sequencedProducts list in staggering order. 
     *   Example of sequenceProducts list (notice the staggering):
     *      Tier 1 yObject A 
     *        Tier 2 yObject A (direct child of Tier 1 yObject A)
     *          Tier 3 yObject A (direct child of Tier 2 yObject A)
     *        Tier 2 yObject B (direct child of Tier 1 yObject A)
     *        Tier 2 yObject C (direct child of Tier 1 yObject A)
     * 			Tier 3 yObject (direct child of Tier 2 yObject C)
     *      Tier 1 yObject B
     *        Tier 2 yObject D (direct child of Tier 1 yObject B)
     *
     * @param YObjectInfo -> a YObjectInfo inner class object that stores the SObject and its extended information
     * @return void
     */
    private static void traverseDownThroughBundleStructure(YObjectInfo productInfoParam, List<SObject> sequencedProducts) {
        sequencedProducts.add(productInfoParam.yObject);
        // see if yObject (subscription or associated asset, or quote line, or order product) has children:
        if(productInfoParam.directChildYObjectInfos.size() > 0) {
            for(YObjectInfo childProductInfo : productInfoParam.directChildYObjectInfos) {
                // if it has children, traverse down another level:
                traverseDownThroughBundleStructure(childProductInfo, sequencedProducts);
            }
        }
    }

    // public class BundleAggregator {
    //     // maps the aggregation number to the bundle line ids in a bundle aggregation:
    //     Map<Integer, Set<Id>> bundleAggregations = new Map<Integer, Set<Id>>();
    //     // maps the aggregation number to ALL line ids in a bundle aggregation:
    //     Map<Integer, Set<Id>> bundleAggregationsExtended = new Map<Integer, Set<Id>>();
    // }

    /**
    * @description -> Method that returns a map with a set of bundles (as top level bundle Ids). Each bundle has close to 100 lines. 
    *   Notes: Useful for breaking a quote, contract, or order into a series of bundle aggregations for dealing with governor limits.
    * @param Id xObjectId -> Id of xObject (Contract, quote, or order) to get the bundle aggregations for
    * @param Integer upperBoundParam -> the maximum number of lines allowed in a bundle aggregation (set this to your desired value - 100 is pretty safe)
    * @return Map<Integer, Set<Id>> bundleAggregationsMap -> a map of bundle aggregation identifiers (integers) to associated bundle aggregation (a set of ulimate parent bundle ids)
    */
    public static Map<Integer, Set<Id>> getBundleAggregations(Id xObjectId, Integer upperBoundParam) {
        return getBundleAggregations(xObjectId, upperBoundParam, null);
    }

    /**
    * @description -> Method that returns a map with a set of bundles (as top level bundle Ids). Each bundle has close to 100 lines. 
    *   Notes: Useful for breaking a quote, contract, or order into a series of bundle aggregations for dealing with governor limits.
    * @param Id xObjectId -> Id of xObject (Contract, quote, or order) to get the bundle aggregations for
    * @param Integer upperBoundParam -> the maximum number of lines allowed in a bundle aggregation (set this to your desired value - 100 is pretty safe)
    * @param Set<Id> bundlesToExclude -> param to optionally exclude bundles from being added to an aggregation
    * @return Map<Integer, Set<Id>> bundleAggregationsMap -> a map of bundle aggregation identifiers (integers) to associated bundle aggregation (a set of ulimate parent bundle ids)
    */
    public static Map<Integer, Set<Id>> getBundleAggregations(Id xObjectId, Integer upperBoundParam, Set<String> bundlesToExclude) {
        XObjectData xObjectData = getXObjectData(xObjectId);
        Map<Id, Set<Id>> topBundleIdToLineIdsInBundle = xObjectData.xObjectBundleStructure.topBundleIdToLineIdsInBundle;
        
        return getBundleAggregations(topBundleIdToLineIdsInBundle, upperBoundParam, bundlesToExclude, false);
    }

    /**
    * @description -> Method that returns a map with a set of bundles (as top level bundle Ids). Each bundle has close to 100 lines. 
    *   Notes: Useful for breaking a quote, contract, or order into a series of bundle aggregations for dealing with governor limits.
    *    This version maps the aggregation number to ALL lines in a bundle aggregation.
    * @param Id xObjectId -> Id of xObject (Contract, quote, or order) to get the bundle aggregations for
    * @param Integer upperBoundParam -> the maximum number of lines allowed in a bundle aggregation (set this to your desired value - 100 is pretty safe)
    * @return Map<Integer, Set<Id>> bundleAggregationsMap -> a map of bundle aggregation identifiers (integers) to associated bundle aggregation (a set of ulimate parent bundle ids)
    */
    public static Map<Integer, Set<Id>> getBundleAggregationsExtended(Id xObjectId, Integer upperBoundParam) {
        return getBundleAggregationsExtended(xObjectId, upperBoundParam, null, true);
    }
    public static Map<Integer, Set<Id>> getBundleAggregationsExtended(
        Id xObjectId, Integer upperBoundParam, Set<String> bundlesToExclude, Boolean mapAllLineIds
    ) {
        XObjectData xObjectData = getXObjectData(xObjectId);
        Map<Id, Set<Id>> topBundleIdToLineIdsInBundle = xObjectData.xObjectBundleStructure.topBundleIdToLineIdsInBundle;
        
        return getBundleAggregations(topBundleIdToLineIdsInBundle, upperBoundParam, bundlesToExclude, true);
    }

    /**
    * @description -> Method that returns a map with a set of bundles (as top level bundle Ids). Each bundle has close to 100 lines. 
    * @param Map<Id, List<SObject>> topBundleIdToListOfLinesInBundle -> a map of ultimate parent bundle id to associated list of lines (quote lines or assets/subs or order products)
    * @param Integer upperBoundParam -> the maximum number of lines allowed in a bundle aggregation (set this to your desired value)
    * @param Set<Id> bundlesToExclude -> param to optionally exclude bundles from being added to an aggregation
    * @return Map<Integer, Set<Id>> bundleAggregationsMap -> a map of bundle aggregation identifiers (integers) to associated bundle aggregation (a set of ulimate parent bundle ids)
    */
    public static Map<Integer, Set<Id>> getBundleAggregations(
        Map<Id, Set<Id>> topBundleIdToLineIdsInBundle, Integer upperBoundParam, Set<String> bundlesToExclude, Boolean mapAllLineIds
    ) {
        List<Id> bundleIds = new List<Id>(topBundleIdToLineIdsInBundle.keySet());
        Map<Integer, Set<Id>> bundleAggregationsMap = new Map<Integer, Set<Id>>();
        Integer accruedNumOfQuoteLines = 0;
        Integer iterator = 1;
        Integer upperBound = upperBoundParam; // 100 quote lines is the maximum number we want on one of the split quotes:
        System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.getBundleAggregations bundleIds size: ' + bundleIds.size());
        for(Id topBundleId : bundleIds) {
            if(topBundleId != null) {
                // make sure to ingore bundle ids if they were optionally excluded in the bundlesToExcude param:
                if(bundlesToExclude == null || (bundlesToExclude != null && !bundlesToExclude.contains(topBundleId))) {
                    // accrue the number of accruedNumOfQuoteLines for this bundle:
                    accruedNumOfQuoteLines += topBundleIdToLineIdsInBundle.get(topBundleId).size();

                    // if the number of accruedNumOfQuoteLines is greater than the upper bound, or the bundles already processed contains the bundle:
                    if(accruedNumOfQuoteLines > upperBound) {
                        // if the bundle count pushed the accruedNumOfQuoteLines above the upper bound, skip the bundle so that it can be put on a different quote:
                        upperBound += upperBoundParam;
                        iterator += 1;
                    }
                     
                    Set<Id> lineIdsInBundle = topBundleIdToLineIdsInBundle.get(topBundleId) == null 
                        ? new Set<Id>() 
                        : topBundleIdToLineIdsInBundle.get(topBundleId);

                    Set<Id> idSet = bundleAggregationsMap.get(iterator) == null ? new Set<Id>() : bundleAggregationsMap.get(iterator);
                       if(mapAllLineIds) {
                        idSet.addAll(lineIdsInBundle);
                    } else {
                        idSet.add(topBundleId);
                    }
                    bundleAggregationsMap.put(iterator, idSet);
                }
            }
        }

        bundleAggregationsMapStatic = bundleAggregationsMap;
        return bundleAggregationsMap;
    }

    /**
     * @description -> Method to get all line ids within a specified bundle aggregation:
     */
    public static Set<Id> getAllLineIdsInAggregation(Integer aggrNumber, Id xObjectIdParam) {
        XObjectData xObjectData = getXObjectData(xObjectIdParam);
        Map<Id, Map<Id, SObject>> topBundleIdToLinesInBundle = xObjectData.xObjectBundleStructure.topBundleIdToLinesInBundle;

        if(bundleAggregationsMapStatic.containsKey(aggrNumber)) {
            Set<Id> bundleIdsInAggregation = bundleAggregationsMapStatic.get(aggrNumber);
            Set<Id> lineIdsInAggregation = new Set<Id>(); // a set of ALL line ids (including parent and child line ids) within a bundle aggregation
            for(Id topBundleId : topBundleIdToLinesInBundle.keySet()) {
                if(bundleIdsInAggregation.contains(topBundleId)) {
                    lineIdsInAggregation.addAll(topBundleIdToLinesInBundle.get(topBundleId).keySet());
                }
            }
            return lineIdsInAggregation;
        } else {
            return null;
        }
    }

    /**
     * BEGIN CLONING METHODS/HELPERS
     */

    /**
     * @description -> Method that clones bundles, whether those bundles are on a quote, contract, or order.
     * @param Id sourceXObjectId -> the quote, contract, or order in which to clone the header (without lines) from.
     * @param Boolean doInsert -> whether or not to insert the clone.
     * @return SObject xObjectClone -> the quote clone, contract clone, or order clone
     */
    public static SObject cloneXObjectHeader(Id sourceXObjectId, Boolean doInsert) {
        return cloneXObjectHeader(sourceXObjectId, false, doInsert);
    }
    /**
     * ...
     * @param Id sourceXObjectId -> the quote, contract, or order in which to clone the header (without lines) from.
     * @param Boolean setCloneAsPrimary -> if dealing with a quote XObject, specify whether or not the clone should become primary
     * @param Boolean doInsert -> whether or not to insert the clone.
     */
    public static SObject cloneXObjectHeader(Id sourceXObjectId, Boolean setCloneAsPrimary, Boolean doInsert) {
        return cloneXObjectHeader(sourceXObjectId, null, setCloneAsPrimary, doInsert);
    }
    /**
     * ...
     * @param Id sourceXObjectId -> the quote, contract, or order in which to clone the header (without lines) from.
     * @param List<String> specificXObjectFields -> optionally specify a list of specific fields for this method to consider when cloning.
     * @param Boolean setCloneAsPrimary -> if dealing with a quote XObject, specify whether or not the clone should become primary
     * @param Boolean doInsert -> whether or not to insert the clone.
     * @return SObject clonedXObject -> a single SObject clone
     */
    public static SObject cloneXObjectHeader(Id sourceXObjectId, List<String> specificXObjectFields, Boolean setCloneAsPrimary, Boolean doInsert) {
        String xObjectType = String.valueOf(sourceXObjectId.getSobjectType());
        String specificXObjectFieldsStr = specificXObjectFields == null ? null : String.join(specificXObjectFields, ',');
        String xObjectQuery = specificXObjectFieldsStr == null 
            ? 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr(xObjectType) + ' FROM ' + xObjectType + ' WHERE Id = :sourceXObjectId'
            : 'SELECT ' + specificXObjectFieldsStr + ' FROM ' + xObjectType + ' WHERE Id = :sourceXObjectId';

        SObject xObjectToClone = Database.query(xObjectQuery);
        SObject clonedXObject = xObjectToClone.clone(false, false);
        if(xObjectType == QUOTE_FIELD_REF) {
            clonedXObject.put(QUOTE_PRIMARY_FIELD, setCloneAsPrimary);
            clonedXObject.put(QUOTE_SOURCE_FIELD_REF, sourceXObjectId);
        }

        if(doInsert) {
            insert clonedXObject;
        }
        return clonedXObject;
    }

    /**
     * ...
     * @param Id sourceXObjectId -> the quote, contract, or order in which to clone the header (without lines) from
     * @param List<String> specificXObjectFields -> optionally specify a list of specific fields for this method to consider when cloning.
     * @param Boolean setCloneAsPrimary -> if dealing with a quote XObject, specify whether or not the clone should become primary
     * @param Boolean doInsert -> whether or not to insert the clone.
     * @return List<SObject> clonedXObject -> a single SObject clone
     */
    public static List<SObject> cloneXObjectHeader(Id sourceXObjectId, List<String> specificXObjectFields, Integer numOfClonesToMake, Boolean doInsert) {
        String xObjectType = String.valueOf(sourceXObjectId.getSobjectType());
        String specificXObjectFieldsStr = specificXObjectFields == null ? null : String.join(specificXObjectFields, ',');
        String xObjectQuery = specificXObjectFieldsStr == null 
            ? 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr(xObjectType) + ' FROM ' + xObjectType + ' WHERE Id = :sourceXObjectId'
            : 'SELECT ' + specificXObjectFieldsStr + ' FROM ' + xObjectType + ' WHERE Id = :sourceXObjectId';
        
        SObject xObjectToClone = Database.query(xObjectQuery);
        List<SObject> clonedXObjects = new List<SObject>();
        for(Integer i = 0; i < numOfClonesToMake; i++) {
            SObject clonedXObject = xObjectToClone.clone(false, false);
            if(xObjectType == QUOTE_FIELD_REF) {
                clonedXObject.put(QUOTE_PRIMARY_FIELD, false);
                clonedXObject.put(QUOTE_SOURCE_FIELD_REF, sourceXObjectId);
            }
            clonedXObjects.add(clonedXObject);
        }

        if(doInsert) {
            insert clonedXObjects;
        }
        return clonedXObjects;
    }

    /**
    * @description -> Method that clones bundles, whether those bundles are on a quote, contract, or order.
    *  TODO: write another parameter variation that only takes the following params: Id sourceXObjectId, Id targetXObjectId
    *  TODO: 
    * @param Id sourceXObjectId -> the quote, contract, or order to clone the bundle(s) from
    * @param Id targetXObjectId -> the quote, contract, or order to clone the bundle(s) onto
    * @param Id targetAccountId -> the id of the Account, in which to clone the bundle(s) onto. 
    *  This is only necessary when cloning asset/subscription bundles or Order Product bundles
    * @param (optional) Id bundleToClone/Set bundlesToClone -> the ultimate parent bundle id (or ids) in which to clone the lines from
    * @param (optional) Map<String, Integer> lineQuantityMap ->  param to specify custom quantity per line
    * @param (optional) Map<String, Integer> lineIdsNotToClone -> param to exclude certain lines within the bundle from being cloned (do not exclude the ultimate parent!)
    * @param (optional) Map<Id, Id> sourceXObjectIdToTargetXObjectId -> param to pass in multiple sources in which to clone their lines to associated targets:
    * @return Map<Id, SObject> lineClones -> an Id to object map of new lines that were the result of cloning
    */
    // V1: Attempt to clone all bundles from the sourceXObject (not recommended for large XObjects (aka large contracts, quotes, orders)):
    // Note: to clone all the bundles for large XObjects, it's best to use V4 with a subset of bundles, within platform event chains.
    public static Map<Id, SObject> cloneBundles(Id sourceXObjectId, Id targetXObjectId, Id targetAccountId) { 
        XObjectData xObjectData = getXObjectData(sourceXObjectId);
        Set<Id> allBundlesOnXObject = xObjectData.xObjectBundleStructure.topBundleIdToLinesInBundle.keySet();
        return(cloneBundles(sourceXObjectId, targetXObjectId, targetAccountId, allBundlesOnXObject, null, null));
    }
    // V2: clone a specified bundle from the sourceXObject:
    public static Map<Id, SObject> cloneBundles(Id sourceXObjectId, Id targetXObjectId, Id targetAccountId, Id bundleToClone) {
        return(cloneBundles(sourceXObjectId, targetXObjectId, targetAccountId, bundleToClone, null, null));
    }
    // V3: clone a specified bundle from the sourceXObject, and assign a custom quantity to the clone (also optionally exclude lines to be cloned to the new bundle):
    public static Map<Id, SObject> cloneBundles(
        Id sourceXObjectId, Id targetXObjectId, Id targetAccountId, Id bundleToClone, Map<String, Integer> lineQuantityMap, 
        Set<Id> lineIdsNotToClone
    ) {
        return(
            cloneBundles(sourceXObjectId, targetXObjectId, targetAccountId, new Set<Id>{bundleToClone}, lineQuantityMap, 
            lineIdsNotToClone)
        );
    }
    // V4: clone a set of specified bundles from the sourceXObject:
    public static Map<Id, SObject> cloneBundles(
        Id sourceXObjectId, Id targetXObjectId, Id targetAccountId, Set<Id> bundlesToClone
    ) {
        return(cloneBundles(sourceXObjectId, targetXObjectId, targetAccountId, bundlesToClone, null, null));
    }
    // V5: clone a set of specified bundles from multiple source objects to their associated target objects:
    public static Map<Id, SObject> cloneBundles(
        Map<Id, Id> sourceXObjectIdToTargetXObjectId, Set<Id> bundlesToClone
    ) {
        return(cloneBundles(null, null, null, bundlesToClone, null, null, sourceXObjectIdToTargetXObjectId));
    }
    // V6: clone a set of specified bundles from the sourceXObject, while also specifying custom quantity for the line clones, and lines to exclude from the bundle:
    public static Map<Id, SObject> cloneBundles(
        Id sourceXObjectId, Id targetXObjectId, Id targetAccountId, 
        Set<Id> bundlesToClone, Map<String, Integer> lineQuantityMap, Set<Id> lineIdsNotToClone
    ) {
        return(cloneBundles(sourceXObjectId, targetXObjectId, targetAccountId, bundlesToClone, lineQuantityMap, lineIdsNotToClone, null));
    }
    // V7: clone a set of specified bundles from the sourceXObject, and assign a custom quantity to the clone (also optionally exclude lines to be cloned to the new bundle.
    //  Also optionally specify a series of source object ids in which to clone bundles from them to associated target object ids.
    public static Map<Id, SObject> cloneBundles(
        Id sourceXObjectId, Id targetXObjectId, Id targetAccountId, 
        Set<Id> bundlesToClone, Map<String, Integer> lineQuantityMap, Set<Id> lineIdsNotToClone, Map<Id, Id> sourceXObjectIdToTargetXObjectId
    ) {
        signalToQueryAllLineFields();

        List<SObject> applicableSourceLines;
        String objectType; // type of object we're dealing with (Contract, Quote, or Order)
        if(sourceXObjectId != null && targetXObjectId != null) {
            XObjectData xObjectData = getXObjectData(sourceXObjectId);
            objectType = xObjectData.xObjectType;
            applicableSourceLines = xObjectData.yObjectsList;
        } else if(sourceXObjectIdToTargetXObjectId != null) {
            populateXObjectDataMap(sourceXObjectIdToTargetXObjectId.keySet());
            applicableSourceLines = new List<SObject>();
            for(XObjectData xObjectData : xObjectIdTo_xObjectDataMap.values()) {
                objectType = xObjectData.xObjectType;
                applicableSourceLines.addAll(xObjectData.yObjectsList);
            }
        }

        if(applicableSourceLines == null || objectType == null) {
            return null;
        }

        Map<Id, SObject> lineClones = new Map<Id, SObject>();
        List<SObject> bundlesToProcess = new List<SObject>();

        // loop through the lines and find the ultimate parent bundle lines
        for(SObject line : applicableSourceLines) {
            // If it's a top bundle line, its id will reside in the bundlesToClone.
            if(bundlesToClone.contains((Id) line.get(ID_STR))) {
                bundlesToProcess.add(line);
            }
        }

        // TODO: create quote line group shells here:
        if(objectType == QUOTE_OBJ_TYPE_STR) {
            potentiallyCloneQuoteLineGroups(bundlesToProcess, sourceXObjectId, targetXObjectId);
        }

        // create the ultimate parent lines:
        List<SObject> tier1Lines = createTier1Lines(bundlesToProcess, targetXObjectId, targetAccountId, lineQuantityMap, sourceXObjectIdToTargetXObjectId);
        tier1Lines = insertTier1Lines(tier1Lines);
        tier1Lines = updateTier1Lines(tier1Lines);
        lineClones.putAll(tier1Lines);

        for(SObject targetTier1Line : tier1Lines) {
            //map sourceId to target line:
            sourceLineIdToClonedLine.put(targetTier1Line.getCloneSourceId(), targetTier1Line);
        }

        Map<Integer, List<YObjectInfo>> tierNumToLineInfosAtTier = getTierNumToLineInfosMap(applicableSourceLines);
        List<Integer> sortedTiersAscending = new List<Integer>(tierNumToLineInfosAtTier.keySet()); // TODO: follow up and make comments to explain what this is.
        sortedTiersAscending.sort();
        System.debug('CPQU_BundleStructureUtils.cloneBundles sortedTiersAscending: ' + sortedTiersAscending);

        Set<Id> parentBundleIds = new Set<Id>();
        parentBundleIds.addAll(bundlesToClone);
        // parse out the non-ultimate parent lines to clone/insert for the first bundle aggregation:
        for(Integer sequencedTierNum : sortedTiersAscending) {
            // skip ultimate parents (only go after the children, grandchildren, etc):
            if(sequencedTierNum != 1) {
                System.debug('CPQU_BundleStructureUtils.cloneBundles sequencedTierNum: ' + sequencedTierNum + ' tierNumToLineInfosAtTier.get(sequencedTierNum).size(): ' + (tierNumToLineInfosAtTier.get(sequencedTierNum) != null ? tierNumToLineInfosAtTier.get(sequencedTierNum).size() : 0));
                List<SObject> nonTier1Lines = new List<SObject>();
                
                // loop through each non-ultimate line:
                for(YObjectInfo sourceNonTier1LineInfo : tierNumToLineInfosAtTier.get(sequencedTierNum)) {
                    // ignore cloning any lines whose ids were optionally passed in (by the developer) to lineIdsNotToClone:
                    if(lineIdsNotToClone == null || (lineIdsNotToClone != null && !lineIdsNotToClone.contains(sourceNonTier1LineInfo.recordId))) {
                        // if the non-ultimate parent line's ultimate parent bundle is in the bundle aggregation parameter, we need to clone/insert
                        //  that line in this batch:
                        System.debug('CPQU_BundleStructureUtils.cloneBundles sourceNonTier1LineInfo.topBundleId: ' + sourceNonTier1LineInfo.topBundleId + ' parentBundleIds.contains(sourceNonTier1LineInfo.topBundleId): ' + parentBundleIds.contains(sourceNonTier1LineInfo.topBundleId) + ' parentBundleIds.contains(sourceNonTier1LineInfo.rootId): ' + bundlesToClone.contains(sourceNonTier1LineInfo.rootId));
                        if(parentBundleIds.contains(sourceNonTier1LineInfo.topBundleId)) {
                            SObject newNonTier1Line;
                            newNonTier1Line = cloneChildLine(
                                    targetXObjectId, targetAccountId, sourceNonTier1LineInfo, sourceLineIdToClonedLine, lineQuantityMap, sourceXObjectIdToTargetXObjectId
                            );
                            parentBundleIds.add(sourceNonTier1LineInfo.recordId);
                            nonTier1Lines.add(newNonTier1Line);
                        }
                    }
                }

                if(!nonTier1Lines.isEmpty()) {
                    nonTier1Lines.sort();
                    // Yes, this is a DML in a for loop...
                    //  But we need to insert one tier at a time, just like CPQ does it out-of-the-box.
                    //  The first iteration of the loop will be tier 2 lines (since tier 1 already got inserted above), then tier 3 lines, and so on...
                    //  If there a 3 tiers in the bundle aggregation, there will be 3 inserts. 
                    //  If there are 4 tiers there will be 4 (and so on);
                    insert nonTier1Lines;
                    lineClones.putAll(nonTier1Lines);

                    System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.cloneBundles nonTier1Lines.size(): '+ nonTier1Lines.size());
                    System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.cloneBundles nonTier1Lines: '+ nonTier1Lines);
                }

                for(SObject newNonTier1Line : nonTier1Lines) {
                    //map source tier 2 quote line Id to target tier 2 quote line:
                    sourceLineIdToClonedLine.put(newNonTier1Line.getCloneSourceId(), newNonTier1Line);
                    //clonedLineIdToLineNumber.put(newNonTier1Line.Id, (Integer) newNonTier1Line.get(SBQQNUMBER_FIELD_REF));
                }
            }			
        }

        System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.cloneBundles lineClones.size(): ' + lineClones.size());
        System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.cloneBundles Serialized lineClones:' + lineClones);

        // if quantity modification was not specified:
        if(lineQuantityMap == null) {
            lineClones = applyRemainingFieldUpdates(lineClones);
        } else { // if quantity modification was specified:
            lineClones = applyRemainingFieldUpdates(lineClones, lineQuantityMap);
        }
        
        // create Subscribed Assets if we're dealing with a Subscription/Asset bundle:
        if(objectType == CONTRACT_STR && !sourceLineIdToClonedLine.isEmpty()) {
            List<SBQQ__SubscribedAsset__c> newSubscribedAssets = createSubscribedAssets(sourceLineIdToClonedLine);
            //List<Customer_Asset__c> newCustomerAssets = createCustomerAssets(sourceLineIdToClonedLine); // Vista specific
        }

        return lineClones;
    }

    /**
    * @description -> Method to create quote line group clones, if applicable 
    * @param List<SObject> bundlesToProcess -> the source bundles in which to clone the quote line group records off of.
    * @param Id sourceXObjectId -> the source quote Id
    * @param Id targetXObjectId -> the Id of the target quote clone to put the quote line group clones on
    */
    private static void potentiallyCloneQuoteLineGroups(List<SObject> bundlesToProcess, Id sourceXObjectId, Id targetXObjectId) {
        Set<Id> applicableSourceQlGroupIds = new Set<Id>();
        for(SObject line : bundlesToProcess) {
            Id quoteLineGroupId = (Id) line.get(QUOTELINE_GROUP_FIELD_REF);
            if(quoteLineGroupId != null) {
                applicableSourceQlGroupIds.add(quoteLineGroupId);
            }
        }

        // query source quote line groups, if applicable:
        if(!applicableSourceQlGroupIds.isEmpty()) {
            // query all groups from source quote:
            Map<Id, SBQQ__QuoteLineGroup__c> sourceAndTargetQlGroups = new Map<Id, SBQQ__QuoteLineGroup__c>(
                (List<SBQQ__QuoteLineGroup__c>) Database.query(
                    'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('SBQQ__QuoteLineGroup__c') +
                    ' FROM SBQQ__QuoteLineGroup__c ' +
                    'WHERE SBQQ__Quote__c = :sourceXObjectId OR SBQQ__Quote__c = :targetXObjectId ORDER BY Id DESC'
                )
            );

            Set<Id> sourceQlGroupIdsOnTarget = new Set<Id>(); // source group ids that are on the target
            for(SBQQ__QuoteLineGroup__c sourceOrTargetQlGroup : sourceAndTargetQlGroups.values()) {
                if(sourceOrTargetQlGroup.SBQQ__Quote__c == targetXObjectId) {
                    sourceQlGroupIdsOnTarget.add(sourceOrTargetQlGroup.SBQQ__Source__c);
                }
            }

            List<SBQQ__QuoteLineGroup__c> qlGroupClones = new List<SBQQ__QuoteLineGroup__c>(); // quote line group clones to insert
            for(SBQQ__QuoteLineGroup__c sourceOrTargetQlGroup : sourceAndTargetQlGroups.values()) {
                // if it is a group already on the target quote:
                if(sourceOrTargetQlGroup.SBQQ__Quote__c == targetXObjectId) {
                    sourceQlGroupIdToQlGroupClone.put(sourceOrTargetQlGroup.SBQQ__Source__c, sourceOrTargetQlGroup);
                } else if(sourceOrTargetQlGroup.SBQQ__Quote__c == sourceXObjectId
                    && !sourceQlGroupIdsOnTarget.contains(sourceOrTargetQlGroup.Id)
                ) {
                    // if the group from the source quote has yet to be created on the target quote:
                    SBQQ__QuoteLineGroup__c qlGroupClone = sourceOrTargetQlGroup.clone(false, false);
                    qlGroupClone.SBQQ__Quote__c = targetXObjectId;
                    qlGroupClone.SBQQ__Source__c = sourceOrTargetQlGroup.Id;
                    qlGroupClones.add(qlGroupClone);
                }
            }

            // insert quote line group clones, which will be empty at first until later in the execution:
            if(!qlGroupClones.isEmpty()) {
                insert qlGroupClones;
                for(SBQQ__QuoteLineGroup__c qlGroupClone : qlGroupClones) {
                    Id sourceQlGroupId = qlGroupClone.getCloneSourceId();
                    sourceQlGroupIdToQlGroupClone.put(sourceQlGroupId, qlGroupClone);
                }
            }
        }
    }

    /**
    * @description -> Method to create tier 1 line clones for the specified bundles to clone.
    * @param Id sourceXObjectId -> the quote, contract, or order to clone the bundle(s) from
    * @param List<SObject> bundlesToProcess -> the bundles to process
     * @param Id targetXObjectId -> the target xObject Id (whether it's a Contract Id, Quote Id, or Order Id)
    * @return List<SObject> tier1Lines -> tier 1 line clones that have been created in memory, but haven't been inserted yet.
    */
    private static List<SObject> createTier1Lines(
        List<SObject> bundlesToProcess, Id targetXObjectId, Id targetAccountId, Map<String, Integer> lineQuantityMap, Map<Id, Id> sourceXObjectIdToTargetXObjectId
    ) {
        // create the ultimate parent lines:
        List<SObject> tier1Lines = new List<SObject>();
        for(SObject tier1Line : bundlesToProcess) {
            SObject newTier1Line = tier1Line.clone(false, false); 
            newTier1Line = setBasicFieldsForLineClone(newTier1Line, targetXObjectId, targetAccountId, lineQuantityMap, sourceXObjectIdToTargetXObjectId);
            tier1Lines.add(newTier1Line);
        }
        return tier1Lines;
    }

    /**
    * @description -> Method to insert tier 1 line clones for the specified bundles to clone.
    * @param List<SObject> tier1Lines -> the tier 1 lines clones to insert
    * @return List<SObject> tier1Lines -> tier 1 line clones that have both been created in memory AND inserted (will have the ids)
    */
    private static List<SObject> insertTier1Lines(List<SObject> tier1Lines) {
        if(!tier1Lines.isEmpty()) {
            tier1Lines.sort();
            insert tier1Lines;
        }
        return tier1Lines;
    }

    /**
    * @description -> method to update the tier 1 lines (in the case of RootId needing set):
    * @param List<SObject> tier1Lines -> the tier 1 lines clones to update
    * @return List<SObject> tier1Lines -> tier 1 line clones that now have the root id set (ignore quote lines since they don't have a root id field)
    */
    private static List<SObject> updateTier1Lines(List<SObject> tier1Lines) {
        if(!tier1Lines.isEmpty()) {
            List<SObject> linesToUpdate = new List<SObject>();
            for(SObject line : tier1Lines) {
                CPQFieldMapping cpqFieldMapping = new CPQFieldMapping(line);
                // Quote lines do not have a managed root id field. Also, CPQ does not set root id on tier 1 order products.
                // Therefore, ignore quote lines and order products with the next condition:
                if(cpqFieldMapping.objectType != QUOTELINE_OBJ_NAME_STR && cpqFieldMapping.objectType != ORDERITEM_OBJ_TYPE_STR) {
                    Id recordId = (Id) line.get(ID_STR);
                    line.put(cpqFieldMapping.rootIdKey, recordId); // set the rootId of the tier 1 to itself (CPQ does this for assets and subs)
                    linesToUpdate.add(line);
                }
            }

            if(!linesToUpdate.isEmpty()) {
                linesToUpdate.sort();
                update linesToUpdate;
            }
        }
        return tier1Lines;
    }

    /**
    * @description -> Method to set basic fields for the cloned line
    * @param SObject line -> the quote line, contract line, or order line in which to set the fields on.
     * @param Id targetXObjectId -> the target xObject Id (whether it's a Contract Id, Quote Id, or Order Id) for the lines to be assigned to
    * @return SObject line -> the line for basic fields to be set on (quote line, Asset/Sub, Order Item)
    */
    private static SObject setBasicFieldsForLineClone(
        SObject line, Id targetXObjectId, Id targetAccountId, Map<String, Integer> lineQuantityMap, Map<Id, Id> sourceXObjectIdToTargetXObjectId
    ) {
        CPQFieldMapping cpqFieldMapping = new CPQFieldMapping(line);
        Id sourceLineId = line.getCloneSourceId();
        YObjectInfo lineInfo = yObjectIdTo_yObjectInfoMap.get(sourceLineId);

        // set the SBQQ__Quote__c id for quote lines, SBQQ__Contract__c for subscriptions, and OrderId for order products.
        //  (assets do not have a managed CPQ lookup field to the parent like the other objects do, so it will be blank depending on org):
        if(cpqFieldMapping.cpqMasterObjectIdKey != null) {
            if(targetXObjectId != null) { // simple clone from one source to one target
                line.put(cpqFieldMapping.cpqMasterObjectIdKey, targetXObjectId);
            } else if(sourceXObjectIdToTargetXObjectId != null) { // complex clone from multiple sources to multiple targets (Ex: Large Order generation mixed with Order By - aka order split)
                Id parentXObjectId = (Id) line.get(cpqFieldMapping.cpqMasterObjectIdKey);
                Id targetXObjectIdDynamic = sourceXObjectIdToTargetXObjectId.get(parentXObjectId);
                line.put(cpqFieldMapping.cpqMasterObjectIdKey, targetXObjectIdDynamic);
            } else {
                return null;
            }
        }

        // if we're dealing with a decommission/quantity reduction scenario (this is rare):
        line = parseDecommissionQuantity(line, lineInfo, cpqFieldMapping, lineQuantityMap);

        if(lineInfo != null && cpqFieldMapping.objectType == ASSET_OBJ_TYPE_STR) {
            if(targetAccountId != null) {
                line.put(cpqFieldMapping.accountIdKey, targetAccountId);
            }
        } else if(cpqFieldMapping.objectType == SUBSCRIPTION_OBJ_TYPE_STR) {
            if(targetAccountId != null) {
                line.put(cpqFieldMapping.accountIdKey, targetAccountId);
            }
        } else if(cpqFieldMapping.objectType == QUOTELINE_OBJ_NAME_STR) {
            line.put(QUOTELINE_SOURCE_FIELD_REF, line.getCloneSourceId());

            Id sourceQlGroupId = (Id) line.get(QUOTELINE_GROUP_FIELD_REF);
            if(sourceQlGroupId != null) {
                SBQQ__QuoteLineGroup__c qlGroupClone = sourceQlGroupIdToQlGroupClone.get(sourceQlGroupId);
                // reassign the quote line clone's SBQQ__Group__c value to the QL group clone:
                line.put(QUOTELINE_GROUP_FIELD_REF, qlGroupClone.Id);
            }            
        } else if(cpqFieldMapping.objectType == ORDERITEM_OBJ_TYPE_STR) {
            if(ORDER_ITEM_SOURCE_FIELD_REF != null) { // if ORDER_ITEM_SOURCE_FIELD_REF was set by the main code performing the clone
                line.put(ORDER_ITEM_SOURCE_FIELD_REF, line.getCloneSourceId());
            }
        }

        return line;
    }

    /**
    * @description -> method to parse decommission quantity, if lineQuantityMap was specified in the cloneBundles method params.
    * @param SObject line -> the line (asset/sub/quote line, etc) in which to assign an alternate (ex: decommission) quantity to
    * @return SObject line -> the line with a different (ex: decommission) quantity assigned
    **/
    private static SObject parseDecommissionQuantity(SObject line, YObjectInfo lineInfo, CPQFieldMapping cpqFieldMapping, Map<String, Integer> lineQuantityMap) {
        // if lineQuantityMap was specified in the parameters:
        if(lineQuantityMap != null && lineInfo != null) {
            Integer decommissionQty = lineQuantityMap.get(lineInfo.topBundleId + DECOMMISSIONED_QTY_MAPKEY);
            if(decommissionQty != null) {
                // reassign quantity on the cloned line:
                line.put(cpqFieldMapping.quantityKey, decommissionQty);
            }
        }
        return line;
    }

    /**
    * @description -> method to clone a non-tier 1 line
    * @param Id targetXObjectId -> the quote, contract, or order to clone the bundle(s) from
    * @param Id targetAccountId -> the target account to clone the line onto
    * @param YObjectInfo sourceNonTier1LineInfo -> extended info for the source line that we are cloning
    * @param Map<Id, SObject> sourceLineIdToClonedLine -> a map of source line Id to already inserted clones
    * @param Map<String, Integer> lineQuantityMap (optional) -> parameter to specify different quantities for the cloned lines
    * @param  Map<Id, Id> sourceXObjectIdToTargetXObjectId (optional) -> parameter for complex cloning scenarios where multiple source XObjects are involved 
    * 
    * @return SObject newNonTier1Line -> the line clone, which hasn't been inserted yet
    */
    private static SObject cloneChildLine(
        Id targetXObjectId, Id targetAccountId, YObjectInfo sourceNonTier1LineInfo, 
        Map<String, SObject> sourceLineIdToClonedLine, Map<String, Integer> lineQuantityMap, Map<Id, Id> sourceXObjectIdToTargetXObjectId
    ) {
        // get the CPQ Field Keys for the line, whether that's a quote line, an asset/sub line, or an order product lin:
        CPQFieldMapping cpqFieldMapping = new CPQFieldMapping(sourceNonTier1LineInfo.yObject);

        SObject newNonTier1Line = sourceNonTier1LineInfo.yObject.clone(false, false);
        newNonTier1Line = setBasicFieldsForLineClone(newNonTier1Line, targetXObjectId, targetAccountId, lineQuantityMap, sourceXObjectIdToTargetXObjectId);	

        // requiredBy field will be SBQQ__RequiredBy__c for quote lines and order products, 
        //  but SBQQ__RequiredById__c for assets/subs.
        // Get the requiredBy Id of the source line:
        //Id sourceRequiredById = (Id) newNonTier1Line.get(cpqFieldMapping.requiredByIdKey);
        Id sourceRequiredById = (Id) newNonTier1Line.get(cpqFieldMapping.parentIdKey);
        SObject targetRequiredByObj = sourceLineIdToClonedLine.get(sourceRequiredById); // the parent that has ALREADY been inserted
        System.debug('CPQU_BundleStructureUtils.cloneChildLine sourceNonTier1LineInfo.yObject.get(ID_STR): ' + sourceNonTier1LineInfo.yObject.get(ID_STR) + ' sourceRequiredById: ' + sourceRequiredById + ' targetRequiredByObj: ' + targetRequiredByObj);
        // Use the requiredBy Id of the source line to get the requiredBy line of the clone:
        newNonTier1Line.put(cpqFieldMapping.requiredByIdKey, targetRequiredByObj.get(ID_STR));

        // set managed CPQ fields for Asset and Subscription lines (as well as Order Products):
        if(cpqFieldMapping.objectType == ASSET_OBJ_TYPE_STR 
            || cpqFieldMapping.objectType == SUBSCRIPTION_OBJ_TYPE_STR
            || cpqFieldMapping.objectType == ORDERITEM_OBJ_TYPE_STR
        ) {
            // set the root id for Assets, Subscriptions, or Order Products by pulling it off the new tier 1 parent for the first iteration of tiers.
            //  for the next iteration of tiers, we can pull it off the parent above them.
            Id rootId = (Id) targetRequiredByObj.get(cpqFieldMapping.rootIdKey);
            newNonTier1Line.put(cpqFieldMapping.rootIdKey, rootId);
            System.debug(LoggingLevel.WARN, 'CPQUL_BundleStructureUtils.cloneChildLine cpqFieldMapping.rootIdKey: ' + cpqFieldMapping.rootIdKey + ' targetRequiredByObj.get(ID_STR): ' + targetRequiredByObj.get(ID_STR));
            if(cpqFieldMapping.objectType == ASSET_OBJ_TYPE_STR) {
                Id rootObjectId = (Id) targetRequiredByObj.get(ROOT_ID_FIELD_REF);
                String rootObjectType = String.valueOf(rootObjectId.getSobjectType());
                if(rootObjectType == ASSET_OBJ_TYPE_STR) {
                    newNonTier1Line.put(ROOT_ASSET_FIELD_REF, rootObjectId);
                }
                
                // if asset's parent is an asset:
                if(targetRequiredByObj instanceof Asset) {
                    // set the SBQQ__RequiredByAsset__c field on asset:
                    Id requiredByAssetId = (Id) targetRequiredByObj.get(ID_STR);
                    newNonTier1Line.put(REQUIRED_BY_ASSET_FIELD_REF, requiredByAssetId);
                // if asset's parent is a subscription:
                } else if(targetRequiredByObj instanceof SBQQ__Subscription__c) {
                    // set the SBQQ__RequiredBySubscription__c field on asset:
                    Id requiredBySubId = (Id) targetRequiredByObj.get(ID_STR);
                    newNonTier1Line.put(REQUIRED_BY_SUB_FIELD_REF, requiredBySubId);
                }
            }
        }	
        
        return newNonTier1Line;
    } 

    /**
    * @description -> method to apply remaining field updates to lines (ex: Set CombineKey on assets)
    * @param Map<Id, SObject> lineClones -> the lines in which to apply remaining updates.
    * @return Map<Id, SObject> lineClones -> the lines in which remaining updates were applied
    */
    private static Map<Id, SObject> applyRemainingFieldUpdates(Map<Id, SObject> lineClones) {
        return applyRemainingFieldUpdates(lineClones, null);
    }
    /**
    * @param Map<String, Integer> lineQuantityMap -> optional parameter to specific different quantities for the cloned lines
    */
    private static Map<Id, SObject> applyRemainingFieldUpdates(Map<Id, SObject> lineClones, Map<String, Integer> lineQuantityMap) {
        Map<Id, SObject> linesToUpdate = new Map<Id, SObject>();
        for(SObject line : lineClones.values()) {
            CPQFieldMapping cpqFieldMapping = new CPQFieldMapping(line);
            Id lineRecordId = (Id) line.get(ID_STR);
            Id sourceLineId = line.getCloneSourceId();
            YObjectInfo lineInfo = yObjectIdTo_yObjectInfoMap.get(sourceLineId);

            if(lineInfo != null && (cpqFieldMapping.objectType == ASSET_OBJ_TYPE_STR || cpqFieldMapping.objectType == SUBSCRIPTION_OBJ_TYPE_STR)) {
                if(cpqFieldMapping.objectType == ASSET_OBJ_TYPE_STR) {
                    // assign the combine key to the id of the asset itself:
                    line.put(COMBINE_KEY_FIELD_REF, lineRecordId);
                    linesToUpdate.put(lineRecordId, line);
                }

                // get the bundle's new quantity value (if specified in the params):
                if(lineQuantityMap != null) {
                    Integer newQtyForLine = lineQuantityMap.get(lineInfo.topBundleId + NEW_QTY_MAPKEY);
                    if(newQtyForLine != null) {
                        if(cpqFieldMapping.objectType == ASSET_OBJ_TYPE_STR) {
                            // reduce quantity on the source asset (the asset that is moving forward to the new contract):
                            Asset assetMovingForward = new Asset(Id = sourceLineId, Quantity = newQtyForLine, SBQQ__CombineKey__c = lineRecordId);
                            linesToUpdate.put(assetMovingForward.Id, assetMovingForward);
                        } else if(cpqFieldMapping.objectType == SUBSCRIPTION_OBJ_TYPE_STR) {
                            // reduce quantity on the source subscription (the previous subscription that now should have a SBQQ__RenewedDate__c populated):
                            SBQQ__Subscription__c renewedSubscription = new SBQQ__Subscription__c(Id = sourceLineId, SBQQ__Quantity__c = newQtyForLine);
                            linesToUpdate.put(renewedSubscription.Id, renewedSubscription);
                        }
                    }
                }
            }
        }

        if(!linesToUpdate.isEmpty()) {
            // sort the sObjects so that we don't get the stack of 10 dml error:
            linesToUpdate = CPQU_ApexUtils.mapSorterByObjType(linesToUpdate);
            update linesToUpdate.values();
        }

        return lineClones;
    }

    /**
    * @description -> method to create subscribed assets for cloned subscription/asset bundles:
    * @param Map<String, SObject> sourceLineIdToClonedLine -> a map of the clone's source Id to the actual clone itself
    * @return List<SBQQ__SubscribedAsset__c> newSubscribedAssets -> a list of newly created Subscribed Assets
    */
    private static List<SObject> createSubscribedAssets(Map<String, SObject> sourceLineIdToClonedLine) {
        // get existing subscribed assets:
        Set<Id> sourceIdKeys = new Set<Id>( (List<Id>)new List<String>( sourceLineIdToClonedLine.keySet()));
        List<SBQQ__SubscribedAsset__c> sourceSubscribedAssets = Database.query(
            'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('SBQQ__SubscribedAsset__c') + ' FROM ' + 'SBQQ__SubscribedAsset__c ' +
            'WHERE SBQQ__Asset__c IN :sourceIdKeys OR SBQQ__Subscription__c IN :sourceIdKeys'
        );
        
        List<SBQQ__SubscribedAsset__c> newSubscribedAssets = new List<SBQQ__SubscribedAsset__c>();
        for(SBQQ__SubscribedAsset__c aSubscribedAsset : sourceSubscribedAssets) {
            if(
                sourceLineIdToClonedLine.containsKey(aSubscribedAsset.SBQQ__Asset__c)
                && sourceLineIdToClonedLine.containsKey(aSubscribedAsset.SBQQ__Subscription__c)
            ) {
                SBQQ__SubscribedAsset__c clonedSubscribedAsset = aSubscribedAsset.clone(false, true);
                clonedSubscribedAsset.SBQQ__Asset__c = sourceLineIdToClonedLine.get(aSubscribedAsset.SBQQ__Asset__c).Id;
                clonedSubscribedAsset.SBQQ__Subscription__c = sourceLineIdToClonedLine.get(aSubscribedAsset.SBQQ__Subscription__c).Id;
                newSubscribedAssets.add(clonedSubscribedAsset);
            }
        }
        System.debug(LoggingLevel.INFO, 'CPQU_BundleStructureUtils.createSubscribedAssets newSubscribedAssets.size(): ' + newSubscribedAssets.size());
        System.debug(LoggingLevel.INFO, 'CPQU_BundleStructureUtils.createSubscribedAssets newSubscribedAssets: ' + newSubscribedAssets);

        if(!newSubscribedAssets.isEmpty()) {
            insert newSubscribedAssets;
        }

        return newSubscribedAssets;
    }

    /**
    * @description -> TODO: figure out if cloning discount schedules, block prices, etc is even necessary before continuing dev work on this method.
    *   Method to clone the essential children of quote line (ex: SBQQ__DiscountSchedule__c, SBQQ__BlockPrice__c, etc)
    * @param Map<String, SObject> sourceLineIdToClonedLine -> a map of the clone's source Id to the actual clone itself
    * @return List<SBQQ__DiscountSchedule__c> newSubscribedAssets -> a list of newly created Subscribed Assets
    */
    private static List<SObject> cloneEssentialChildrenOfQuoteLine(Map<String, SObject> sourceLineIdToClonedLine) {
        Set<Id> sourceIdKeys = new Set<Id>( (List<Id>)new List<String>( sourceLineIdToClonedLine.keySet()));

        // Clone discount schedules from quote lines:
        String dsQueryStr = 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('SBQQ__DiscountSchedule__c');
        dsQueryStr += ' WHERE SBQQ__QuoteLine__c IN :sourceIdKeys';
        List<SBQQ__DiscountSchedule__c> discountSchedules = Database.query(dsQueryStr);

        List<SBQQ__DiscountSchedule__c> discountScheduleClones = new List<SBQQ__DiscountSchedule__c>();
        for(SBQQ__DiscountSchedule__c discountSchedule : discountSchedules) {
            if(sourceLineIdToClonedLine.containsKey(discountSchedule.SBQQ__QuoteLine__c)) {
                SBQQ__DiscountSchedule__c discountScheduleClone = discountSchedule.clone(false, true);
                discountScheduleClone.SBQQ__QuoteLine__c = sourceLineIdToClonedLine.get(discountSchedule.SBQQ__QuoteLine__c).Id;
                discountScheduleClones.add(discountScheduleClone);
            }
        }

        if(!discountScheduleClones.isEmpty()) {
            insert discountScheduleClones;
        }

        return discountScheduleClones;
    }

    /**
    * @description -> method to create Customer Assets for cloned Asset/Subscription bundles:
    * @param Map<String, SObject> sourceLineIdToClonedLine -> a map of the clone's source Id to the actual clone itself
    * @return List<SObject> newCustomerAssets -> a list of newly created Subscribed Assets
    */
    // private static List<SObject> createCustomerAssets(Map<String, SObject> sourceLineIdToClonedLine) {
    //     Set<Id> sourceIdKeys = new Set<Id>( (List<Id>)new List<String>( sourceLineIdToClonedLine.keySet()));
    //     // get existing customer assets:
    //     List<Customer_Asset__c> sourceCustomerAssets = Database.query(
    //         'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr('Customer_Asset__c') + ' FROM ' + 'Customer_Asset__c ' +
    //         'WHERE Steelbrick_Asset__c IN :sourceIdKeys OR Steelbrick_Subscription__c IN :sourceIdKeys'
    //     );
        
    //     System.debug(LoggingLevel.INFO, 'CPQU_BundleStructureUtils.createCustomerAssets sourceCustomerAssets: ' + sourceCustomerAssets);

    //     // clone the customer assets in the source bundle and associate them to the cloned bundle and the cloned bundle's contract/account
    //     List<Customer_Asset__c> newCustomerAssets = new List<Customer_Asset__c>();
    //     for (Customer_Asset__c customerAsset : sourceCustomerAssets) {
    //         if(sourceLineIdToClonedLine.containsKey(customerAsset.Steelbrick_Asset__c)) {
    //             Customer_Asset__c clonedCustomerAsset = customerAsset.clone(false, true);
    //             Asset assetClone = (Asset) sourceLineIdToClonedLine.get(customerAsset.Steelbrick_Asset__c);
    //             clonedCustomerAsset.Steelbrick_Asset__c = assetClone.Id;
    //             clonedCustomerAsset.Quantity__c = assetClone.Quantity;
    //             clonedCustomerAsset.Contract__c = assetClone.Contract__c;
    //             clonedCustomerAsset.Account__c = assetClone.AccountId;
    //             newCustomerAssets.add(clonedCustomerAsset);
    //         } else if(sourceLineIdToClonedLine.containsKey(customerAsset.Steelbrick_Subscription__c)) {
    //             Customer_Asset__c clonedCustomerAsset = customerAsset.clone(false, true);
    //             SBQQ__Subscription__c subscriptionClone = (SBQQ__Subscription__c) sourceLineIdToClonedLine.get(customerAsset.Steelbrick_Subscription__c);
    //             clonedCustomerAsset.Steelbrick_Subscription__c = subscriptionClone.Id;
    //             clonedCustomerAsset.Quantity__c = subscriptionClone.SBQQ__Quantity__c;
    //             clonedCustomerAsset.Contract__c = subscriptionClone.SBQQ__Contract__c;
    //             clonedCustomerAsset.Account__c = subscriptionClone.SBQQ__Account__c;
    //             newCustomerAssets.add(clonedCustomerAsset);
    //         }
    //     }

    //     System.debug(LoggingLevel.INFO, 'CPQU_BundleStructureUtils.createCustomerAssets newCustomerAssets: ' + newCustomerAssets);

    //     if (!newCustomerAssets.isEmpty()) {
    //         insert newCustomerAssets;
    //     }

    //     return newCustomerAssets;
    // }

    /**
     * @description -> method to map each tier to its respective list of lines at that tier.
     * @param List<SObject> applicableSourceLines -> a list of applicable source lines to map to their respective tier number
     * @return Map<Integer, List<yObjectInfo>> tierNumToLineInfosAtTier -> a map of tier number to associated lines in the tier.
    */
    private static Map<Integer, List<YObjectInfo>> getTierNumToLineInfosMap(List<SObject> applicableSourceLines) {
        System.debug('CPQU_BundleStructureUtils.getTierNumToLineInfosMap() applicableSourceLines.size(): ' + applicableSourceLines.size());
        Map<Integer, List<YObjectInfo>> tierNumToLineInfosAtTier = new Map<Integer, List<YObjectInfo>>();
        // loop through the lines and map each line to its associated tier,
        //   (so that we can insert each tier in sequencial order for the given bundleAggregation):
        for(SObject line : applicableSourceLines) {
            Id lineId = (Id) line.get(ID_STR);
            // Map each tier of quote lines to that tier:
            CPQU_BundleStructureUtils.YObjectInfo lineInfo = CPQU_BundleStructureUtils.yObjectIdTo_yObjectInfoMap.get(lineId);
            List<CPQU_BundleStructureUtils.YObjectInfo> lineInfosAtTier = tierNumToLineInfosAtTier.get(lineInfo.tier) == null ? new List<CPQU_BundleStructureUtils.YObjectInfo>() : tierNumToLineInfosAtTier.get(lineInfo.tier);
            lineInfosAtTier.add(lineInfo);
            tierNumToLineInfosAtTier.put(lineInfo.tier, lineInfosAtTier);
        }
        return tierNumToLineInfosAtTier;
    }

    /**
     * @description -> method to delete specified bundles and all of their children.
     * @param Id sourceXObjectId -> the quote, contract, or order you wish to delete bundles off of
     * @param Set<Id> bundlesToDelete -> a set of ids for bundles you wish to delete. All children underneath these bundles will be 
     *  deleted as well.
     * @return void
    */
    public static void deleteBundles(Id sourceXObjectId, Set<Id> bundlesToDelete) {
        if(bundlesToDelete == null || bundlesToDelete.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.deleteBundles: no bundles were specified for deletion.');
            return;
        }

        XObjectData xObjectData = getXObjectData(sourceXObjectId);
        Map<Id, Map<Id, SObject>> topBundleIdToLinesInBundle = xObjectData.xObjectBundleStructure.topBundleIdToLinesInBundle;

        List<SObject> linesToDelete = new List<SObject>();
        // loop through each bundle on the source XObject (quote, contract, or Order)
        for(Id topBundleId : topBundleIdToLinesInBundle.keySet()) {
            // if the bundle id was passed in to the method, move it and all of its child lines:
            if(bundlesToDelete.contains(topBundleId)) {
                // loop through the lines on the source Contract bundle and assign to the target contract
                for(SObject yObject : topBundleIdToLinesInBundle.get(topBundleId).values()) {
                    linesToDelete.add(yObject);
                }
            }
        }

        if(!linesToDelete.isEmpty()) {
            linesToDelete.sort(); // sort to avoid chunking errors
            System.debug(LoggingLevel.WARN, 'CPQU_BundleStructureUtils.deleteBundles linesToDelete: ' + linesToDelete);
            delete linesToDelete;
        }
    }

    /**
     * END CLONING METHODS/HELPERS
     */

    /**
     * BEGIN MOVE BUNDLE METHODS/HELPERS
     */

    /**
    * @description -> move contract bundles from one contract to another
    *   Note: we can't move quote lines to another quote due to the quote lookup on quote line being a master-detail relationship. 
    *   Same applies for order products. We can't move them either due to the order lookup on order product being a master-detail relationship.
    *   We can, however, move subscriptions between contracts.
    * @param Id sourceContractId -> an id of the source contract in which to move bundles from
    * @param Id targetContractId -> an id of the target contract in which to move bundles to
    * @param (optional) Set<Id> bundlesToMove -> a specific set of contract bundles (ids) to move
    * @param (optional) Boolean doUpdate -> whether or not to update the records. There may be use cases where we just want to return them.
    * @return Map<Id, SObject> -> the moved assets/subscriptions
    */
    // V1: moves all contract bundles from source contract to target contract:
    public static Map<Id, SObject> moveContractBundles(Id sourceContractId, Id targetContractId) { 
        return (moveContractBundles(sourceContractId, targetContractId, null, true));
    }
    // V2: moves all contract bundles from source contract to target contract, while specifying a scenario (ex: Generate Large Contract):
    public static Map<Id, SObject> moveContractBundles(Id sourceContractId, Id targetContractId, Boolean doUpdate) { 
        return (moveContractBundles(sourceContractId, targetContractId, null, doUpdate));
    }
    // V3: moves specific contract bundles from source contract to target contract:
    public static Map<Id, SObject> moveContractBundles(Id sourceContractId, Id targetContractId, Set<Id> bundlesToMove) {
        return (moveContractBundles(sourceContractId, targetContractId, bundlesToMove, true));
    }
    // V2: moves specific contract bundles from source contract to target contract, while specifiying a scenario (ex: Generate Large Contract):
    public static Map<Id, SObject> moveContractBundles(Id sourceContractId, Id targetContractId, Set<Id> bundlesToMove, Boolean doUpdate) {
        XObjectData xObjectData = getXObjectData(sourceContractId);
        if(xObjectData.xObjectType != CONTRACT_STR) {
            StringException e = new StringException();
            e.setMessage('The object type for the Id passed to CPQU_BundleStructureUtils.moveContractBundles must be a Contract. You cannot move bundles between Quotes or Orders.');
            throw e;
        }

        Map<Id, Map<Id, SObject>> topBundleIdToLinesInBundle = xObjectData.xObjectBundleStructure.topBundleIdToLinesInBundle;
        Map<Id, SObject> linesToUpdate = new Map<Id, SObject>();
        // loop through each bundle on the source Contract:
        for(Id topBundleId : topBundleIdToLinesInBundle.keySet()) {
            // if the bundle id was passed in to the method, move it and all of its child lines:
            if(bundlesToMove == null || (bundlesToMove != null && bundlesToMove.contains(topBundleId))) {
                // loop through the lines on the source Contract bundle and assign to the target contract
                for(SObject line : topBundleIdToLinesInBundle.get(topBundleId).values()) {
                    Id recordId = (Id) line.get(ID_STR);                    
                    CPQFieldMapping cpqFieldMapping = new CPQFieldMapping(line);
                    if(cpqFieldMapping.cpqMasterObjectIdKey != null) {
                        // this is where the contract field reassignment happens on subscription:
                        line.put(cpqFieldMapping.cpqMasterObjectIdKey, targetContractId);
                        linesToUpdate.put(recordId, line);
                    }
                }
            }
        }

        if(!linesToUpdate.isEmpty()) {
            // sort the sObjects so that we don't get the stack of 10 dml error:
            linesToUpdate = CPQU_ApexUtils.mapSorterByObjType(linesToUpdate);
            if(doUpdate) {
                update linesToUpdate.values();
            }
        }

        return linesToUpdate;
    }

    /**
     * @description -> Method to check for line number sequencing issues on Contract Subscriptions (and their associated assets), or Quote lines.
     * @param xObjectId -> the Id of the Contract or Quote, in which to scan its lines for line number sequencing issues
     * @return Boolean -> whether or not the Contract or Quote has sequencing issues
     */
    public static Boolean hasLineNumberSequencingIssues(Id xObjectId) {
        XObjectData xObjectData = getXObjectData(xObjectId);
        if(xObjectData.xObjectType != CONTRACT_STR && xObjectData.xObjectType != QUOTE_FIELD_REF) {
            StringException e = new StringException();
            e.setMessage('The Object (XObject) type of the xObjectId parameter must be a Contract or SBQQ__Quote__c in order to scan it for line number sequencing issues.');
            throw e;
        }

        BundleStructure xObjectBundleStructure = xObjectData.xObjectBundleStructure;
        Set<Integer> uniqueLineNumbers = new Set<Integer>();
        Integer highestLineNumber = 0;
        Integer totalNumberOfLines = xObjectBundleStructure.yObjectIdTo_yObjectInfoMap.size();
        
        Boolean reachedNextTopParent = false;
        Id currentTopBundleId;

        for(YObjectInfo yObjectInfo : xObjectBundleStructure.yObjectIdTo_yObjectInfoMap.values()) {
            SObject line = yObjectInfo.yObject;        
            CPQFieldMapping cpqFieldMapping = new CPQFieldMapping(line);

            Id requiredBy = (Id) line.get(cpqFieldMapping.parentIdKey);
            Id recordId = (Id) line.get(ID_STR);
            if(requiredBy == null) {
                reachedNextTopParent = true;
                currentTopBundleId = (Id) line.get(ID_STR);
            } else {
                reachedNextTopParent = false;
            }

            // if we haven't reached the next parent yet, but the topBundleId is something other than the currentTopBundleId:
            if(requiredBy != null && !reachedNextTopParent && yObjectInfo.topBundleId != currentTopBundleId) {
                return true;
            }

            Integer lineNumber = (Integer)((Decimal)line.get(SBQQNUMBER_FIELD_REF));
            if(!uniqueLineNumbers.contains(lineNumber)) {
                uniqueLineNumbers.add(lineNumber);
            } else {
                // if we made it in this else statement, there are duplicate line numbers on the xObject
                return true;
            }
            
            if(lineNumber > highestLineNumber) {
                highestLineNumber = lineNumber;
            }
        }

        // highest line number must be equal to the total number of lines, else we have a sequencing issue:
        if(highestLineNumber != totalNumberOfLines) {
            return true;
        }

        return false;
    }

    /**
    * @description : Given a quote Id, build a page reference for redirecting to the quote line editor for that quote.
    *  Example sandbox URL: 
    *   https://companyname--dev--sbqq.cs50.visual.force.com/apex/sb?scontrolCaching=1&id=a0l3B00000181MS#quote/le?qId=a0l3B00000181MS
    *  Example prod URL:
    *   https://companyname--sbqq.na77.visual.force.com/apex/sb?scontrolCaching=1&id=a0l1M00000JQxws#quote/le?qId=a0l1M00000JQxws
    * @param Id quoteId -> the id of the quote used to invoke the QLE
    * @return PageReference qlePageRef -> a page reference to the quote line editor.
    **/
    public static PageReference quoteLineEditorPageRef(Id quoteId) {
        String quoteLineEditorURL = CPQU_ApexUtils.subDomainWithProtocol + '--sbqq.' + CPQU_ApexUtils.getInstanceName() +
            '.visual.force.com/apex/sb?scontrolCaching=1&id=' + quoteId + '#quote/le?qId=' + quoteId;
        quoteLineEditorURL = quoteLineEditorURL.replace('--c--', '--');

        PageReference qlePageRef = new PageReference(quoteLineEditorURL);
        qlePageRef.setRedirect(true);
        return qlePageRef;
    }
    
    // Method to get the tier number for a quote line or order product the basic way via traversing a pre-determined max number of tiers.
    // In this case, this max number is 3 (because of the 3 tier bundle structure).
    public static Integer getTierNumBasic(SObject line) {
        Integer tier;
        try {
            if(line instanceof SBQQ__QuoteLine__c) {
                SBQQ__QuoteLine__c quoteLine = (SBQQ__QuoteLine__c) line;
                if (quoteLine.SBQQ__RequiredBy__c == null) { // tier 1
                    tier = 1;
                } else if (quoteLine.SBQQ__RequiredBy__r.SBQQ__RequiredBy__c != null) { // tier 3
                    tier = 3;
                } else if (quoteLine.SBQQ__RequiredBy__r.SBQQ__RequiredBy__c == null) { // tier 2
                    tier = 2;
                }
            } else if(line instanceof OrderItem) {
                OrderItem orderItem = (OrderItem) line;
                if (orderItem.SBQQ__RequiredBy__c == null) { // tier 1
                    tier = 1;
                } else if (orderItem.SBQQ__RequiredBy__r.SBQQ__RequiredBy__c != null) { // tier 3
                    tier = 3;
                } else if (orderItem.SBQQ__RequiredBy__r.SBQQ__RequiredBy__c == null) { // tier 2
                    tier = 2;
                }
            }
        } catch(Exception e) {
            System.debug('CPQU_BundleStructureUtils.getTierNumBasic exception: ' + e.getMessage());
        }
    
        return tier;
    }

    /**
     * Clones a list of related objects to a set of parent objects and assigns the clones to the target set of xobjects.
     * @param targetXObjectIdToOriginalXObjectId a map of Id to Id where the key is the XObject (newly created) which will get assigned on the clones and the value is the Id of the original XObject the list is cloning from.
     * @param listObjectName object name of the List Objects.
     * @param listSObjectFieldReferenceToParent SObjectField reference to the field on the listObject which connects to the parent.
     * @param doInsert - perform the insert
     *
     * @return Map of target parent id to the list of listObjects that were cloned
     */
    public static Map<String, List<SObject>> cloneRelatedListToXObject(String listObjectName, Map<Id, Id> targetXObjectIdToOriginalXObjectId, SObjectField listSObjectFieldReferenceToParent, Map<Id, Id> originalXObjectCustomIdToTargetXObjectCustomId, SObjectField listSObjectFieldReferenceToCustomId, Boolean doInsert) {
        System.debug('ApexUtils.cloneRelatedListToXObject() targetXObjectIdToOriginalXObjectId: ' + targetXObjectIdToOriginalXObjectId);

        List<Id> originalXObjectIds = targetXObjectIdToOriginalXObjectId.values();
        System.debug('ApexUtils.cloneRelatedListToXObject() originalXObjectIds: ' + originalXObjectIds);

        String soql = 'SELECT ' + CPQU_ApexUtils.getAllFieldsForSObjAsStr(listObjectName) + ' FROM ' +  listObjectName + ' WHERE ' + listSObjectFieldReferenceToParent  + ' IN :originalXObjectIds';
        List<SObject> listXObjects = Database.query(soql);

        List<SObject> listXObjectsToInsert = new List<SObject>();
        if(!listXObjects.isEmpty()) {
            Map<String, List<SObject>> listXObjectsByOriginalId = CPQU_ApexUtils.groupBy(listXObjects, listSObjectFieldReferenceToParent);

            for (Id targetXObjectId : targetXObjectIdToOriginalXObjectId.keySet()) {
                if(listXObjectsByOriginalId.containsKey(targetXObjectIdToOriginalXObjectId.get(targetXObjectId))) {
                    List<SObject> listOfListXObjects = listXObjectsByOriginalId.get(targetXObjectIdToOriginalXObjectId.get(targetXObjectId));
                    for (SObject listXObject : listOfListXObjects) {
                        SObject newListXObject = listXObject.clone(false, true);
                        newListXObject.put(listSObjectFieldReferenceToParent, targetXObjectId);
                        if(listSObjectFieldReferenceToCustomId != null && originalXObjectCustomIdToTargetXObjectCustomId != null
                            && originalXObjectCustomIdToTargetXObjectCustomId.containsKey((Id) newListXObject.get(listSObjectFieldReferenceToCustomId))) {
                            newListXObject.put(listSObjectFieldReferenceToCustomId, originalXObjectCustomIdToTargetXObjectCustomId.get((Id) newListXObject.get(listSObjectFieldReferenceToCustomId)));
                        }
                        listXObjectsToInsert.add(newListXObject);
                    }
                }
            }
            System.debug('ApexUtils.cloneRelatedListToXObject() listXObjectsToInsert.size(): ' + listXObjectsToInsert.size());

            if (!listXObjectsToInsert.isEmpty() && doInsert) {
                List<Database.SaveResult> saveResults = Database.insert(listXObjectsToInsert, false);

                for (Database.SaveResult saveResult : saveResults) {
                    if (saveResult.isSuccess()) {
                        // Operation was successful, so get the ID of the record that was processed
                        System.debug(LoggingLevel.FINE, 'ApexUtils.cloneRelatedListToXObject() Successfully updated target line item. : ' + saveResult.getId());
                    } else {
                        // Operation failed, so get all errors
                        for (Database.Error err : saveResult.getErrors()) {
                            //newBatchJobLog.addError(err.fields.toString(), err.getMessage());
                            System.debug('ApexUtils.cloneRelatedListToXObject() The following error has occurred.');
                            System.debug('ApexUtils.cloneRelatedListToXObject() ' + err.getStatusCode() + ': ' + err.getMessage());
                            System.debug('ApexUtils.cloneRelatedListToXObject() fields that affected this error: ' + err.getFields());
                        }
                    }
                }
            }
        }
        return CPQU_ApexUtils.groupBy(listXObjectsToInsert, listSObjectFieldReferenceToParent);
    }
}