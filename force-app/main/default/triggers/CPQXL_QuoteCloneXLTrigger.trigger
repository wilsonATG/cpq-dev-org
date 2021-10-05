/**
* * Created by Name / Date:  Kevin Antonioli 8.28.2019 for B-13097 (governor limits workaround for generating large orders)
*
* Description:
* Trigger on CPQXL_CloneLargeQuoteEvent__e event object.  All logic handled in CPQXL_QuoteCloneXLTriggerHandler class.
*   which implements the TriggerHandler class. do not put logic in this trigger
*
*
* Revisions:
* Date : Name : Notes
*
* Note: specific code  comments related to non-trivial logic, method usage, and revisions will be
*             included in the appropriate area of the code below
*  Note: always implement all trigger actions in the trigger class. they will be handled in the handler class
*/
trigger CPQXL_QuoteCloneXLTrigger on CPQXL_CloneLargeQuoteEvent__e (after insert) {
    new CPQXL_QuoteCloneXLTriggerHandler().run();
}