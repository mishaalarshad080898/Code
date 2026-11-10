/// <summary>
/// Job queue entry point: processes all inbound ICR movements in status Received.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.2 Core Behavior (Validated inbound payloads initiate Business Central transaction processing)
codeunit 50424 "IP ICR Movement Job Queue"
{
    TableNo = "Job Queue Entry";

    trigger OnRun()
    var
        MovementProcessing: Codeunit "IP ICR Movement Processing";
    begin
        MovementProcessing.ProcessReceivedEntries();
    end;
}
