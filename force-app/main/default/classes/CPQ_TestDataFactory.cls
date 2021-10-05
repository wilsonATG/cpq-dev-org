/**
* File Name     :  CPQ_TestDataFactory
* @description  :  Utils class to create any types of data used in all test classes for the CPQ build
* @author       :  Cory Bartholomew @ ATG and  Cesar Sandrigo @ ATG - Advanced Technology Group  
* Modification Log
**/

@IsTest
public with sharing class CPQ_TestDataFactory {
  public static Map<String, RecordType> recordTypeMap = new Map<String, RecordType>();

  public static void activateOrder(Order order) {
    order.status = 'Activated';
    order.SBQQ__PriceCalcStatus__c = 'Not Needed';
    update order;
  }

  public static void contractOrder(Order order) {
    order.SBQQ__Contracted__c = true;
    update order;
  }

  
  public static Account createAccount(Boolean doInsert) {
    Account account = new Account();
    account.Name = 'Test';
    account.BillingPostalCode = '10013'; // '00000';
    account.BillingCity = 'New York'; // 'testCity';
    account.BillingState = 'New York'; // 'testState';
    account.BillingStreet = '434 Broadway floor 2'; // 'testStreet';
    account.BillingCountry = 'United States';
    /*account.BillingCountryCode = 'US';*/
    account.ShippingPostalCode = '10013'; // '00000';
    account.ShippingCity = 'New York'; // 'testCity';
    account.ShippingState = 'New York'; // 'testState';
    account.ShippingStreet = '434 Broadway floor 2'; // 'testStreet';
    account.ShippingCountry = 'United States';
    /*account.ShippingCountryCode = 'US';*/
    if (doInsert) {
      insert account;
    }
    return account;
  }

  public static Lead createLead(Boolean doInsert) {
    Lead lead = new Lead();
    lead.IsConverted = false;
    lead.FirstName = 'US';
    lead.LastName = 'QATEST';
    lead.State = 'mt';
    lead.Status = 'Open';
    if (doInsert) {
      insert lead;
    }
    return lead;
  }

  public static Lead createLead(
    String firstName,
    String lastName,
    String street,
    String city,
    String state,
    String postalCode,
    String country,
    String companyName,
    Boolean doInsert
  ) {
    Lead lead = new Lead();
    lead.IsConverted = false;
    lead.FirstName = firstName;
    lead.LastName = lastName;
    lead.Street = street;
    lead.City = city;
    lead.State = state;
    lead.PostalCode = postalCode;
    lead.Country = country;
    lead.Company = companyName;
    lead.Status = 'Open';
    if (doInsert) {
      insert lead;
    }
    return lead;
  }

  public static Contact createContact(Boolean doInsert) {
    //contact
    Contact testContact = new Contact();
    testContact.FirstName = 'Test Last Name1';
    testContact.LastName = 'Test Last Name';
    if (doInsert) {
      insert testContact;
    }
    return testContact;
  }

  
  public static Opportunity createOppty(Account account, Boolean doInsert) {
    //Oppty
    Opportunity opportunity = new Opportunity();
    opportunity.Name = 'AA Test';
    opportunity.AccountId = account.Id;
    opportunity.CloseDate = Date.Today();
    /*opportunity.CurrencyIsoCode = 'USD';*/
    opportunity.Pricebook2Id = Test.getStandardPricebookId();
    opportunity.Probability = 10;
    opportunity.TotalOpportunityQuantity = 0;
    opportunity.StageName = 'Qualified';
    if (doInsert) {
      insert opportunity;
    }
    return opportunity;
  }

  // FIXME: do not use this method anymore, use the one with the address instead. Remove this method when it has no more references
  public static SBQQ__Quote__c createQuote(Opportunity oppty, Account account, Contact contact, Boolean doInsert) {
    SBQQ__Quote__c quote = new SBQQ__Quote__c();
    quote.SBQQ__Primary__c = true;
    quote.SBQQ__Type__c = 'Quote';
    quote.SBQQ__Status__c = 'Draft';
    quote.SBQQ__Account__c = account.Id;
    quote.SBQQ__ExpirationDate__c = oppty.CloseDate;
    quote.SBQQ__BillingCity__c = 'Aurora';
    quote.SBQQ__BillingCountry__c = 'US';
    quote.SBQQ__BillingName__c = 'H & R BLOCK CENTRAL DENVER';
    quote.SBQQ__BillingPostalCode__c = '80014';
    quote.SBQQ__BillingState__c = 'CO';
    quote.SBQQ__BillingStreet__c = '13693 E. Iliff Ave Ste 110';
    quote.SBQQ__Opportunity2__c = oppty.Id;
    quote.SBQQ__PriceBook__c = Test.getStandardPricebookId();
    quote.SBQQ__PricebookId__c = Test.getStandardPricebookId();
    quote.SBQQ__PrimaryContact__c = contact.Id;
    quote.SBQQ__ShippingCity__c = 'Aurora';
    quote.SBQQ__ShippingCountry__c = 'US';
    quote.SBQQ__ShippingName__c = 'H & R BLOCK CENTRAL DENVER';
    quote.SBQQ__ShippingPostalCode__c = '80014';
    quote.SBQQ__ShippingState__c = 'CO';
    quote.SBQQ__ShippingStreet__c = '13693 E. Iliff Ave Ste 110';
    quote.SBQQ__StartDate__c = Date.today();
    quote.SBQQ__SubscriptionTerm__c = 12;
    if (doInsert) {
      insert quote;
    }
    return quote;
  }

  public static Product2 createProduct(Boolean doInsert) {
      return createProduct('Digital Package', doInsert);
  }

  public static Product2 createProduct(String name, Boolean doInsert) {
    Product2 product = new Product2();
    product.Name = name;
    product.Description = 'Digital Package';
    product.Family = 'Test Product Digital';
    product.IsActive = true;
    product.ProductCode = String.valueOf(Integer.valueof(Math.random() * 1000000000));
    product.SBQQ__AssetAmendmentBehavior__c = 'Default';
    product.SBQQ__AssetConversion__c = 'One per quote line';
    product.SBQQ__BillingFrequency__c = 'Monthly';
    product.SBQQ__BillingType__c = 'Advance';
    product.SBQQ__BlockPricingField__c = 'Quantity';
    product.SBQQ__ChargeType__c = 'Recurring';
    product.SBQQ__ConfigurationEvent__c = 'Always';
    product.SBQQ__ConfigurationType__c = 'Allowed';
    product.SBQQ__DefaultQuantity__c = 1;
    product.SBQQ__HasConfigurationAttributes__c = true;
    product.SBQQ__OptionLayout__c = 'Sections';
    product.SBQQ__PriceEditable__c = true;
    product.SBQQ__PricingMethod__c = 'List';
    product.SBQQ__QuantityEditable__c = true;
    product.SBQQ__QuantityScale__c = 0;
    product.SBQQ__SubscriptionBase__c = 'List';
    product.SBQQ__SubscriptionPricing__c = 'Fixed Price';
    product.SBQQ__SubscriptionTerm__c = 1;
    product.SBQQ__SubscriptionType__c = 'Renewable';
    //product.Product_External_ID__c = ApexUtils.randomString(30);
    /*
    product.Infrastructure__c = 'Public Cloud';
    product.Revenue_Category__c = 'SERV';
    product.CPQ_Output_Name__c = 'TSDV';
    product.CPQ_Charge_Category__c = 'Managed Services';
    product.CPQ_Discount_Category__c = 'Managed Services';
    product.CPQ_Pricing_Source__c = 'SalesConnect';
    product.CPQ_Pricing_Driver__c = 'Bundle';*/

    if (doInsert) {
      insert product;
    }
    return product;
  }

  public static Pricebook2 createPricebook(String name, Boolean doInsert) {
    //pricebook entry
    Pricebook2 pb = new Pricebook2();
    pb.Name = name;
    pb.IsActive = true;

    if (doInsert) {
      insert pb;
    }
    return pb;
  }

  public static List<PricebookEntry> createPriceBookEntries(List<Product2> products, Boolean doInsert) {
    List<PricebookEntry> priceBookEntries = new List<PricebookEntry>();

    for (Product2 prod : products) {
      priceBookEntries.add(createPriceBookEntry(prod, false));
    }

    if (doInsert) {
      insert priceBookEntries;
    }
    return priceBookEntries;
  }

  public static PricebookEntry createPriceBookEntry(Product2 product, Boolean doInsert) {
    return createPriceBookEntry(product, new Pricebook2(Id = Test.getStandardPricebookId()), 'USD', doInsert);
  }

  public static PricebookEntry createPriceBookEntry(Product2 product, String currencyCode, Boolean doInsert) {
    return createPriceBookEntry(product, new Pricebook2(Id = Test.getStandardPricebookId()), currencyCode, doInsert);
  }

  public static PricebookEntry createPriceBookEntry(Product2 product, Pricebook2 pricebook, String currencyCode, Boolean doInsert) {
    //pricebook entry
    PricebookEntry testPbEntry = new PricebookEntry();
    testPbEntry.Pricebook2Id = pricebook.Id;
    testPbEntry.Product2Id = product.Id;
    testPbEntry.UnitPrice = 10;
    testPbEntry.IsActive = true;
    /*testPbEntry.CurrencyIsoCode = currencyCode;*/
    //testPbEntry.SAP_Price_Entry__c = priceEntry == null ? null : priceEntry.Id;
    if (doInsert) {
      insert testPbEntry;
    }
    return testPbEntry;
  }

  public static SBQQ__QuoteLine__c createQuoteLine(SBQQ__Quote__c quote, Product2 product, String pricebookEntryId, Integer quantity, Boolean doInsert) {
    SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c();
    quoteLine.SBQQ__BillingFrequency__c = product.SBQQ__BillingFrequency__c;
    quoteLine.SBQQ__BillingType__c = product.SBQQ__BillingType__c;
    quoteLine.SBQQ__Bundle__c = false;
    quoteLine.SBQQ__ChargeType__c = product.SBQQ__ChargeType__c;
    quoteLine.SBQQ__PricingMethod__c = product.SBQQ__PricingMethod__c;
    quoteLine.SBQQ__ComponentListTotal__c = 100;
    quoteLine.SBQQ__ComponentTotal__c = 100;
    quoteLine.SBQQ__CustomerPrice__c = 100;
    quoteLine.SBQQ__Description__c = product.Description;
    quoteLine.SBQQ__ListPrice__c = 100;
    quoteLine.SBQQ__NetPrice__c = 100;
    quoteLine.SBQQ__OriginalPrice__c = 100;
    quoteLine.SBQQ__PartnerPrice__c = 100;
    quoteLine.SBQQ__Product__c = product.Id;
    quoteLine.SBQQ__PricebookEntryId__c = pricebookEntryId;
    quoteLine.SBQQ__ProrateMultiplier__c = 1;
    quoteLine.SBQQ__ProratedListPrice__c = 100;
    quoteLine.SBQQ__ProratedPrice__c = 100;
    quoteLine.SBQQ__Quantity__c = quantity;
    quoteLine.SBQQ__Quote__c = quote.Id;
    quoteLine.SBQQ__RegularPrice__c = 100;
    quoteLine.SBQQ__SpecialPrice__c = 100;
    quoteLine.SBQQ__SubscriptionBase__c = product.SBQQ__SubscriptionBase__c;
    quoteLine.SBQQ__SubscriptionPricing__c = product.SBQQ__SubscriptionPricing__c;

    /*quoteLine.CPQ_Charge_Category__c = 'Managed Services';
    quoteLine.CPQ_Discount_Category__c = 'Managed Services';
    quoteLine.CPQ_Pricing_Source__c = 'SalesConnect';
    quoteLine.CPQ_Pricing_Driver__c = 'Bundle';
    quoteLine.CPQ_Output_Name__c = 'TSDV';*/
    
    if (doInsert) {
      insert quoteLine;
    }
    return quoteLine;
  }

  public static Order createOrder(Account account, Opportunity opp, SBQQ__Quote__c quote, Boolean doInsert) {
    Order order = new Order();
    order.AccountId = account.Id;
    order.BillingCity = 'New York';
    order.BillingCountry = 'United States';
    order.BillingPostalCode = '10013';
    order.BillingState = 'New York';
    order.BillingStreet = '434 Broadway floor 2';
    /*order.CurrencyIsoCode = 'USD';*/
    order.EffectiveDate = Date.today();
    order.EndDate = Date.today().addMonths(12);
    order.OpportunityId = opp.Id;
    order.Pricebook2Id = Test.getStandardPricebookId();
    order.SBQQ__ContractingMethod__c = 'By Subscription End Date';
    order.SBQQ__PaymentTerm__c = 'Net 30';
    order.SBQQ__PriceCalcStatus__c = 'Not Started';
    order.SBQQ__Quote__c = quote.Id;
    order.SBQQ__RenewalTerm__c = 1;
    order.ShippingCity = 'New York';
    order.ShippingCountry = 'United States';
    order.ShippingPostalCode = '10013';
    order.ShippingState = 'New York';
    order.ShippingStreet = '434 Broadway floor 2';
    order.Status = 'Draft';
    order.Type = 'New';
    if (doInsert) {
      insert order;
    }
    return order;
  }

  public static OrderItem createOrderItems(Order order, SBQQ__QuoteLine__c quoteLine, Boolean doInsert) {
    OrderItem oi = new OrderItem();
    oi.EndDate = Date.today().addMonths(12);
    oi.OrderId = order.Id;
    oi.PricebookEntryId = quoteLine.SBQQ__PricebookEntryId__c;
    oi.Quantity = 1;
    oi.SBQQ__Activated__c = true;
    oi.SBQQ__BillingFrequency__c = quoteLine.SBQQ__BillingFrequency__c;
    oi.SBQQ__BillingType__c = quoteLine.SBQQ__BillingType__c;
    oi.SBQQ__BookingsIndicator__c = 'Include';
    oi.SBQQ__ChargeType__c = quoteLine.SBQQ__ChargeType__c;
    oi.SBQQ__ContractAction__c = 'New';
    oi.SBQQ__ContractingMethod__c = 'Inherit';
    oi.SBQQ__DefaultSubscriptionTerm__c = 1;
    oi.SBQQ__OrderedQuantity__c = quoteLine.SBQQ__Quantity__c;
    oi.SBQQ__ProrateMultiplier__c = 1;
    oi.SBQQ__QuoteLine__c = quoteLine.Id;
    oi.SBQQ__QuotedListPrice__c = quoteLine.SBQQ__ListPrice__c;
    oi.SBQQ__QuotedQuantity__c = quoteLine.SBQQ__Quantity__c;
    oi.SBQQ__Status__c = 'Activated';
    oi.SBQQ__SubscriptionPricing__c = quoteLine.SBQQ__SubscriptionPricing__c;
    oi.SBQQ__SubscriptionTerm__c = quoteLine.SBQQ__SubscriptionTerm__c;
    oi.ServiceDate = Date.today();
    oi.UnitPrice = quoteLine.SBQQ__NetPrice__c;
    if (doInsert) {
      insert oi;
    }
    return oi;
  }

    public static Contract createContract(Account acct, Id pricebookId, Opportunity opp, Order order, SBQQ__Quote__c quote, Boolean doInsert) {
        Contract obj = (Contract)Contract.sObjectType.newSObject(
            null, // null will make it the default record type for the user
            true // loadDefaultValues
        );
        obj.AccountId = acct.Id;
        obj.ContractTerm = 12;
        obj.SBQQ__Quote__c = quote == null ? null : quote.Id;
        obj.SBQQ__Opportunity__c = opp == null ? null : opp.Id;
        obj.SBQQ__Order__c = order == null ? null : order.Id;
        obj.SBQQ__RenewalTerm__c = 12;
        obj.StartDate = System.Today();

        if (doInsert) {
            insert obj;
        }
        return obj;
    }

  /** UTILITY METHODS **/

  public static id getRecordType(string developer_name) {
    if (recordTypeMap.size() == 0) {
      Map<id, RecordType> rtmap = new Map<id, RecordType>([SELECT Id, DeveloperName, sobjectType, isActive FROM RecordType]);
      for (Id idKey : rtmap.keyset()) {
        RecordType rt = rtmap.get(idKey);
        recordTypeMap.put(rt.DeveloperName, rt);
      }
      System.debug('All Record Types :' + recordTypeMap);
    }

    return recordTypeMap.get(developer_name).id;
  }

  public static Integer queryCount = 0;
  public static void printQueries(String message) {
    System.debug(
      Logginglevel.ERROR,
      message +
      ' used ' +
      (Limits.getQueries() - queryCount) +
      ' queries. The total queries used is ' +
      Limits.getQueries() +
      ' CPU TIME: ' +
      Limits.getCpuTime() +
      ' ' +
      Limits.getLimitCpuTime()
    );
    queryCount = Limits.getQueries();
  }

  /** Query sobject without subquery */
  public static List<sObject> queryRecordsFromIdsAndName(Set<Id> recordIds, String objectName, String whereClause) {
    Set<Id> idSet = recordIds;
    String soql = 'SELECT ' + getAllFieldsForSObjAsStr(objectName) + ' FROM ' + objectName + ' ' + whereClause;
    System.debug(soql);
    return Database.query(soql);
  }

  /** Query sobject with subquery */
  public static List<sObject> queryRecordsAndChildrenFromIdsAndNames(
    Set<Id> recordIds,
    String parentObjName,
    String childObjName,
    String childObjRelationshipName,
    String whereClause
  ) {
    Set<Id> idSet = recordIds;
    String soql =
      'SELECT ' +
      getAllFieldsForSObjAsStr(parentObjName) +
      ', (SELECT ' +
      getAllFieldsForSObjAsStr(childObjName) +
      ' FROM ' +
      childObjRelationshipName +
      ') FROM ' +
      parentObjName +
      ' ' +
      whereClause;
    System.debug(soql);
    return Database.query(soql);
  }

  /** Get all fields for an sobject as a list - helpful for dynamic SOQL */
  public static List<String> getAllFieldsForSobj(String sobjectName) {
    List<String> allFields = new List<String>(Schema.getGlobalDescribe().get(sobjectName).getDescribe().fields.getMap().keySet());
    return allFields;
  }

  /** Get comma delimited string list of all sobject fields */
  public static String getAllFieldsForSObjAsStr(String sobjectName) {
    return String.join(getAllFieldsForSobj(sobjectName), ', ');
  }

  public static User createUser(
    String firstName,
    String lastName,
    String email,
    String userName,
    String nickName,
    String alias,
    Id profileId,
    Id userRoleId,
    Boolean doInsert
  ) {
    User user = new User();
    user.FirstName = firstName;
    user.LastName = lastName;
    user.Email = email;
    user.Username = username;
    user.CommunityNickname = nickName;
    user.Alias = alias;
    user.UserRoleId = userRoleId;
    user.ProfileId = profileId;
    user.TimeZoneSidKey = 'America/Los_Angeles';
    user.LocaleSidKey = 'en_US';
    user.EmailEncodingKey = 'ISO-8859-1';
    user.LanguageLocaleKey = 'en_US';

    if (doInsert) {
      insert user;
    }
    return user;
  }

  public static UserRole createRole(String roleDeveloperName, Boolean doInsert) {
    UserRole r = new UserRole(DeveloperName = roleDeveloperName, Name = roleDeveloperName);

    if (doInsert) {
      insert r;
    }
    return r;
  }
}