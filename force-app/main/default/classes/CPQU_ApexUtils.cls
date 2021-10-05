/**
 * Utility class for common operations
 *
 * Any classes that use Schema.SObjectField, this property is object by calling "Schema.Account.Description"
 * This allows type safety to ensure that code will not break if fields are changed
 * this will not work with person accounts
 *
 */
public class CPQU_ApexUtils {

    public class NoParentRecordIncludedException extends Exception {}
    
    private static final String ID_STR = 'Id'; 
    private static Map<String, RecordType> recordTypeMap = new Map<String, RecordType>();
    public static String instanceURL = System.Url.getSalesforceBaseUrl().toExternalForm();
    public static String subDomainWithProtocol = (System.Url.getSalesforceBaseUrl().toExternalForm()).split('\\.')[0];
    public static final Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
    public static Map<String, Map<String, Schema.SObjectField>> mapObjNameToFieldMap = new Map<String, Map<String, Schema.SObjectField>>();

    public static Boolean runningInASandbox {
        get {
            if (runningInASandbox == null) {
                runningInASandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
            }
            return runningInASandbox;
        }
        set;
    }

    /**
     * @description Given an SObject name, return a Schema.SObjectField field map. Cache the map in the following instance variable: mapObjNameToFieldMap.
     * @param String sObjectName -> the name of the SObject in which to return a Schema.SObjectField field map for
     * @return Map<String, Schema.SObjectField> fMap -> the Schema.SObjectField field map to return
     */
    public static Map<String, Schema.SObjectField> getFieldMap(String sObjectName) {
        // Get a map of field name and field token
        Map<String, Schema.SObjectField> fMap = mapObjNameToFieldMap.get(sObjectName) == null 
            ? globalDescribe.get(sObjectName.toLowerCase()).getDescribe().fields.getMap() : mapObjNameToFieldMap.get(sObjectName);
        // cache the map at the object name key to save on performance if this method is called again with the same object name in the same exectution:
        mapObjNameToFieldMap.put(sObjectName, fMap);
    
        return fMap;
    }
    
