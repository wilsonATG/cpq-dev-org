/**
 * 
 * CPQXL_OrderContractXLTrigger class
 *
 * Versioning: 
 *   3/22/21 : stevelohrenz : File Created
 */

trigger CPQXL_OrderContractXLTrigger on CPQXL_GenerateLargeContractEvent__e (after insert) {
    new CPQXL_OrderContractXLTriggerHandler().run();
}