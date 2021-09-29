public with sharing class CPQ_ApiHelper {


    public static Boolean debug = true;

    /** CPQ API METHODS */
    public static final String CONTRACT_RENEWER = 'SBQQ.ContractManipulationAPI.ContractRenewer';
    public static final String CONTRACT_AMENDER = 'SBQQ.ContractManipulationAPI.ContractAmender';

    public static final String CONFIG_LOADER = 'SBQQ.ConfigAPI.ConfigLoader';
    public static final String LOAD_RULE_EXECUTOR = 'SBQQ.ConfigAPI.LoadRuleExecutor';
    public static final String CONFIGURATION_VALIDATOR = 'SBQQ.ConfigAPI.ConfigurationValidator';

    public static final String PRODUCT_LOADER = 'SBQQ.ProductAPI.ProductLoader';
    public static final String PRODUCT_SUGGESTER = 'SBQQ.ProductAPI.ProductSuggester';
    public static final String PRODUCT_SEARCHER = 'SBQQ.ProductAPI.ProductSearcher';

    public static final String QUOTE_READER = 'SBQQ.QuoteAPI.QuoteReader';
    public static final String QUOTE_PRODUCT_ADDER = 'SBQQ.QuoteAPI.QuoteProductAdder';
    public static final String QUOTE_CALCULATOR = 'SBQQ.QuoteAPI.QuoteCalculator';
    public static final String QUOTE_SAVER = 'SBQQ.QuoteAPI.QuoteSaver';


    /** Mini Wrapper around SBQQ API METHODS */
    private static String read(String name, String uid) {
        return SBQQ.ServiceRouter.read(name, uid);
    }

    private static String load(String name, String uid, Object payload) {
        return loadStr(name, uid, JSON.serialize(payload));
    }

    private static String loadStr(String name, String uid, String payloadJson) {
        return SBQQ.ServiceRouter.load(name, uid, payloadJson);
    }

    private static String save(String name, Object model) {
        return saveStr(name, JSON.serialize(model));
    }

    private static String saveStr(String name, String modelJson) {
        return SBQQ.ServiceRouter.save(name, modelJson);
    }

    /**
     * ******* QUOTE API EXAMPLES ********
     */
    public static CPQ_ApiDataModels.QuoteModel getQuoteModel(Id quoteId) {
        String jsonResult = read(QUOTE_READER, (String) quoteId);
        CPQ_ApiDataModels.QuoteModel quoteModel = (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(jsonResult, CPQ_ApiDataModels.QuoteModel.class);
        if(debug) {
            System.debug(LoggingLevel.WARN, 'jsonResult: ' + jsonResult);
            System.debug(LoggingLevel.WARN, 'quoteModel: ' + quoteModel);
        }
        return quoteModel;
    }

    public static CPQ_ApiDataModels.ProductModel loadProduct(Id productId, Id pricebookId, String currencyCode) {
        CPQ_ApiDataModels.ProductLoadContext productLoadPayload = new CPQ_ApiDataModels.ProductLoadContext(pricebookId, currencyCode);
        String jsonResultProduct = load(PRODUCT_LOADER, (String) productId, productLoadPayload);
        CPQ_ApiDataModels.ProductModel productModel = (CPQ_ApiDataModels.ProductModel) JSON.deserialize(jsonResultProduct, CPQ_ApiDataModels.ProductModel.class);
        if(debug) {
            System.debug(LoggingLevel.WARN, 'jsonResultProduct: ' + jsonResultProduct);
            System.debug(LoggingLevel.WARN, 'productModel: ' + productModel);
        }
        return productModel;
    }

    public static CPQ_ApiDataModels.QuoteModel addProductsToQuote(Id quoteId, Id productId, Id pricebookId, String currencyCode) {
        return addProductsToQuote(quoteId, pricebookId, productId, currencyCode, false);
    }
    public static CPQ_ApiDataModels.QuoteModel addProductsToQuote(Id quoteId, Id productId, Id pricebookId, String currencyCode, Boolean skipCalculate) {
        CPQ_ApiDataModels.ProductModel productModel = loadProduct(productId, pricebookId, currencyCode);

        String jsonResultQuote = read(QUOTE_READER, (String) quoteId);
        CPQ_ApiDataModels.QuoteModel initialQuoteModel = (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(jsonResultQuote, CPQ_ApiDataModels.QuoteModel.class);
        if(debug) {
            System.debug(LoggingLevel.WARN, 'jsonResultQuote: ' + jsonResultQuote);
            System.debug(LoggingLevel.WARN, 'initialQuoteModel: ' + initialQuoteModel);
        }

        CPQ_ApiDataModels.ProductAddContext productAddPayload = new CPQ_ApiDataModels.ProductAddContext(skipCalculate, initialQuoteModel, new List<CPQ_ApiDataModels.ProductModel>{productModel});

        return addProductsToQuote(productAddPayload);

    }

    public static CPQ_ApiDataModels.QuoteModel addProductsToQuote(CPQ_ApiDataModels.ProductAddContext productAddPayload) {
        if(debug) {
            System.debug(LoggingLevel.WARN, 'productAddPayloadJSON: ' + JSON.serialize(productAddPayload));
        }
        String updatedQuoteJSON = load(QUOTE_PRODUCT_ADDER, null, productAddPayload);
        CPQ_ApiDataModels.QuoteModel updatedQuoteModel = (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(updatedQuoteJSON, CPQ_ApiDataModels.QuoteModel.class);
        if(debug) {
            System.debug(LoggingLevel.WARN, 'updatedQuoteJSON: ' + updatedQuoteJSON);
            System.debug(LoggingLevel.WARN, 'updatedQuoteModel: ' + updatedQuoteModel);
        }

        return updatedQuoteModel;
    }

  /*******************************************************************************************************
   * @description Add products to a quote
   * @param quote the quote where the products are aded
   * @param products the products to add
   * @param groupKey
   * @return  the quote with the products added
   */
    public static CPQ_ApiDataModels.QuoteModel addProductsToQuote(CPQ_ApiDataModels.QuoteModel quote, CPQ_ApiDataModels.ProductModel[] products, Integer groupKey) {
        CPQ_ApiDataModels.ProductAddContext ctx = new CPQ_ApiDataModels.ProductAddContext(true, quote, products, groupKey);
        String quoteJSON = SBQQ.ServiceRouter.load(QUOTE_PRODUCT_ADDER, null, JSON.serialize(ctx));
        return (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(quoteJSON, CPQ_ApiDataModels.QuoteModel.class);
    }

    public static CPQ_ApiDataModels.QuoteModel addProductsToQuote(CPQ_ApiDataModels.QuoteModel quote, CPQ_ApiDataModels.ProductModel[] products, Integer groupKey, Boolean skipCalculate) {
        CPQ_ApiDataModels.ProductAddContext ctx = new CPQ_ApiDataModels.ProductAddContext(skipCalculate, quote, products, groupKey);
        String quoteJSON = SBQQ.ServiceRouter.load(QUOTE_PRODUCT_ADDER, null, JSON.serialize(ctx));
        return (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(quoteJSON, CPQ_ApiDataModels.QuoteModel.class);
    }

    public static CPQ_ApiDataModels.QuoteModel saveQuote(CPQ_ApiDataModels.QuoteModel quoteModel) {
        String savedQuoteJSON = save(QUOTE_SAVER, quoteModel);

        CPQ_ApiDataModels.QuoteModel updatedQuoteModel = (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(savedQuoteJSON, CPQ_ApiDataModels.QuoteModel.class);
        if (debug) {
            System.debug(LoggingLevel.WARN, 'updatedQuoteModel: ' + updatedQuoteModel);
        }

        return updatedQuoteModel;
    }

    public static CPQ_ApiDataModels.QuoteModel amend(String contractId) {
        String quoteJSON = SBQQ.ServiceRouter.load(CONTRACT_AMENDER, contractId, null);
        return (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(quoteJSON, CPQ_ApiDataModels.QuoteModel.class);
    }

    public static CPQ_ApiDataModels.QuoteModel calculateQuote(CPQ_ApiDataModels.QuoteModel quoteModel, String callbackClass) {
        CPQ_ApiDataModels.CalculatorContext calculatorPayload = null;
        if (callbackClass != null) {
            calculatorPayload = new CPQ_ApiDataModels.CalculatorContext(quoteModel, callbackClass);
        } else {
            calculatorPayload = new CPQ_ApiDataModels.CalculatorContext(quoteModel);
        }

        String updatedQuoteJSON = load(QUOTE_CALCULATOR, null, calculatorPayload);

        CPQ_ApiDataModels.QuoteModel updatedQuoteModel = (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(updatedQuoteJSON, CPQ_ApiDataModels.QuoteModel.class);
        if (debug) {
            System.debug(LoggingLevel.WARN, 'updatedQuoteJSON: ' + updatedQuoteJSON);
            System.debug(LoggingLevel.WARN, 'updatedQuoteModel: ' + updatedQuoteModel);
        }

        return updatedQuoteModel;
    }

    /**
     * Force a re-calculation of provided quote
     * @param  quoteId [description]
     * @param  callbackClass [description]
     * @return         [description]
     */
    public static CPQ_ApiDataModels.QuoteModel calculateQuote(String quoteId, String callbackClass) {
        CPQ_ApiDataModels.QuoteModel initialQuoteModel = getQuoteModel(quoteId);
        if (debug) {
            System.debug(LoggingLevel.WARN, 'initialQuoteModel: ' + initialQuoteModel);
        }

        CPQ_ApiDataModels.QuoteModel calculatedQuoteModel = calculateQuote(initialQuoteModel, callbackClass);
        if (debug) {
            System.debug(LoggingLevel.WARN, 'calculatedQuoteModel: ' + calculatedQuoteModel);
        }

        CPQ_ApiDataModels.QuoteModel savedQuoteModel = saveQuote(calculatedQuoteModel);
        if (debug) {
            System.debug(LoggingLevel.WARN, 'savedQuoteModel: ' + savedQuoteModel);
        }

        return savedQuoteModel;
    }
}