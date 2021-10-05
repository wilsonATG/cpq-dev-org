/**
 * 
 * CPQXL_OpportunityTrigger class
 *
 * Versioning: 
 *   3/22/21 : stevelohrenz : File Created
 */

trigger CPQXL_OpportunityTrigger on Opportunity (before insert, before update, after insert, after update) {
    new CPQXL_OpportunityTriggerHandler().run();
}