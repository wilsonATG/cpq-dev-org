global with sharing class ContractAmenderCalculateCallback implements SBQQ.CalculateCallback {
    public void callback(String quoteJSON) {
        CPQ_ApiDataModels.QuoteModel quoteModel = (CPQ_ApiDataModels.QuoteModel) JSON.deserialize(quoteJSON, CPQ_ApiDataModels.QuoteModel.class);
        CPQ_ApiHelper.saveQuote(quoteModel);
    }
}
