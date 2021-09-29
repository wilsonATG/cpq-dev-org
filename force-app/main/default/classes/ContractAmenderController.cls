public class ContractAmenderController {

    public Id contractId { get; set; }
    public Id quoteId { get; set; }
    public Boolean finished { get; private set; }
    
    public ContractAmenderController() {
        this.contractId = (Id) ApexPages.currentPage().getParameters().get('id');
        System.debug('ATG: contractId is ' + this.contractId);

        //ApexPages.getMessages().clear();
        finished = false;
    }

    public PageReference callContractAmendment() {
        CPQ_ApiDataModels.QuoteModel qModel = null;
        try {
            qModel = ContractAmender.makeAmend(this.contractId);
            if (qModel == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Errors during make amend process.'));

                finished = true;
            
                return null;
            }
        } catch(Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Errors during make amend process.'));
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,  + ex.getMessage()));

            finished = true;
            
            return null;
        }

        try {
            qModel = ContractAmender.modifyQuoteLines(qModel);
            if (qModel == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Errors on updating amended quote.'));

                finished = true;
            
                return null;
            }
        } catch(Exception ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Errors on updating amended quote.'));
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,  + ex.getMessage()));

            finished = true;
            
            return null;
        }

        if (String.isEmpty(qModel.record.Id)) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Errors on creating the quote.'));

            finished = true;
        
            return null;
        }
        this.quoteId = qModel.record.Id;
        System.debug('ATG: amended quote Id is ' + this.quoteId);
        
        finished = true;

        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Cancel & Replace successful'));

        //return redirectToQuoteLineEditor();
        return null;
    }

    public PageReference refreshContractAmendment() {

        this.quoteId = null;
        ApexPages.getMessages().clear();
        finished = false;

        return callContractAmendment();
    }

    public PageReference redirectToQuoteLineEditor() {
        String url = '/apex/sbqq__sb?id={0}#quote/le?qId={0}';
        url = String.format(url, new List<String>{ this.quoteId });
        System.debug(LoggingLevel.WARN, 'redirect url: ' + url);

        PageReference pg = new PageReference(url);
        pg.setRedirect(true);
        
        return pg;
    }

    public PageReference backToContract() {
        String url = '/{0}';
        url = String.format(url, new List<String>{ this.contractId });
        System.debug(LoggingLevel.WARN, 'redirect url: ' + url);

        PageReference pg = new PageReference(url);
        pg.setRedirect(true);
        
        return pg;
    }
}
