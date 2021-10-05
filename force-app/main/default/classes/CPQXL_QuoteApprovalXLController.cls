/**
 * @Title: CPQXL_QuoteApprovalXLController
 * @description: Created to be able to submit large quotes for approval without hitting governor limit errors.
 *
 * Created by : Kevin Antonioli : 05.11.2020
 */
public without sharing class CPQXL_QuoteApprovalXLController {
    private static final String CLASS_NAME = 'CPQXL_QuoteApprovalXLController';
    private static final String CURRENCY_FIELD_TYPE = 'CURRENCY';
    private static final Map<String, CPQU_UtilitySetting__mdt> utilitySettings = new Map<String, CPQU_UtilitySetting__mdt>();

    // static initialization
    static {
        utilitySettings.putAll(CPQU_ApexUtils.groupSettingsByDeveloperName(
        [SELECT DeveloperName, Label, BooleanValue__c, NumberValue__c, TextValue__c
        FROM CPQU_UtilitySetting__mdt WHERE IsActive__c = TRUE]));
    }

    // quote line aggregation size for each of the Approval Request email line item grids.
    // an Approval Request email could have multiple grids if we're dealing with a large quote.
    private static Integer quoteLineAggregationSize = Integer.valueOf(utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_QUOTE_FLATTEN_LINE_GRID_SIZE).NumberValue__c);

    /**
     * @Description -> method to get the environment name of the org. 
     *   Example: januarytwenty-dev-ed
     * @return String
     */
    @AuraEnabled(Cacheable=true)
    public static String getEnvironmentName() {
        return CPQU_ApexUtils.getEnvironmentName();
    }

    /**
     * @description -> Submit for Approval 2.0 method to use in LWC
     * @param null
     * @return void -> 
     */   
    @AuraEnabled
    public static void onSubmitForApproval2(Id quoteIdParam) {
        System.debug('CPQXL_SubmitForApproval2Controller.onSubmitForApproval2()...');
        SBQQ__Quote__c quote = [
            SELECT Id, SBQQ__LineItemCount__c, SBQQ__Type__c FROM SBQQ__Quote__c WHERE Id = :quoteIdParam
        ];
        try{
            // determine the set of columns to use in the approval email (add more conditions/fieldsets here if desired):
            List<Schema.FieldSetMember> fieldSetMemberList = CPQU_ApexUtils.readFieldSet('SBQQ__LineEditor','SBQQ__QuoteLine__c');
            // if the quote is not a large quote, no need to create the visual line item grid records:
            if(quote.SBQQ__LineItemCount__c <  utilitySettings.get(CPQXL_Constants.UTILITY_SETTING_SUBMIT_LARGE_QUOTE_FOR_APPROVAL_THRESHOLD).NumberValue__c) {
                return;
            }

            // create the visual line item grid records, so that we can display ALL lines in the Approval Request email without hitting a governor limit:
            createVisualLineItemGridRecords(quote, fieldSetMemberList);
        } catch(Exception e) {
            System.debug('CPQXL_SubmitForApproval2Controller.onSubmitForApproval(): FATAL exception occurred: ' + e.getMessage() + '. stack trace: ' + e.getStackTraceString());
            CPQU_ErrorLog__c errorLog = CPQU_ErrorLogUtils.createErrorLog(
                 e, CLASS_NAME + ': failed to Submit large quote for approval.', CLASS_NAME, String.valueOf(quote.Id)
            );
        }
    }

    /**
     * @description -> Method to query the quote lines for the quote we're dealing with on the Submit for Approval 2.0 page.
     * @param Id quoteId -> the Id of the quote we're dealing with on the Submit for APproval 2.0 page
     * @return Map<Id, SBQQ__QuoteLine__c> -> a map of quote lines for the quote we're dealing with on the Submit for Approval 2.0 page.
     */ 
    private static Map<Id, SBQQ__QuoteLine__c> getQuoteLinesMap(Id quoteId, List<Schema.FieldSetMember> fieldSetMemberList) {
        String queryString = 'SELECT Id, SBQQ__Number__c, ' 
            + String.join(CPQU_ApexUtils.getFieldSetFieldAPINames(fieldSetMemberList), ',')
            + ' FROM SBQQ__QuoteLine__c WHERE SBQQ__Quote__c = :quoteId ORDER BY SBQQ__Number__c';

        return new Map<Id, SBQQ__QuoteLine__c>((List<SBQQ__QuoteLine__c>) Database.query(queryString));
    }

    /**
     * @description Flattens a list of the quote's quote lines, into HTML attributes representing product grids. 
     *  These grids are each associated to a CPQXL_QuoteFlattenedLinesGrid__c record (1 grid per record)
     * @param null
     * @return void
     */
    private static void createVisualLineItemGridRecords(SBQQ__Quote__c quote, List<Schema.FieldSetMember> fieldSetMemberList) {
        System.debug(System.LoggingLevel.DEBUG, 'CPQXL_SubmitForApproval2Controller.createVisualLineItemGridRecords quote: ' + quote);
        List<CPQXL_QuoteFlattenedLinesGrid__c> newVisualQuoteLineGrids = new List<CPQXL_QuoteFlattenedLinesGrid__c>();
        Map<Id, SBQQ__QuoteLine__c> quoteLinesMap = getQuoteLinesMap(quote.Id, fieldSetMemberList);
        if(quoteLinesMap != null) {
            // build map of aggregation number to ALL quote lines appicable to that aggregation (quoteLineAggregationSize lines per aggregation):
            Map<Integer, Set<Id>> bundleAggregationsMapExtended =  CPQU_BundleStructureUtils.getBundleAggregationsExtended(
                quote.Id, quoteLineAggregationSize, new Set<String>(), true
            );
            // loop through quote line aggregations:
            for(Integer aggrNumber : bundleAggregationsMapExtended.keySet()) {
                List<SBQQ__QuoteLine__c> quoteLinesInAggr = new List<SBQQ__QuoteLine__c>();
                for(Id qlId : bundleAggregationsMapExtended.get(aggrNumber)) {
                    quoteLinesInAggr.add(quoteLinesMap.get(qlId));
                }
        
                // build a visual line item grid for each aggregation (these grids will display on the Approval Request email):
                OutputLines output = new OutputLines(quote, quoteLinesInAggr, fieldSetMemberList); 
                newVisualQuoteLineGrids.add(new CPQXL_QuoteFlattenedLinesGrid__c(
                    CPQXL_Quote__c = quote.Id,
                    CPQXL_LineItemGridHTML__c = output.quoteLineGridContent
                ));

            }
            
            if(!newVisualQuoteLineGrids.isEmpty()) {
                List<CPQXL_QuoteFlattenedLinesGrid__c> existingVisualQuoteLineGrids = [SELECT Id FROM CPQXL_QuoteFlattenedLinesGrid__c WHERE CPQXL_Quote__c = :quote.Id];
                if(!existingVisualQuoteLineGrids.isEmpty()) {
                    // delete any existing quote line grids pertaining to the quote(s) transitioning to Pending status.
                    // (this will only happen if the approval has been recalled).
                    delete existingVisualQuoteLineGrids;
                }
                insert newVisualQuoteLineGrids;
            }
        }
    }

    /**
     * @description Inner class to format list of quote lines into a visual line item grid.
     * @param SBQQ__Quote__c quote -> the quote that we're dealing with on the Submit for Approval 2.0 page.
     * @param List<SBQQ__QuoteLine__c> the quote lines belonging to the quote that we're dealing with on the Submit for Approval 2.0 page.
     * @return void
     */
    class OutputLines {
        String quoteLineGridContent = '';
        String QUANTITY_FIELD = 'SBQQ__Quantity__c';
        List<Schema.FieldSetMember> fieldSetMemberList;
        Map<String, String> fieldTypeMap = new Map<String, String>{'CURRENCY' => '$', 'PERCENT' => '%'};

        // even though fields say they can have 132000ish characters, the update of FLatten_Lines__c fails if trying to inject much 
        // more than 80000 characters into it.
        Integer maxCharactersForGrid = 80000;
        String headerCellStartOfTagGeneric = '<td align="center" colspan="1" rowspan="1" width="100px" style="background-color: lightgray; font-weight: bold;" ><b>';
        String headerLineNumCellStartOfTag = '<td align="center" colspan="1" rowspan="1" width="100px" style="background-color: lightgray; font-weight: bold;" ><b>';
        String headerQuantityCellStartOfTag = '<td align="center" colspan="1" rowspan="1" width="100px" style="background-color: lightgray; font-weight: bold;" ><b>';
        String headerCellEndOfTag = '</b></td>';

        String trOpenTag = '<tr>';
        String bodyCellStartOfTag = '<td width="100px" align="center"';
        //String defaultBodyCellStyles = 'width="10%" align="left"';
        String closeTag = '>';
        String bodyCellEndOfTag = '</td>';
        String trCloseTag = '</tr>';

        String language = 'English';
        OutputLines(SBQQ__Quote__c quote, List<SBQQ__QuoteLine__c> quoteLines, List<Schema.FieldSetMember> fieldSetMemberList) {
            this.fieldSetMemberList = fieldSetMemberList;

            beginProductGridTable();
            for(SBQQ__QuoteLine__c quoteLine : quoteLines) {
                if(quoteLineGridContent.length() < maxCharactersForGrid) {
                    fullDataRow(quoteLine);
                }
            }
            endProductGridTable();
        }

        /**
         * start the inner html table with column headers
         *
         * @param null
         * @return void
         */
        void beginProductGridTable() {
            quoteLineGridContent += '<table width="100%" cellpadding="1" cellspacing="0" border="1">';
            quoteLineGridContent += trOpenTag;
            quoteLineGridContent += headerCellStartOfTagGeneric  + '#'  + headerCellEndOfTag; // line #

            // initialize a column for every field in the Applicable field set:
            for(Schema.FieldSetMember fieldSetMemberObj : fieldSetMemberList) {   
                quoteLineGridContent += headerCellStartOfTagGeneric  + fieldSetMemberObj.getLabel()  + headerCellEndOfTag;   
            }
            quoteLineGridContent += trCloseTag;
        }

        /**
         * @description -> Method to build a visual table row (that will appear on Approval Request email) for a quote line
         * @param SBQQ__QuoteLine__c quoteLine -> the quote line in which to build a visual table row for.
         * @return void
         */
        void fullDataRow(SBQQ__QuoteLine__c quoteLine) {
            // Flattened_Lines__c column quoteLineGridContent:
            // Note: we cannot vertical align the cell values due to Salesforce limitation.
            quoteLineGridContent += trOpenTag;
            quoteLineGridContent += bodyCellStartOfTag + closeTag + String.valueOf(quoteLine.SBQQ__Number__c) + bodyCellEndOfTag;  

            // loop through the fields in the applicable field set (net new vs renewal, etc) an populate the cell values for the row:
            for(Schema.FieldSetMember fieldSetMemberObj : fieldSetMemberList) {
                String gridCellValue;
                String field = String.valueOf(fieldSetMemberObj.getFieldPath());
                String fieldType = String.valueOf(fieldSetMemberObj.getType());
                String fieldTypeSymbol = fieldTypeMap.containsKey(fieldType) ? fieldTypeMap.get(fieldType) : '';
                
                if(fieldType == CURRENCY_FIELD_TYPE) {
                    gridCellValue = quoteLine.get(field) == null ? '' : String.valueOf( ((Decimal) quoteLine.get(field)).setScale(2).format() );
                } else {
                    gridCellValue = quoteLine.get(field) == null ? '' : String.valueOf(quoteLine.get(field));
                }

                quoteLineGridContent += bodyCellStartOfTag + closeTag + fieldTypeSymbol + gridCellValue + bodyCellEndOfTag;
            }
            quoteLineGridContent += trCloseTag;
        }

        /**
         * generic table end tag
         *
         * @param null
         * @return void
         */
        void endProductGridTable() {
            quoteLineGridContent += '</table>';
        }
    }
}