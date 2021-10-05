/**
 * 
 * CPQXL_QuoteTrigger class
 *
 * Versioning: 
 *   3/22/21 : Steve Lohrenz : File Created
 */

trigger CPQXL_QuoteTrigger on SBQQ__Quote__c (before insert, before update, after insert, after update) {
    new CPQXL_QuoteTriggerHandler().run();
}