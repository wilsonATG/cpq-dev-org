/**
 * 
 * CPQXL_QuoteOrderXLTrigger class
 *
 * Versioning: 
 *   3/22/21 : stevelohrenz : File Created
 */

trigger CPQXL_QuoteOrderXLTrigger on CPQXL_GenerateLargeOrderEvent__e (after insert) {
    new CPQXL_QuoteOrderXLTriggerHandler().run();
}