    /**
     * Given a list and a string property (of an ID field), return a set of the extracted ids
     * (Example: Given a list of contacts where prop='AccountId', return a set of the account Id's)
     * @param  items [description]
     * @param  prop  [description]
     * @return       [description]
     */
    public static Set<Id> pluckIdSet(List<SObject> items, Schema.SObjectField prop) {
        Set<Id> ids = new Set<Id>();
        for(SObject obj : items) {
            try {
                if(obj.get(prop) != null) {
                    ids.add((Id)obj.get(prop));
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return ids;
    }

    /**
     * Given a list and a string property (of an ID field), return a set of the extracted ids
     * (Example: Given a list of contacts where prop='AccountId', return a set of the account Id's)
     * This method allows relationships - Ex. 'Account.CreatedBy.Id'
     * @param  items [description]
     * @param  prop  [description]
     * @return       [description]
     */
    public static Set<Id> pluckIdSet(List<SObject> items, String prop) {
        Set<Id> ids = new Set<Id>();
        for(SObject obj : items) {
            try {
                if(prop.contains('.')) {
                    SObject currObj = obj;
                    List<String> fields = prop.split('\\.');
                    for(String field : fields) {
                        try {
                            currObj = (SObject)currObj.getSObject(field);
                        } catch (Exception ex) {
                            ids.add((Id)currObj.get(field));
                        }
                    }
                } else if (obj.get(prop) != null) {
                    ids.add((Id)obj.get(prop));
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return ids;
    }

    /**
     * Given a list and a string property (of a String field), return a set of the extracted values
     * (Example: Given a list of contacts where prop='FirstName', return a set of the contacts first name)
     * @param  items [description]
     * @param  prop  [description]
     * @return       [description]
     */
    public static Set<String> pluckStringSet(List<SObject> items, Schema.SObjectField prop) {
        Set<String> strings = new Set<String>();
        for(SObject obj : items) {
            try {
                if(obj.get(prop) != null) {
                    strings.add((String)obj.get(prop));
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return strings;
    }

    /**
     * Given a list and a string property (of a String field), return a set of the extracted values
     * The string version provides the ability to get relationship fields - e.x. 'Account.CreatedBy.Name'
     * @param  items [description]
     * @param  prop  [description]
     * @return       [description]
     */
    public static Set<String> pluckStringSet(List<SObject> items, String prop) {
        Set<String> strings = new Set<String>();
        for(SObject obj : items) {
            try {
                if(prop.contains('.')) {
                    SObject currObj = obj;
                    List<String> fields = prop.split('\\.');
                    for(String field : fields) {
                        try {
                            currObj = (SObject)currObj.getSObject(field);
                        } catch (Exception ex) {
                            strings.add((String)currObj.get(field));
                        }
                    }
                } else if (obj.get(prop) != null) {
                    strings.add((String)obj.get(prop));
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return strings;
    }

    /**
     * Build a map from two proprties on a list of objects
     * Example: Given a list of Opportunites, passing in prop1='Id', prop2='AccountId', get a map back with the opp id to the account id
     * If two records have the same value for key, then record later in the list will overwrite prior value
     * @param  items list of SObject
     * @param  key Property to get a map by
     * @param  value [description]
     * @return       [description]
     */
    public static Map<String, String> pluckMap(List<SObject> items, Schema.SObjectField key, Schema.SObjectField value) {
        Map<String, String> outputMap = new Map<String, String>();
        for(SObject obj : items) {
            try {
                if(obj.get(key) != null && obj.get(value) != null) {
                    outputMap.put((String)obj.get(key), (String)obj.get(value));
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return outputMap;
    }

    /**
     * Same logic as pluckMap, but value is of type Object and will need to be casted to proper type
     * @param  items list of SObject
     * @param  key Property to get a map by
     * @param  value [description]
     * @return       [description]
     */
    public static Map<String, Object> pluckMapAny(List<SObject> items, Schema.SObjectField key, Schema.SObjectField value) {
        Map<String, Object> propToPropMap = new Map<String, Object>();
        for(SObject obj : items) {
            try {
                if(obj.get(key) != null && obj.get(value) != null) {
                    propToPropMap.put((String)obj.get(key), obj.get(value));
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getMessage() + ex.getStackTraceString());
            }
        }
        return propToPropMap;
    }

    /**
     * Group a list of SObjects by any field on the SObject.
     * @param  items list of SObject
     * @param  field Property to get a map by
     * @return       [description]
     */
    public static Map<String, List<SObject>> groupBy(List<SObject> items, Schema.SObjectField field) {
        Map<String, List<SObject>> propToPropMap = new Map<String, List<SObject>>();
        for(SObject obj : items) {
            try {
                if(obj.get(field) != null) {
                    if(!propToPropMap.containsKey((String)obj.get(field))) {
                        propToPropMap.put((String)obj.get(field), new List<SObject>());
                    }
                    propToPropMap.get((String)obj.get(field)).add(obj);

                } else {
                    System.debug(field + ' is null, ignoring record: ' + obj);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getMessage() + ex.getStackTraceString());
            }
        }
        return propToPropMap;
    }

    /**
     * Group a list of SObjects by any field on the SObject.
     * This version of the method supports passing in a string key with relationship fields
     * For example, if you want to group Contacts by Contact.Account.Name
     * @param  items list of SObject
     * @param  field Property to get a map by
     * @return       [description]
     */
    public static Map<String, List<SObject>> groupBy(List<SObject> items, String field) {
      Map<String, List<SObject>> propToPropMap = new Map<String, List<SObject>>();
      for(SObject obj : items) {
          try {
              SObject baseObj = obj;
              SObject tempObj = obj; // if field has a "." this holds the nested objects until fields is reached
              String currField = field;
              // If provided field is using dot notation, get nested object and field
              if(field.contains('.')) {
                  List<String> fields = field.split('\\.');
                  for(String splitField : fields) {
                      try {
                          tempObj = (SObject)tempObj.getSObject(splitField);
                      } catch (Exception ex) {
                          currField = splitField;
                      }
                  }
              }

              if(tempObj.get(currField) != null) {
                  if(!propToPropMap.containsKey((String)tempObj.get(currField))) {
                      propToPropMap.put((String)tempObj.get(currField), new List<SObject>());
                  }
                  propToPropMap.get((String)tempObj.get(currField)).add(baseObj);

              } else {
                  System.debug(currField + ' is null, ignoring record: ' + baseObj);
              }
          } catch (Exception ex) {
              System.debug('Error processing record, ignoring ' + ex.getMessage() + ex.getStackTraceString());
          }
      }
      return propToPropMap;
    }

    /**
     * Sames as groupBy, but only returns one record per key
     * if two records have the same key, the record later in the list will overwrite the previous record
     * @param  items list of records
     * @param  key  field key
     * @return       [description]
     */
    public static Map<String, SObject> groupByFlat(List<SObject> items, Schema.SObjectField key) {
        Map<String, SObject> propToSObjMap = new Map<String, SObject>();
        for(SObject obj : items) {
            try {
                if(obj.get(key) != null) {
                    propToSObjMap.put((String)obj.get(key), obj);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getMessage() + ex.getStackTraceString());
            }
        }
        return propToSObjMap;
    }

    /**
     * Sames as groupBy, but only returns one record per key
     * if two records have the same key, the record later in the list will overwrite the previous record
     * SPECIFICALLY DESIGNED FOR THE CPQ UTILITY SETTING METADATA
     * @param  items list of records
     * @return       [description]
     */ 
    public static Map<String, CPQU_UtilitySetting__mdt> groupSettingsByDeveloperName(List<CPQU_UtilitySetting__mdt> items) {
        Schema.SObjectField key = Schema.CPQU_UtilitySetting__mdt.DeveloperName;

        Map<String, CPQU_UtilitySetting__mdt> propToSObjMap = new Map<String, CPQU_UtilitySetting__mdt>();
        for(CPQU_UtilitySetting__mdt obj : items) {
            try {
                if(obj.get(key) != null) {
                    propToSObjMap.put((String)obj.get(key), obj);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getMessage() + ex.getStackTraceString());
            }
        }
        return propToSObjMap;
    }

    /**
     * Get a list of records where the specified value changed
     * @param  items       trigger.new
     * @param  oldItemsMap trigger.oldMap
     * @param  fields      string | string[], name(s) of property to check
     * @return             
     */
    public static List<SObject> findChangedRecs(List<SObject> items, Map<Id, SObject> oldItemsMap, Schema.SObjectField field) {
        return findChangedRecs(items, oldItemsMap, new List<Schema.SObjectField>{field});
    }
    public static List<SObject> findChangedRecs(List<SObject> items, Map<Id, SObject> oldItemsMap, List<Schema.SObjectField> fields) {
        List<SObject> changedObjects = new List<SObject>();
        for(SObject obj : items) {
            for(Schema.SObjectField field : fields) {
                try {
                    Object newObjValue = obj.get(field);
                    Object oldObjValue = oldItemsMap.get((Id)obj.get(ID_STR)).get(field);
                    if(newObjValue != oldObjValue) {
                        changedObjects.add(obj);
                        break; // do not need to continue checking for this record
                    }
                } catch (Exception ex) {
                    System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
                }
            }

        }
        return changedObjects;
    }

    /**
     * Same as findChangedRecs, but check if changed values meet a specific new value
     * @param  items            List of new records
     * @param  oldItemsMap      Map of old records
     * @param  field            The field on the SObject to check
     * @param  expectedNewValue The value that is desired on the new records. IF the value on the new record equals this value, then the old record is checked
     *                          to see if the value is set differently
     * @return                  List of eligible objects, or an empy list
     */
    public static List<SObject> findChangedRecsWithMatchingVal(List<SObject> items, Map<Id, SObject> oldItemsMap, Schema.SObjectField field, Object expectedNewValue) {
        List<SObject> changedObjects = new List<SObject>();
        for(SObject obj : items) {
            try {
                Object newObjValue = obj.get(field);
                if(newObjValue == expectedNewValue) {
                    Object oldObjValue = oldItemsMap.get((Id)obj.get(ID_STR)).get(field);
                    if(newObjValue != oldObjValue) {
                        changedObjects.add(obj);
                    }
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return changedObjects;
    }

    /**
     * Given a newList and oldMap, return the records that have a matching old value and new value.
     * This use-case is used when we only want to match records that had a specific value to begin with where the field was changed to another specified value
     * Example: Status changed from "Draft" to "Cancelled"
     * @param  items            List of new records
     * @param  oldItemsMap      Map of old records
     * @param  field            The field on the SObject to check
     * @param  oldValue         Old value of the record that the value should had to be considered to be returned
     * @param  expectedNewValue Value that the record should have to be returned
     * @return                  List of eligible objects, or an empy list
     */
    public static List<SObject> findChangedRecsWithMatchingVal(List<SObject> items, Map<Id, SObject> oldItemsMap, Schema.SObjectField field, Object oldValue, Object expectedNewValue) {
        List<SObject> changedObjects = new List<SObject>();
        for(SObject obj : items) {
            try {
                Object newObjValue = obj.get(field);
                Object oldObjValue = oldItemsMap.get((Id)obj.get(ID_STR)).get(field);
                if(oldObjValue == oldValue && newObjValue == expectedNewValue) {
                    changedObjects.add(obj);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return changedObjects;
    }

    /**
     * Same as findChangedRecs, but check if changed values meet a specific new value
     * @param  items            List of new records
     * @param  field            The field to check
     * @param  expectedValue    Return the record if the field's value equals this value
     * @return                  List of records where the field == expectedValue
     */
    public static List<SObject> findRecsWithMatchingValue(List<SObject> items, Schema.SObjectField field, Object expectedValue) {
        List<SObject> matchedObjects = new List<SObject>();
        for(SObject obj : items) {
            try {
                if(obj.get(field) == expectedValue) {
                    matchedObjects.add(obj);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return matchedObjects;
    }

    /**
     * Same as findChangedRecs, but check if changed values meet a specific new value
     * @param  items            List of new records
     * @param  field            The field to check
     * @param  expectedValue    Return the record if the field's value does not equals this value
     * @return                  List of records where the field != expectedValue
     */
    public static List<SObject> findRecsWithNonMatchingValue(List<SObject> items, Schema.SObjectField field, Object expectedValue) {
        List<SObject> matchedObjects = new List<SObject>();
        for(SObject obj : items) {
            try {
                if(obj.get(field) != expectedValue) {
                    matchedObjects.add(obj);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return matchedObjects;
    }

    public static Date getEarliestDate(List<SObject> items, Schema.SObjectField field) {
        return getEarliestDate(items, field, Date.today());
    }
    public static Date getEarliestDate(List<SObject> items, Schema.SObjectField field, Date defaultIfNull) {
        Date outputDate;
        for(SObject obj : items) {
            try {
                if(outputDate == null || outputDate > (Date) obj.get(field)) {
                    outputDate = (Date)obj.get(field);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        outputDate = outputDate != null ? outputDate : defaultIfNull;
        return outputDate;
    }

    public static Date getLatestDate(List<SObject> items, Schema.SObjectField field) {
        return getLatestDate(items, field, Date.today());
    }
    public static Date getLatestDate(List<SObject> items, Schema.SObjectField field, Date defaultIfNull) {
        Date outputDate;
        for(SObject obj : items) {
            try {
                if(outputDate == null || outputDate < (Date) obj.get(field)) {
                    outputDate = (Date)obj.get(field);
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        outputDate = outputDate != null ? outputDate : defaultIfNull;
        return outputDate;
    }

    /**
     * Find a record where a date is between a start/end date on a given record
     * This method is useful to find a record that exists within some defined range of another set of records
     *
     * @param items
     * @param valueToCompare Date to compare against, usually obtained from a record
     * @param startDateField Field containing a start date
     * @param endDateField field containing an end date
     * @param isInclusive [*optional] Defaults = true. IF true, this uses <= and >= instead of < and >
     *
     * @return
     */
    public static SObject findRecWithDateBetween(List<SObject> items, Date valueToCompare, Schema.SObjectField startDateField, Schema.SObjectField endDateField) {
        return findRecWithDateBetween(items, valueToCompare, startDateField, endDateField, true);
    }
    public static SObject findRecWithDateBetween(List<SObject> items, Date valueToCompare, Schema.SObjectField startDateField, Schema.SObjectField endDateField, Boolean isInclusive) {
        for(SObject obj : items) {
            try {
                if(isInclusive) {
                    if(valueToCompare >= (Date) obj.get(startDateField) && valueToCompare <= (Date) obj.get(endDateField)) {
                        return obj;
                    }
                } else {
                    if(valueToCompare > (Date) obj.get(startDateField) && valueToCompare < (Date) obj.get(endDateField)) {
                        return obj;
                    }
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return null;
    }

    /**
     * For a given record, compare a decimal field to see if record is between a range of two fields
     * Example: If you have an object with "Start" and "End" (as decimals), then you can pass in a number and find the record that matches that range
     * This is useful when you are working with many records, so you need to perform multiple matches, thus cannot use SOQL to target just one record  
     * 
     * This method returns the first match, and not multiple matches. Ensure that your orders are sorted appropriately.
     *
     * @param items
     * @param valueToCompare Date to compare against, usually obtained from a record
     * @param startField Field containing a start decimal
     * @param endField Field containing an end decimal
     * @param startIsInclusive [*optional] Defaults = true. If true, this uses <= and >= instead of < and >
     * @param endIsInclusive [*optional] Defaults = true. If true, this uses <= and >= instead of < and >
     * @param allowNullEnd [*optional] Defaults = false. If true, this allows end field to be null
     *
     * @return
     */
    public static SObject findRecWithDecimalBetween(List<SObject> items, Decimal valueToCompare, Schema.SObjectField startField, Schema.SObjectField endField) {
        return findRecWithDecimalBetween(items, valueToCompare, startField, endField, true, true);
    }
    public static SObject findRecWithDecimalBetween(List<SObject> items, Decimal valueToCompare, Schema.SObjectField startField, Schema.SObjectField endField, Boolean startIsInclusive, Boolean endIsInclusive) {
        return findRecWithDecimalBetween(items, valueToCompare, startField, endField, startIsInclusive, endIsInclusive, false);
    }
    public static SObject findRecWithDecimalBetween(List<SObject> items, Decimal valueToCompare, Schema.SObjectField startField, Schema.SObjectField endField, Boolean startIsInclusive, Boolean endIsInclusive, Boolean allowNullEnd) {
        for(SObject obj : items) {
            try {
                if(startIsInclusive) {
                    if(endIsInclusive) {
                        if (allowNullEnd) {
                            if(valueToCompare >= (Decimal) obj.get(startField) && (obj.get(endField) == null || valueToCompare <= (Decimal) obj.get(endField))) {
                                return obj;
                            }
                        } else {
                            if(valueToCompare >= (Decimal) obj.get(startField) && (obj.get(endField) != null && valueToCompare <= (Decimal) obj.get(endField))) {
                                return obj;
                            }
                        }
                    } else {
                        if (allowNullEnd) {
                            if(valueToCompare >= (Decimal) obj.get(startField) && (obj.get(endField) == null || valueToCompare < (Decimal) obj.get(endField))) {
                                return obj;
                            }                            
                        } else {
                            if(valueToCompare >= (Decimal) obj.get(startField) && (obj.get(endField) != null && valueToCompare < (Decimal) obj.get(endField))) {
                                return obj;
                            }
                        }
                    }
                } else {
                    if(endIsInclusive) {
                        if (allowNullEnd) {
                            if(valueToCompare > (Decimal) obj.get(startField) && (obj.get(endField) == null || valueToCompare <= (Decimal) obj.get(endField))) {
                                return obj;
                            }
                        } else {
                            if(valueToCompare > (Decimal) obj.get(startField) && (obj.get(endField) != null && valueToCompare <= (Decimal) obj.get(endField))) {
                                return obj;
                            }
                        }
                    } else {
                        if (allowNullEnd) {
                            if(valueToCompare > (Decimal) obj.get(startField) && (obj.get(endField) == null || valueToCompare < (Decimal) obj.get(endField))) {
                                return obj;
                            }

                        } else {
                            if(valueToCompare > (Decimal) obj.get(startField) && (obj.get(endField) != null && valueToCompare < (Decimal) obj.get(endField))) {
                                return obj;
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }
        return null;
    }

    /**
     * For items that are "bundled" by a self-lookup (e.x. quote lines or order product lines), this method groups
     * the quote lines by the parent most record id. Items will appear in the list in the order they are provided
     * @param  items            List of records
     * @param  bundleField      Field that has the self-lookup
     * @return                  List of eligible objects, or an empy list
     */
    public static Map<Id, List<SObject>> groupByTopLevelBundle(List<SObject> items, Schema.SObjectField bundleField) {
        Map<Id, List<SObject>> output = new Map<Id, List<SObject>>();
        Map<Id, Id> temp = new Map<Id, Id>();

        // Get top level bundle and create map of records and their parents
        for(SObject obj : items) {
            try {
                if(obj.get(bundleField) == null) {
                    output.put((Id) obj.get(ID_STR), new List<SObject>{obj});
                } else {
                    temp.put((Id) obj.get(ID_STR), (Id) obj.get(bundleField));
                }
            } catch (Exception ex) {
                System.debug('Error processing record, ignoring ' + ex.getStackTraceString());
            }
        }

        for(SObject obj : items) {
            // skip parent items
            if(output.containsKey((Id) obj.get(ID_STR))) {
                continue;
            }
            Boolean foundTopMostParent = false;
            Id currParent = (Id) obj.get(bundleField);

            // keep looking up through parent/grandparents until we find the topMost grandparent
            while(!foundTopMostParent) {
                if(output.containsKey(currParent)) {
                    output.get(currParent).add(obj);
                    foundTopMostParent = true;
                } else {
                    currParent = temp.get((Id) obj.get(bundleField));
                }
                if(currParent == null) {
                    throw new NoParentRecordIncludedException('Parent record not included in dataset');
                }
            }
        }

        return output;
    }

    /**
     * Format a date using the format options offered with a Datetime
     * Format options: https://docs.oracle.com/javase/7/docs/api/java/text/SimpleDateFormat.html
     *
     * @param d
     * @param format
     *
     * @return
     */
    public static String formatDate(Date d, String format) {
        if(d == null) { return null; }
        return Datetime.newInstance(d, Time.newInstance(1, 0, 0, 0)).format(format);
    }

    /**
     * ********************** Query Helpers ********************
     */
    /**
     * Query records with a string SObject name
     * @params objectName
     * @params whereClause [*optional] Where clause (this must begin with "WHERE", e.x. "WHERE Type = \'Foo\'")
     *  This can be overloaded with any final part of the query (e.x. LIMIT, ORDER BY) that can be included with or without "WHERE"
     *
     */
    public static List<SObject> dynamicQuery(String objectName) {
        return dynamicQuery(objectName, '');
    }
    public static List<SObject> dynamicQuery(String objectName, String whereClause) {
        String soql = 'SELECT ' + getAllFieldsForSObjAsStr(objectName) + ' FROM ' + objectName + ' ' + whereClause;
        return Database.query(soql);
    }

    /**
     * Query records with a string SObject name
     * @params parentObjName
     * @params childObjName
     * @params childObjRelationshipName
     * @params whereClause [*optional] Where clause (this must begin with "WHERE", e.x. "WHERE Type = \'Foo\'")
     *  This can be overloaded with any final part of the query (e.x. LIMIT, ORDER BY) that can be included with or without "WHERE"
     *
     */
    public static List<SObject> dynamicQueryWithSubquery(String parentObjName, String childObjName, String childObjRelationshipName) {
        return dynamicQueryWithSubquery(parentObjName, childObjName, childObjRelationshipName, '', '');
    }
    public static List<SObject> dynamicQueryWithSubquery(String parentObjName, String childObjName, String childObjRelationshipName, String parentWhereClause, String childWhereClause) {
        String soql = 'SELECT ' + getAllFieldsForSObjAsStr(parentObjName) + ', (SELECT ' + getAllFieldsForSObjAsStr(childObjName) + ' FROM ' + childObjRelationshipName + ' ' + childWhereClause + ') FROM ' + parentObjName + ' ' + parentWhereClause;
        return Database.query(soql);
    }

    /** Get all fields for an sobject as a list - helpful for dynamic SOQL */
    public static List<String> getAllFieldsForSobj(String sobjectName) {
        List<String> allFields = new List<String>(getFieldMap(sobjectName).keySet());
        return allFields;
    }

    /**
     * Method to return list of creatable fields for a given object.
     * @param String objectName
     * @return List of creatable fields for a given SObject.
     */
    public static List<String> getCreatableFields(String sObjectName) {
        // Get a map of field name and field token
        Map<String, Schema.SObjectField> fMap = getFieldMap(sObjectName);

        List<String> creatableFields = new List<String>();
        if(fMap != null) {
            for (Schema.SObjectField fieldSchema : fMap.values()){
                Schema.DescribeFieldResult fieldDescribe = fieldSchema.getDescribe(); // describe each field (fd)
                if (fieldDescribe.isCreateable() && !(fieldDescribe.isExternalId() && fieldDescribe.isAutoNumber())){ // field is creatable
                    creatableFields.add(fieldDescribe.getName());
                }
            }
        }
        return creatableFields;
    }

    /**
     * Method to return list of Updateable Fields fields for a given object.
     * @param String objectName
     * @return List of creatable fields for a given SObject.
     */
    public static List<String> getUpdateableFields(String sObjectName) {
        // Get a map of field name and field token
        Map<String, Schema.SObjectField> fMap = getFieldMap(sObjectName);

        List<String> updateableFields = new List<String>();
        if(fMap != null) {
            for (Schema.SObjectField fieldSchema : fMap.values()){
                Schema.DescribeFieldResult fieldDescribe = fieldSchema.getDescribe(); // describe each field (fd)
                if (fieldDescribe.isUpdateable() && !(fieldDescribe.isExternalId() && fieldDescribe.isAutoNumber())){ // field is creatable
                    updateableFields.add(fieldDescribe.getName());
                }
            }
        }
        return updateableFields;         
    }

    /**
     * @desription -> Method to return a SOQL string with all creatable fields:
     * @param String objectName -> object name to use in query
     * @param String whereClause -> where clause to use in query
     * @return List of creatable fields for a given SObject.
     */
    public static String getCreatableFieldsSOQL(String sObjectName, String whereClause){
        if (whereClause == null || whereClause == ''){ return null; }

        // Get a map of field name and field token
        Map<String, Schema.SObjectField> fMap = getFieldMap(sObjectName);

        List<String> fieldsToSelect = getCreatableFields(sObjectName);
        return 'SELECT ' + String.join(fieldsToSelect, ',') + ' FROM ' + sObjectName + ' WHERE ' + whereClause;
    }

    /** Get all fields for an sobject as a list, except those in the blacklist */
    public static List<String> getAllFieldsExceptBlacklist(String sobjectName, List<String> blackList) {
        Set<String> fields = new Set<String>(getAllFieldsForSobj(sobjectName));
        for(String blackListedField : blackList) {
             if(fields.contains(blackListedField)) {
                 fields.remove(blackListedField);
             } else if(fields.contains(blackListedField.toLowerCase())) {
                 fields.remove(blackListedField.toLowerCase());
             }
         }
        return new List<String>(fields);
    }

    /** Get comma delimited string list of all sobject fields */
    public static String getAllFieldsForSObjAsStr(String sobjectName) {
       return String.join(getAllFieldsForSobj(sobjectName), ', ');
    }
    /** Get comma delimited string list of sobject fields, except those in the blacklist */
    public static String getAllFieldsExceptBlacklistAsStr(String sobjectName, List<String> blackList) {
       return String.join(getAllFieldsExceptBlacklist(sobjectName, blackList), ', ');
    }

    /** Get comma delimited string list of creatable sobject fields */
    public static String getCreatableFieldsAsStr(String sobjectName) {
        List<String> creatableFields = getCreatableFields(sobjectName);
        return String.join(creatableFields, ', ');
    }

    /*
    * randomizers
    */
    public static String randomString(Integer length){
        String key = EncodingUtil.base64Encode(Crypto.generateAesKey(192));
        return key.substring(0,length);
    }

    /*
     * Id validation
     */
    static public String validateId(String Idparam) {
        String id = String.escapeSingleQuotes(Idparam);
        if((Idparam instanceof Id) && (id.length() == 15 || id.length() == 18) && Pattern.matches('^[a-zA-Z0-9]*$', id)) {
            return id;
        }
        return null;
    }

    /**
     * Get environment short name from url.
     * @param none
     * @return String of the environment name
     * Example:
     *   Url structure: https://xyzcompany.my.salesforce.com
     *   This method will return 'xyzcompany'
     */
    public static String getEnvironmentName() {
        return getEnvironmentName(null);
    }
    /* Optionally pass in a string to detect in the subDomainWithProtocol name and truncate after that.
     * Example:
     *   Url structure: https://xyzcompany--dev.cs77.my.salesforce.com
     *   Passing in '--' as the parameter will cause the method to return 'dev'
     */ 
    public static String getEnvironmentName(String urlPortionToSnipAfter) {
        // subDomainWithProtocol is set at the class level to allow mocking in unit test by setting specific Url
        if(urlPortionToSnipAfter == null || !subDomainWithProtocol.contains(urlPortionToSnipAfter)) {
            urlPortionToSnipAfter = 'https://'; 
        }
        Integer intIndex = subDomainWithProtocol.indexOf(urlPortionToSnipAfter) + urlPortionToSnipAfter.length();
        String envName = subDomainWithProtocol.substring(intIndex, subDomainWithProtocol.length());
      
        return envName;
    }

    /** 
     * @description -> get instance name from organization
     * @param null
     * @return a String of the instance name for the org (ex: na77)
     */ 
    public static String getInstanceName() {
        // the '+ 1' below is for the dot (.) in the full Url. 
        // Example: https://companyname--dev.cs50.my.salesforce.com. The + 1 is for the dot after 'dev'
        String instanceName = instanceURL.substring(subDomainWithProtocol.length() + 1);
        instanceName = instanceName.remove('.my.salesforce.com');
        instanceName = instanceName.remove('.visual.force.com');

        // example instance names: na9, na77, cs50, cs70, etc
        if(instanceName == null || instanceName.length() > 5 || instanceName.length() < 3) { 
            instanceName = [SELECT InstanceName FROM Organization LIMIT 1].InstanceName;
        }
        return instanceName;
    }

    /**
     * Method to make it easier to build a 'string to list of sObjects' map within a loop.
     * 
     * @param Map<String, List<SObject>> mapParam -> the map to build/add to
     * @param String mapKey -> the map key (you will probably have multiple map keys in which to store the values at)
     * @param SObject objToPutAtKey -> the obj to accrue at the mapKey
     */
    public static Map<String, List<SObject>> stringToObjListMapBuilder(Map<String, List<SObject>> mapParam, String mapKey, SObject objToPutAtKey) {
        List<SObject> objList = mapParam.get(mapKey) == null ? new List<SObject>() : mapParam.get(mapKey);
        objList.add(objToPutAtKey);
        mapParam.put(mapKey, objList);
        return mapParam;
    }

    /**
     * Sort an id to SObject map by the number of items in each list ascending.
     * Example param: we have a list of sObjects (assets and subs for example) where the list is chunked as follows:
     *   A, S, A, A, S, A, S, A, S, A, S, A, S, A, S, A
     *   
     *   Salesforce gives a 'Cannot have more than 10 chunks in a single operation' error if trying to peform DML on the list, if the list
     *   switches object types more than 10 times (like the above list does).
     *   
     *   This method sorts the objects by Id, so then afterwards the list is chunked as follows:
     *   A, A, A, A, A, A, A, A, A, S, S, S, S, S, S, S

     *   Thus we can perform DML on the list no problem. This method has been tested and works as expected. Your mileage may vary, but doubtful :)
     * 
     * @param  mapToSort -> Id to SObject map to sort, in order to consolidate the chunks 
     * @return sortedMap -> an Id to SObject map with consolidated chunks (1 chunk per object type)
     */ 
    public static Map<Id, SObject> mapSorter(Map<Id, SObject> mapToSort) {
        List<Id> sortedList = new List<Id>(mapToSort.keySet());
        sortedList.sort();
    
        Map<Id, SObject> sortedMap = new Map<Id, SObject>();
        for(String idKey : sortedList) {
            sortedMap.put(idKey, mapToSort.get(idKey));
        }
    
        return sortedMap;
    }

    /**
     * Method to sort an Id to SObject map by object types of the Id keys. This method could be a more reliable means of sorting as compared
     *  to the mapSorterById method, but it won't be as good on performance.
     *
     * @param  mapToSort -> Id to SObject map to sort, in order to consolidate the chunks 
     * @return sortedMap -> an Id to SObject map with consolidated chunks (1 chunk per object type)
     */
    public static Map<Id, SObject> mapSorterByObjType(Map<Id, SObject> mapToSort) {
        Map<String, List<SObject>> objTypeToObjListMap = new Map<String, List<SObject>>();
        for(SObject obj : mapToSort.values()) {
            String objType = String.valueOf(obj.getSObjectType()); // can't use groupBy since we're grouping by objType
            stringToObjListMapBuilder(objTypeToObjListMap, objType, obj);
        }

        Map<Id, SObject> sortedMap = new Map<Id, SObject>();
        // Loop through each object type:
        for(String objType : objTypeToObjListMap.keySet()) {
            // Loop through each object that has that type:
            for(SObject obj : objTypeToObjListMap.get(objType)) {
                sortedMap.put((Id)obj.get(ID_STR), obj);
            }
        }

        // Now the sortedMap will be nice and organized by obj type, as to avoid the 'over 10 chunks' apex error.
        return sortedMap;
    }

    /**
     * Sort a string to list map by the number of items in each list ascending.
     * Example param: We have a quote id to quote lines map, where each quote id is mapped to associated list of quote lines.
     *   quote id A (first quote id in the map) has 5 quote lines
     *   quote id B (second quote in id the map) has 3 quote lines
     *   quote id C (third quote id in the map) has 11 quote lines
     *   
     *   After sorting:
     *   quote id B (first quote id in the map, 3 quote lines)
     *   quote id A (second quote id in the map, 5 quote lines)
     *   quote id C (third quote id in the map, 11 quote lines)
     * 
     * @param  mapToSort -> map of: String to list of sobjects to sort. 
     * @return sortedMap -> a sorted map by the number of items in each of the key's lists ascending
     */ 
    public static Map<String, List<SObject>> mapSorterByNumOfChildren(Map<String, List<SObject>> mapToSort) {
        Map<String, List<SObject>> prepSortedMap = new Map<String, List<SObject>>();
        String placeholderDigits = '00000';
        for(String key : mapToSort.keySet()) {
            List<SObject> childObjList = mapToSort.get(key) == null ? new List<SObject>() : mapToSort.get(key);
            String numOfChildren = String.valueOf(childObjList.size());
            String keyPrefix = placeholderDigits.substring(0, placeholderDigits.length() - numOfChildren.length()) + numOfChildren;
            prepSortedMap.put(keyPrefix + '*' + key, childObjList);
        }
        
        List<String> sortedList = new List<String>(prepSortedMap.keySet());
        sortedList.sort();
    
        Map<String, List<SObject>> sortedMap = new Map<String, List<SObject>>();
        for(String idKey : sortedList) {
            Id idFromIdKey = Id.valueOf(idKey.substring(idKey.indexOf('*') + 1, idKey.length()));
            sortedMap.put(idFromIdKey, prepSortedMap.get(idKey));
        }
    
        return sortedMap;
    }

    /**
     * Inner class to assist in sheduling apex jobs. 
     *
     * Example usage: 
     *   In the following example: we will schedule a schedulable apex class called 'MySchedulableApexClassName' to run 1.5 ours from now:
     *     CPQU_ApexUtils.ScheduleBuilder scheduleBuilder = new CPQU_ApexUtils.ScheduleBuilder('myJob', 'MySchedulableApexClassName').addHours(1).addMinutes(30).run();
     * 
     * Constructor params:
     * @param jobName -> the desired name of the schedule
     * @param className -> the desired name of the schedule
     *
     */ 
    public class ScheduleBuilder {
        public Datetime pointInFuture = System.now();
        public Id scheduleId;
        public String className; 
        public String strJobName;
        public String strSchedule;
        private final String SECONDS = 'seconds';
        private final String MINUTES = 'minutes';
        private final String HOURS = 'hours';
        private final String DAYS = 'days';

        // contructor flavor 1 
        //  (defaults to scheduling the job NOW. You can use the addHours, addMinutes, addSeconds, and addDays methods below to push it further out) 
        public ScheduleBuilder(String jobName, String className) {
            this.className = className;
            this.strJobName = jobName + '. Date: ' + this.pointInFuture.month() + '/' + this.pointInFuture.day() + '/' + this.pointInFuture.year() + ' ' + this.pointInFuture.hour() + ':' + this.pointInFuture.minute() + ':' + this.pointInFuture.second();
            this.strSchedule = this.pointInFuture.second() + ' ' + this.pointInFuture.minute() + ' ' + this.pointInFuture.hour() + ' ' + this.pointInFuture.day() + ' ' + this.pointInFuture.month() + ' ?' + ' ' + this.pointInFuture.year();
        }

        /**
         * @description -> Method to add seconds to the schedule (push the start time out by a specified number of seconds).
         * @param hoursToAdd -> number of seconds to add to the schedule.
         * @return ScheduleBuilder this -> the modified job to schedule
         */
        public ScheduleBuilder addSeconds(Integer secondsToAdd) {
            this.pointInFuture.addSeconds(secondsToAdd);
            this.strSchedule = buildScheduleString(this.pointInFuture);
            return this;
        }

        /**
         * @description -> Method to add minutes to the schedule (push the start time out by a specified number of minutes).
         * @param hoursToAdd -> number of minutes to add to the schedule.
         * @return ScheduleBuilder this -> the modified job to schedule
         */
        public ScheduleBuilder addMinutes(Integer minutesToAdd) {
            this.pointInFuture.addMinutes(minutesToAdd);
            this.strSchedule = buildScheduleString(this.pointInFuture);
            return this;
        }
        
        /**
         * @description -> Method to add hours to the schedule (push the start time out by a specified number of hours).
         * @param hoursToAdd -> number of hours to add to the schedule.
         * @return ScheduleBuilder this -> the modified job to schedule
         */
        public ScheduleBuilder addHours(Integer hoursToAdd) {
            this.pointInFuture.addHours(hoursToAdd);
            this.strSchedule = buildScheduleString(this.pointInFuture);
            return this;
        }

        /**
         * @description -> Method to add days to the schedule (push the start time out by a specified number of days).
         * @param hoursToAdd -> number of days to add to the schedule.
         * @return ScheduleBuilder this -> the modified job to schedule
         */
        public ScheduleBuilder addDays(Integer daysToAdd) {
            this.pointInFuture.addDays(daysToAdd);
            this.strSchedule = buildScheduleString(this.pointInFuture);
            return this;
        }

        /**
         * @description -> Method to set the point in future that the schedule will run, once the run method is invoked.
         * @param DateTime pointInFuture -> the point in the future in which to execute the scheduled job
         * @return String -> the stringified point in time to execute the scheduled job
         */
        public String buildScheduleString(Datetime pointInFuture) {
            return pointInFuture.second() + ' ' + pointInFuture.minute() + ' ' + pointInFuture.hour() + ' ' + 
                pointInFuture.day() + ' ' + pointInFuture.month() + ' ?' + ' ' + pointInFuture.year(); 
        }

        /**
         * @description -> Method to queue up the scheduled job
         * @param void
         * @return null
         */
        public ScheduleBuilder run() {
            Type theType = Type.forName(this.className);
            try {
                this.scheduleId = System.schedule(this.strJobName, this.strSchedule, (Schedulable)theType.newInstance());
            } catch(Exception e) {
                System.debug('CPQU_ApexUtils.ScheduleBuilder: Error scheduling job. ' + e.getStackTraceString());
            }
            return this;
        }
    }

    /** 
     * @description -> method to parse field references, even if in dot notation (ex: Contact.Account.Name)
     *  Example: if I have a queried Task record where I queried Contact.Account.Name from the Task,
     *  if I pass in the Task record and 'Contract.Account.Name' as a string, this method will return the value stored in the 'Name'.
     * @param SObject record -> the record in which to parse the field reference from
     * @param String fieldReference -> the field reference in which to parse. Ex: 'Contact.Account.Name' will get the Name field value parsed
     * @return Object fieldVal -> the String, Integer, Boolean, etc parsed value. Ex: 'Contact.Account.Name' will return the value in the Account's Name field which is a String primitive Object.
     */
    public static Object parseFieldPathForSObject(SObject record, String fieldReference) {
        SObject tempObj = record; // if field has a "." this holds the nested objects until fields is reached
        Object fieldVal;
        // If provided field is using dot notation, get nested object and field
        if(!fieldReference.contains('.')) {
            return record.get(fieldReference);
        } else {
            List<String> fields = fieldReference.split('\\.');
            for(String splitField : fields) {
                try {
                    tempObj = (SObject)tempObj.getSObject(splitField);
                } catch (Exception ex) {
                    try{
                        fieldVal = tempObj == null ? null : tempObj.get(splitField);
                    } catch (Exception exx) {
                        return null;
                    }
                }
            }
        }
        return fieldVal;
    }

    /**
     * @description -> Method to get properties of a field set.
     * @usage example:
     *  List<Schema.FieldSetMember> fieldSetMemberList =  readFieldSet('SBQQ__LineEditor','SBQQ__Quote__c');
     *  for(Schema.FieldSetMember fieldSetMemberObj : fieldSetMemberList) {
     *      system.debug('API Name ====>' + fieldSetMemberObj.getFieldPath()); //api name
     *      system.debug('Label ====>' + fieldSetMemberObj.getLabel());
     *      system.debug('Required ====>' + fieldSetMemberObj.getRequired());
     *      system.debug('DbRequired ====>' + fieldSetMemberObj.getDbRequired());
     *      system.debug('Type ====>' + fieldSetMemberObj.getType());   //type - STRING,PICKLIST
     *  }
     *
     * @param String fieldSetName -> name of field set you wish to get the properties (ex: fields) for
     * @return List<Schema.FieldSetMember -> field set properties to return.
     */
    public static List<Schema.FieldSetMember> readFieldSet(String fieldSetName, String ObjectName)  {
        Schema.SObjectType SObjectTypeObj = globalDescribe.get(ObjectName);
        Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.fieldSets.getMap().get(fieldSetName);
        return fieldSetObj.getFields(); 
    }

    /**
     * @description -> Method to get list of field API names to query, given a Schema.FieldSetMember list:
     * @param List<Schema.FieldSetMember> fieldSetMemberList -> a Schema.FieldSetMember list in which to parse the field API names from
     * @return List<String> fieldSetFieldAPINames -> a list of field API names parsed from the field set parameter
     */ 
    public static List<String> getFieldSetFieldAPINames(List<Schema.FieldSetMember> fieldSetMemberList) {
        Set<String> fieldSetFieldAPINamesSet = new Set<String>();
        for(Schema.FieldSetMember fieldSetMemberObj : fieldSetMemberList) {   
            fieldSetFieldAPINamesSet.add(fieldSetMemberObj.getFieldPath());
        }
        List<String> fieldSetFieldAPINames = new List<String>(fieldSetFieldAPINamesSet);
        return fieldSetFieldAPINames;
    }

    /**
     * @description -> given a Set<String> with comma delimited lists of custom Trigger Handlers, build a Set<String> of those Trigger Handlers
     * @param String triggerHandlerDelimitedStrings -> a Set<String> containing comma delimited lists of custom Trigger Handlers
     * @return Set<String> consolidatedTriggerHandlers -> the Trigger Handler names in a consolidated set
     */
    public static Set<String> consolidateTriggerHandlerNames(Set<String> triggerHandlerDelimitedStrings) {
        List<String> consolidatedTriggerHandlers = new List<String>();
        for(String triggerHandlerString : triggerHandlerDelimitedStrings) {
            List<String> individualTriggerHandlers = triggerHandlerString == null ? new List<String>() :  triggerHandlerString.split(',');
            consolidatedTriggerHandlers.addAll(individualTriggerHandlers);
        }

        return new Set<String>(consolidatedTriggerHandlers);
        
    }
}