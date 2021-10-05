/**
 * 
 * CPQXL_OrderTrigger class
 *
 * Versioning: 
 *   3/22/21 : stevelohrenz : File Created
 */

trigger CPQXL_OrderTrigger on Order (before insert, before update, after insert, after update) {
  new CPQXL_OrderTriggerHandler().run();
}