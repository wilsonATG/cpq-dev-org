public class ContractAmender {

    private static Map<Integer, List<QuoteLineWrapper>> quoteLineWrapperMap = new Map<Integer, List<QuoteLineWrapper>>();

    public class QuoteLineWrapper {
        SBQQ__QuoteLine__c quoteLine {get; private set;}
        Integer parentQuoteLineNumber {get; private set;}

        public QuoteLineWrapper(SBQQ__QuoteLine__c quoteLine, Integer parentQuoteLineNumber) {
            this.quoteLine = quoteLine;
            this.parentQuoteLineNumber = parentQuoteLineNumber;
        }
    }

    public static Integer globalLineNumber = 0;

    public static CPQ_ApiDataModels.QuoteModel makeAmend(String contractId) {
        CPQ_ApiDataModels.QuoteModel quoteModel = null;
        try {
            System.debug('Entering makeAmend.. contractId -> ' + contractId);

            quoteModel = CPQ_ApiHelper.amend(contractId);

            System.debug('After do amender..');

            quoteModel = CPQ_ApiHelper.saveQuote(quoteModel);
            System.debug('ATG: CR Lines: ' + quoteModel.lineItems.size());

        } catch (Exception ex) {
            System.debug('Amend Error: ' + ex.getMessage() + 'line: ' + ex.getLineNumber());
            System.debug('Amend Trace: ' + ex.getStackTraceString());
            System.debug('Amend Cause: ' + ex.getCause());

            throw ex;
        }

        return quoteModel;
    }

    private static void reorderAndFlagLines(CPQ_ApiDataModels.QuoteModel quoteModel) {
        // To fix the line numbers sequency coming after an amendment call
        Integer amendedLineNumber = 0;

        List<SBQQ__QuoteLine__c> qLines = new List<SBQQ__QuoteLine__c>();
        for (CPQ_ApiDataModels.QuoteLineModel lineItem : quoteModel.lineItems) {
            // Delete ALL lines
            SBQQ__QuoteLine__c qLine = lineItem.record;

            qLine.Amended__c = true;
            qLine.SBQQ__Number__c = ++amendedLineNumber;

            qLines.add(qLine);
        }
        update qLines;
    }

    private static void cancelLines(CPQ_ApiDataModels.QuoteModel quoteModel) {
        // To fix the line numbers sequency coming after an amendment call
        Integer amendedLineNumber = 0;

        List<SBQQ__QuoteLine__c> qLines = new List<SBQQ__QuoteLine__c>();
        for (CPQ_ApiDataModels.QuoteLineModel lineItem : quoteModel.lineItems) {
            SBQQ__QuoteLine__c qLine = lineItem.record;
            if (qLine.Amended__c) {
                qLine.SBQQ__Quantity__c = 0;

                qLines.add(qLine);
            }
        }
        update qLines;
    }

    public static Id calculateQuoteAsync(String quoteId, String callbackClass) {
        return System.enqueueJob(
            new CalculateQuoteBatchClass(quoteId, callbackClass)
        );
    }

    private static List<CPQ_ApiDataModels.QuoteLineModel> findChilds(CPQ_ApiDataModels.QuoteModel quoteModel, Integer lineUniqueKey) {
        List<CPQ_ApiDataModels.QuoteLineModel> childs = new List<CPQ_ApiDataModels.QuoteLineModel>();
        for (CPQ_ApiDataModels.QuoteLineModel lineItem: quoteModel.lineItems) {
            if (lineItem.parentItemKey == lineUniqueKey) {
                childs.add(lineItem);
            }
        }
        return childs;
    }

    private static CPQ_ApiDataModels.QuoteLineModel findLineItemModelInQuoteModel(CPQ_ApiDataModels.QuoteModel quoteModel, String quoteLineId) {
        for (CPQ_ApiDataModels.QuoteLineModel lineItem : quoteModel.lineItems) {
            if (lineItem.record.Id == quoteLineId) {
                return lineItem;
            }
        }
        return null;
    }

    /**
     * @description  Put a quantity of 0 for every original quote line. Then clone every line.
     */
    public static CPQ_ApiDataModels.QuoteModel modifyQuoteLines(CPQ_ApiDataModels.QuoteModel quoteModel) {
        System.debug('ATG: CR Lines (modifyQuoteLines): ' + quoteModel.lineItems.size());
        try {
            
            reorderAndFlagLines(quoteModel);

            generateQuoteLines_FlatMode(quoteModel);

            cancelLines(quoteModel);

            calculateQuoteAsync(quoteModel.record.Id, 'ContractAmenderCalculateCallback');
            
        } catch (Exception ex) {
            System.debug('Modify Quote Lines Error: ' + ex.getMessage() + 'line: ' + ex.getLineNumber());
            System.debug('Modify Quote Lines Trace: ' + ex.getStackTraceString());
            System.debug('Modify Quote Lines Cause: ' + ex.getCause());

            throw ex;
        }

        return quoteModel;
    }

    private static void generateQuoteLines_FlatMode(CPQ_ApiDataModels.QuoteModel quoteModel) {
        try {

            globalLineNumber = quoteModel.lineItems.size();
            Integer quoteLinesSize = quoteModel.lineItems.size();

            addProducts_FlatMode(quoteModel, quoteModel.lineItems, quoteLinesSize, null, 0);

            insertUpdateQuoteLines(quoteModel, quoteLinesSize);

        } catch (Exception ex) {
            System.debug('Generate Quote Lines Error: ' + ex.getMessage() + 'line: ' + ex.getLineNumber());
            System.debug('Generate Quote Lines Trace: ' + ex.getStackTraceString());
            System.debug('Generate Quote Lines Cause: ' + ex.getCause());

            throw ex;
        }
    }

    /**
     * Populates quoteLineWrapperMap field, to be used in next step to insert/update quote lines.
     */
    private static void addProducts_FlatMode(CPQ_ApiDataModels.QuoteModel quoteModel, List<CPQ_ApiDataModels.QuoteLineModel> quoteLinesModel, Integer originalAmendedQuoteLines, Integer parentQuoteLineNumber, Integer optionLevel) {
        if (quoteLinesModel.size() > 0) {
            System.debug('ATG: Adding level ' + quoteLinesModel[0].record.SBQQ__OptionLevel__c + ' for line ' + parentQuoteLineNumber);
        }

        Map<Integer, SBQQ__QuoteLine__c> orderedQuoteLines = new Map<Integer, SBQQ__QuoteLine__c>();

        // Bulkify mode..
        //List<SBQQ__QuoteLine__c> replacedLinesToInsert = new List<SBQQ__QuoteLine__c>();
        List<SBQQ__QuoteLine__c> canceledLinesToUpdate = new List<SBQQ__QuoteLine__c>();
        Map<Integer, List<CPQ_ApiDataModels.QuoteLineModel>> childsLinesToUpdateMap = new Map<Integer, List<CPQ_ApiDataModels.QuoteLineModel>>();

        Integer idx = 0;
    
        for (CPQ_ApiDataModels.QuoteLineModel quoteLineModel: quoteLinesModel) {

            SBQQ__QuoteLine__c qLine = quoteLineModel.record;

            if (parentQuoteLineNumber == null && String.isBlank(qLine.SBQQ__RequiredBy__c) ||
                parentQuoteLineNumber != null) {
                
                SBQQ__QuoteLine__c lineItem = new SBQQ__QuoteLine__c();
        
                lineItem.SBQQ__Quote__c = qLine.SBQQ__Quote__c;
				
				// Custom Field: SBQQ__QuoteLine__c.SBQQ__Source__c
                // SBQQ__Source is the OOB lookup that's populated when you clone a line
                lineItem.SBQQ__Source__c = qLine.Id;
        
                lineItem.SBQQ__Product__c = qLine.SBQQ__Product__c;
        
                List<CPQ_ApiDataModels.QuoteLineModel> childs = findChilds(quoteModel, quoteLineModel.key);
                if (childs.size() > 0) {
                    lineItem.SBQQ__Bundle__c = true;
        
                } else {
                    lineItem.SBQQ__Bundle__c = false;
                }
        
                // Set quantity for each quoteline
                lineItem.SBQQ__Quantity__c = qLine.SBQQ__Quantity__c;
        
                // Set price for each quoteline
                lineItem.SBQQ__ListPrice__c = qLine.SBQQ__ListPrice__c;
                
                // Set discount for each quoteline
                lineItem.SBQQ__TermDiscount__c = qLine.SBQQ__TermDiscount__c;
                
                if (parentQuoteLineNumber != null) {
                    lineItem.SBQQ__OptionType__c = qLine.SBQQ__OptionType__c;
        
                    lineItem.SBQQ__ProductOption__c = qLine.SBQQ__ProductOption__c;
                    lineItem.SBQQ__OptionLevel__c = qLine.SBQQ__OptionLevel__c;
                }
                
                lineItem.SBQQ__BundledQuantity__c = qLine.SBQQ__BundledQuantity__c;
        
                // MC-248
                /**
                 * Ensure that SBQQ End Date is blank on all Replace QLs
                 */
                lineItem.SBQQ__EndDate__c = null;
				
				// Custom Field: SBQQ__QuoteLine__c.Amended__c: To identify when a quote line is result of an amendment
                lineItem.Amended__c = false;
				
				// Add custom fields matching here
				//		Source: lineItem
				//		Target: qLine

        
                lineItem.SBQQ__Number__c = ++globalLineNumber;
                orderedQuoteLines.put(globalLineNumber, lineItem);
                
                // Custom field: SBQQ__QuoteLine__c.Replace_Quoteline__c
				// Populate Replace_Quoteline__c on all the Cancel Lines with a lookup to the Replace Line
                SBQQ__QuoteLine__c originalLineItem = findLineItemModelInQuoteModel(quoteModel, qLine.Id)?.record;
                
                childsLinesToUpdateMap.put(idx++, childs);

                //replacedLinesToInsert.add(lineItem);
                canceledLinesToUpdate.add(originalLineItem);
				
                System.debug('ATG: adding product ' + qLine.SBQQ__Product__c + ' [' + String.valueOf(qLine.SBQQ__Number__c) + '] in number[' + lineItem.SBQQ__Number__c + ']');
            }
        }

        // Reordering
        /*if (replacedLinesToInsert.size() > 0) {
            for (Integer i = 0; i < replacedLinesToInsert.size(); i++) {
                SBQQ__QuoteLine__c replaced = replacedLinesToInsert[i];
                CPQ_ApiDataModels.QuoteLineModel source = findLineItemModelInQuoteModel(quoteModel, replacedLinesToInsert[i].SBQQ__Source__c);
                replaced.SBQQ__Number__c = source.record.SBQQ__Number__c + originalAmendedQuoteLines;
            }
        }*/

        // Populates quoteLineWrapperMap for this option level 
        /*List<QuoteLineWrapper> wrappers = quoteLineWrapperMap.get(optionLevel);
        if (wrappers == null) {
            wrappers = new List<QuoteLineWrapper>();
        }
        for (SBQQ__QuoteLine__c replaced : replacedLinesToInsert) {
            wrappers.add(new QuoteLineWrapper(replaced, parentQuoteLineNumber));
        }
        quoteLineWrapperMap.put(optionLevel, wrappers);

        // Process next option level
        for (Integer j : childsLinesToUpdateMap.keySet()) {
            List<CPQ_ApiDataModels.QuoteLineModel> childQuoteLines = childsLinesToUpdateMap.get(j);
            addProducts_FlatMode(quoteModel, childQuoteLines, originalAmendedQuoteLines, (Integer) replacedLinesToInsert[j].SBQQ__Number__c, optionLevel+1);
        }*/
    }

    /**
     * Uses quoteLineWrapperMap created in previous step to insert/update quote lines in batch for each option level
     */
    private static void insertUpdateQuoteLines(CPQ_ApiDataModels.QuoteModel quoteModel, Integer quoteLinesSize) {
        // Map Quote Line Number/Quote Line Id
        Map<Integer, String> quoteLinesNumbersMap = new Map<Integer, String>();

        // Loop through every option level
        for (Integer optionLevel : quoteLineWrapperMap.keySet()) {
            List<QuoteLineWrapper> quoteLineWrappers = quoteLineWrapperMap.get(optionLevel);
            List<SBQQ__QuoteLine__c> quoteLinesToInsert = new List<SBQQ__QuoteLine__c>();
            for (QuoteLineWrapper quoteLineWrapper : quoteLineWrappers) {

                SBQQ__QuoteLine__c qLine = quoteLineWrapper.quoteLine;
                
                System.debug('ATG: Wrapper [' + optionLevel + '] ' + qLine.SBQQ__Number__c);
                
                // If this is the top level, just insert
                if (quoteLineWrapper.parentQuoteLineNumber == null) {
                    quoteLinesToInsert.add(qLine);
                
                // If this is an inner level, loook for the parent in the Quote Line Number/Quote Line Id map
                //      and set the parent Id to the quote line, then insert
                } else {
                    // search for parent added in previous level to the Quote Line Number/Quote Line Id map
                    String parentQuoteLineId = quoteLinesNumbersMap.get(quoteLineWrapper.parentQuoteLineNumber);
                    if (parentQuoteLineId != null) {
                        qLine.SBQQ__RequiredBy__c = parentQuoteLineId;
                        quoteLinesToInsert.add(qLine);
                    }
                }
            }

            // Insert in batch mode per option level
            if (quoteLinesToInsert.size() > 0) {
                insert quoteLinesToInsert;
            }

            // Add to the Quote Line Number/Quote Line Id map all the quotes after inserted, to be used in next loop (option level)
            for (SBQQ__QuoteLine__c quoteLine : quoteLinesToInsert) {
                quoteLinesNumbersMap.put((Integer) quoteLine.SBQQ__Number__c, quoteLine.Id);
            }
        }

        // After all quote lines were inserted, update Replace_Quoteline__c lookup field on each amended quote line.
        //      parent quote line number = quote line number + amended quote lines size
        //      Then, get parent quote Line Id from Quote Line Number/Quote Line Id map
        List<SBQQ__QuoteLine__c> qLines = new List<SBQQ__QuoteLine__c>();
        for (CPQ_ApiDataModels.QuoteLineModel lineItem : quoteModel.lineItems) {
            SBQQ__QuoteLine__c qLine = lineItem.record;
            if (qLine.Amended__c) {
                String parentQuoteLineId = quoteLinesNumbersMap.get((Integer) qLine.SBQQ__Number__c + quoteLinesSize);
                if (parentQuoteLineId != null) {
                    qLine.Replace_Quoteline__c = parentQuoteLineId;

                    qLines.add(qLine);
                }
            }
        }
        update qLines;
    }
}