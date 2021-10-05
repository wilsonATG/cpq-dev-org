/*
 * Name: CPQXL_Constants 
 * Description: store shared contants for apex classes that pertain to one of the following pieces of functionality:
 *   > CPQXL
 *
 * Created : 5.18.2020 : Kevin Antonioli 
 */
public with sharing class CPQXL_Constants {
    public static final String RECORDJOB_STATUS_COMPLETED = 'Completed';
    
    public static final String SUCCESS_ENTRY = 'Success';
    public static final String ERROR_ENTRY = 'Error';

    public static final String COMPLETED_STATUS = 'Completed';
    public static final String FAILED_STATUS = 'Failed'; 
    public static final String JOB_COMPLETED_STATUS = 'Completed';
    public static final String JOB_FAILED_STATUS = 'Failed';
    public static final String QUOTE_CLONE_COMPLETED_STATUS = 'Completed';
	public static final String QUOTE_CLONE_PROCESSING_STATUS = 'Processing';
    public static final String CURRENCY_FIELD_TYPE = 'CURRENCY';
    public static final String PRODUCT_CLASS_ADDON_SOFTWARE = 'Addon Software';
    public static final String LARGE_QUOTE_ASYNC_ORDERING_SCENARIO = 'AsyncOrdering';
    public static final String LARGE_QUOTE_CLONE_SCENARIO = 'CloneLargeQuote';
    public static final String LARGE_QUOTE_SPLIT_SCENARIO = 'SplitLargeQuote';
    public static final String LARGE_ORDER_SCENARIO = 'OrderLargeQuote';
    public static final String LARGE_CONTRACT_SCENARIO = 'ContractLargeOrder';

    public static final String OPPORTUNITY_OBJ_NAME = 'Opportunity';
    public static final String QUOTE_OBJ_NAME = 'SBQQ__Quote__c';

    public static final String GENERATE_LARGE_CONTRACT = 'Generate Large Contract';

    public static final String UTILITY_SETTING_ALLOW_PARTIAL_CLONING_ON_CLONE = 'CPQXL_AllowPartialCloningOnCloneXL';
    public static final String UTILITY_SETTING_CUSTOM_ASSET_TRIGGER_HANDLERS = 'CPQXL_CustomAssetTriggerHandlers';
    public static final String UTILITY_SETTING_CUSTOM_CONTRACT_TRIGGER_HANDLERS = 'CPQXL_CustomContractTriggerHandlers';
    public static final String UTILITY_SETTING_CUSTOM_OPPORTUNITY_TRIGGER_HANDLERS = 'CPQXL_CustomOpportunityTriggerHandlers';
    public static final String UTILITY_SETTING_CUSTOM_ORDER_ITEM_TRIGGER_HANDLERS = 'CPQXL_CustomOrderItemTriggerHandlers';
    public static final String UTILITY_SETTING_CUSTOM_ORDER_TRIGGER_HANDLERS = 'CPQXL_CustomOrderTriggerHandlers';
    public static final String UTILITY_SETTING_CUSTOM_QUOTE_LINE_TRIGGER_HANDLERS = 'CPQXL_CustomQuoteLineTriggerHandlers';
    public static final String UTILITY_SETTING_CUSTOM_QUOTE_TRIGGER_HANDLERS = 'CPQXL_CustomQuoteTriggerHandlers';
    public static final String UTILITY_SETTING_CUSTOM_SUBSCRIPTION_TRIGGER_HANDLERS = 'CPQXL_CustomSubscriptionTriggerHandlers';
    public static final String UTILITY_SETTING_IGNORE_RECALC_FOR_QUOTE_LINE = 'CPQXL_IgnoreRecalcForQuoteClone';
    public static final String UTILITY_SETTING_KEEP_SUBSET_CONTRACTS = 'CPQXL_KeepSubsetContracts';
    public static final String UTILITY_SETTING_KEEP_SUBSET_ORDERS = 'CPQXL_KeepSubsetOrders';
    public static final String UTILITY_SETTING_LARGE_CONTRACT_AGGREGATION_LINE_SIZE = 'CPQXL_LargeContractAggregationLineSize';
    public static final String UTILITY_SETTING_LARGE_CONTRACT_THRESHOLD = 'CPQXL_LargeContractThreshold';
    public static final String UTILITY_SETTING_LARGE_ORDER_AGGREGATIONS_LINE_SIZE = 'CPQXL_LargeOrderAggregationLIneSize';
    public static final String UTILITY_SETTING_LARGE_ORDER_THRESHOLD = 'CPQXL_LargeOrderThreshold';
    public static final String UTILITY_SETTING_ORDER_TRIGGER_HANDLER_BYPASS = 'CPQXL_OrderTriggerHandler_Bypass';
    public static final String UTILITY_SETTING_QUOTE_CLONE_LINE_AGGREGATION_SIZE = 'CPQXL_QuoteCloneLineAggregationSize';
    public static final String UTILITY_SETTING_QUOTE_FLATTEN_LINE_GRID_SIZE = 'CPQXL_QuoteFlattenLinesGridSize';
    public static final String UTILITY_SETTING_CLONE_XL_QUOTE_LINE_FIELD_SET_NAME = 'CPQXL_CloneXLQuoteLineFieldSetName';
    public static final String UTILITY_SETTING_QUOTE_LINE_THRESHOLD = 'CPQXL_QuoteLineThreshold';
    public static final String UTILITY_SETTING_SUBMIT_LARGE_QUOTE_FOR_APPROVAL_THRESHOLD = 'CPQXL_SubmitLargeQuoteForApprThreshold';
    public static final String UTILITY_SETTING_VERY_LARGE_CONTRACT_THRESHOLD = 'CPQXL_VeryLargeContractThreshold';
    public static final String UTILITY_SETTING_VERY_LARGE_ORDER_THRESHOLD = 'CPQXL_VeryLargeOrderThreshold';
}