/// <summary>
/// Job Queue entry point that processes newly received inbound filler completion payloads.
/// Exception entries are not retried automatically; retry is a manual action.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing / 4.2 Integration Assumptions (2)
codeunit 50111 "IP Inbound Job Queue"
{
    TableNo = "Job Queue Entry";

    /// <summary>
    /// Runs inbound processing for all entries with status Received.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
    trigger OnRun()
    var
        InboundProcessing: Codeunit "IP Inbound Processing";
    begin
        InboundProcessing.ProcessReceivedEntries();
    end;
}
