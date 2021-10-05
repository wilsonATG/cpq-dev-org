/*
 * Name: CPQU_Constants
 * Description: store shared contants for apex classes that pertain to one of the following areas:
 *   > Advanced Related List
 *   > CPQ Governor Limit workarounds
 *
 * Created ?
 * Updated: 8.30.2019 : Kevin Antonioli
 */
public with sharing class CPQU_Constants {
    public static final String SUCCESS_ENTRY = 'Success';
    public static final String ERROR_ENTRY = 'Error';
    public static final String ERROR_INFLIGHT_INDICATOR = '_in-flight';
    public static final List<String> assetQueryBlacklistFields = new List<String>{'digitalassetstatus', 'productfamily', 'productdescription', 'locationid'};

    public static final String STATUS_DRAFT = 'Draft';
    public static final String STATUS_ACTIVATED = 'Activated';
    public static final String STATUS_EXPIRED = 'Expired';
    public static final String STATUS_QUOTED = 'Quoted';

    public static final String APPLICATION_CPQ = 'CPQ';

    public static final String CUSTOM_SETTING_TRIGGER_BYPASS_SUFFIX = '_Bypass';
    public static final String CUSTOM_SETTING_TRIGGER_BYPASS_WILDCARD = '%' + CUSTOM_SETTING_TRIGGER_BYPASS_SUFFIX + '%';
    public static final String CUSTOM_SETTING_BOOLEAN_FIELD_NAME = 'BooleanValue__c';

    public static final String CUSTOM_FEATURES_ALL_TRIGGER_NAME = 'AllTriggerHandlersDisabled__c';
}