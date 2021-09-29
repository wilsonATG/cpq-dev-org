global class CalculateQuoteBatchClass implements Queueable {

    global final String quoteId;
    global final String callbackClass;

    public CalculateQuoteBatchClass(String quoteId, String callbackClass) {
        this.quoteId = quoteId;
        this.callbackClass = callbackClass;
    }

    public void execute(QueueableContext context) {
        System.debug('ATG CPQ: SendEmailBatchClass.execute()');
        CalculateQuoteBatchClass.calculateQuote(this.quoteId, this.callbackClass);
    }

    /**
     * This method sends mail by taking subject,body,emailaddresses as arguments
     */ 
    public static void calculateQuote(String quoteId, String callbackClass) {
        CPQ_ApiDataModels.QuoteModel quoteModel = CPQ_ApiHelper.getQuoteModel(quoteId);
        quoteModel = CPQ_ApiHelper.calculateQuote(quoteModel, callbackClass);
    }
}
