trigger CPQU_ErrorLogEventTrigger on CPQU_ErrorLogEvent__e (after insert) {
    new CPQU_ErrorLogEventTriggerHandler().run();
}