/// <summary>
/// Entry point for processing inbound ICR movements (manually, from the job queue or as a retry).
/// Rejects duplicates, runs each movement in its own transaction, and records the result on the
/// movement and in the Filler Integration Activity Log. A failed movement is set to Exception and
/// can be corrected and retried; a processed movement is never posted again.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 / 6.5 / 5.2 Integration Assumptions (1) Payload failures may occur and require retry processing / (2) Duplicate transaction prevention
codeunit 50417 "IP ICR Movement Processing"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        Validation: Codeunit "IP ICR Movement Validation";
        MovementLogMgt: Codeunit "IP ICR Movement Log Mgt";
        ReceivedTxt: Label 'ICR movement %1 received (MVT_TYPE %2, order %3, ICR document %4).', Comment = '%1 = Entry No., %2 = Movement type, %3 = PO_NUMBER, %4 = HDTEXT';
        DuplicateErr: Label 'Duplicate ICR movement: a movement with the same Message ID or the same movement type, order and ICR document number was already processed.';
        ProcessedTxt: Label 'ICR movement %1 processed. Posted document %2.', Comment = '%1 = Entry No., %2 = Posted document No.';
        FailedTxt: Label 'ICR movement %1 failed. Nothing was posted.', Comment = '%1 = Entry No.';
        FailedAfterPostTxt: Label 'ICR movement %1 was posted, but a later step failed.', Comment = '%1 = Entry No.';
        RetryOnlyExceptionErr: Label 'Only ICR movements with status Exception can be retried.';
        ProcessedMsg: Label 'ICR movement %1 was processed.', Comment = '%1 = Entry No.';
        FailedMsg: Label 'ICR movement %1 could not be processed:\\%2', Comment = '%1 = Entry No., %2 = Error';
        DuplicateMsg: Label 'ICR movement %1 is a duplicate and was not processed.', Comment = '%1 = Entry No.';
        NotOrchestrationErr: Label 'ICR inbound entry %1 (MVT_TYPE %2) is not an Inventory Orchestration entry. It is processed by the ICR-MRP inbound process (production PO completion, scrap or adjustment).', Comment = '%1 = Entry No., %2 = Movement type';

    /// <summary>
    /// Processes one movement. Duplicates are set to Duplicate. Otherwise the movement runs in its
    /// own transaction; on failure everything is rolled back and the movement is set to Exception with
    /// the error. Returns true when the movement was processed.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Failures prevent posting)
    procedure ProcessEntry(var MovementHeader: Record "IP ICR Inbound Entry Header"): Boolean
    var
        Success: Boolean;
    begin
        // One inbound table serves both FDDs: only raw material receipts (030 without Assembly Order)
        // and finished goods transfers (311) are processed here.
        if not MovementHeader.IsInventoryOrchestration() then
            Error(NotOrchestrationErr, MovementHeader."Entry No.", MovementHeader."Mvt Type");
        if MovementHeader.Status = MovementHeader.Status::Processed then
            exit(true);
        if MovementHeader.Status = MovementHeader.Status::Duplicate then
            exit(false);

        if Validation.IsDuplicate(MovementHeader) then begin
            MovementHeader.Status := MovementHeader.Status::Duplicate;
            MovementHeader."Error Message" := DuplicateErr;
            MovementHeader.Modify();
            MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"ICR Movement Validation", "IP Integration Status"::Skipped, DuplicateErr, DuplicateErr);
            Commit();
            exit(false);
        end;

        Commit();
        ClearLastError();
        Context.SetSuppressOutbound(true);
        Success := Codeunit.Run(Codeunit::"IP ICR Movement Posting", MovementHeader);
        Context.SetSuppressOutbound(false);

        MovementHeader.Get(MovementHeader."Entry No.");
        if Success then
            MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"ICR Movement Processing", "IP Integration Status"::Success,
                StrSubstNo(ProcessedTxt, MovementHeader."Entry No.", MovementHeader."Posted Document No."), '')
        else
            SetException(MovementHeader, GetLastErrorText());
        Commit();
        exit(Success);
    end;

    /// <summary>
    /// Retry: reprocesses a movement in Exception status after the cause was fixed. The retry count
    /// is increased and kept in the Activity Log.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 5.2 Integration Assumptions (1) Payload failures may occur and require retry processing
    procedure RetryEntry(var MovementHeader: Record "IP ICR Inbound Entry Header"): Boolean
    begin
        if MovementHeader.Status <> MovementHeader.Status::Exception then
            Error(RetryOnlyExceptionErr);
        MovementHeader."Retry Count" += 1;
        MovementHeader.Status := MovementHeader.Status::Received;
        MovementHeader.Modify();
        exit(ProcessEntry(MovementHeader));
    end;

    /// <summary>
    /// Processes or retries a movement from the UI and shows the result.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility
    procedure ProcessEntryWithMessage(var MovementHeader: Record "IP ICR Inbound Entry Header"; IsRetry: Boolean)
    var
        Success: Boolean;
    begin
        if IsRetry then
            Success := RetryEntry(MovementHeader)
        else
            Success := ProcessEntry(MovementHeader);
        if Success then
            Message(ProcessedMsg, MovementHeader."Entry No.")
        else
            if MovementHeader.Status = MovementHeader.Status::Duplicate then
                Message(DuplicateMsg, MovementHeader."Entry No.")
            else
                Message(FailedMsg, MovementHeader."Entry No.", MovementHeader."Error Message");
    end;

    /// <summary>
    /// Processes all Inventory Orchestration entries (030 without Assembly Order, 311) in status
    /// Received, oldest first. Entries of the ICR-MRP process are left alone. Used by the job queue.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.2 Core Behavior (Validated inbound payloads initiate Business Central transaction processing)
    procedure ProcessReceivedEntries()
    var
        MovementHeader: Record "IP ICR Inbound Entry Header";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        MovementHeader.SetCurrentKey(Status, "Mvt Type");
        MovementHeader.SetRange(Status, MovementHeader.Status::Received);
        MovementHeader.SetFilter("Mvt Type", '%1|%2', '030', '311');
        if MovementHeader.FindSet() then
            repeat
                if MovementHeader.IsInventoryOrchestration() then
                    EntryNos.Add(MovementHeader."Entry No.");
            until MovementHeader.Next() = 0;

        foreach EntryNo in EntryNos do
            if MovementHeader.Get(EntryNo) then
                ProcessEntry(MovementHeader);
    end;

    /// <summary>
    /// Payload receipt is logged as soon as the middleware inserts the movement.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Receives payload / Activity is logged)
    [EventSubscriber(ObjectType::Table, Database::"IP ICR Inbound Entry Header", 'OnAfterInsertEvent', '', false, false)]
    local procedure MovementHeaderOnAfterInsert(var Rec: Record "IP ICR Inbound Entry Header")
    begin
        if Rec.IsTemporary() then
            exit;
        MovementLogMgt.LogMovement(Rec, "IP Integration Event Type"::"ICR Movement Received", "IP Integration Status"::Success,
            StrSubstNo(ReceivedTxt, Rec."Entry No.", Rec."Mvt Type", Rec."PO Number", Rec."HD Text"), '');
    end;

    /// <summary>
    /// Records a failure on the movement and in the Activity Log. If the BC document was already
    /// posted (status committed as Processed), the movement stays Processed so it is never posted
    /// twice; only the error is logged.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.3 Outbound Integration Trigger Points (Records failures) / 6.4 (Failures prevent posting)
    local procedure SetException(var MovementHeader: Record "IP ICR Inbound Entry Header"; ErrorText: Text)
    begin
        if MovementHeader.Status = MovementHeader.Status::Processed then begin
            MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"ICR Movement Processing", "IP Integration Status"::Exception,
                StrSubstNo(FailedAfterPostTxt, MovementHeader."Entry No."), ErrorText);
            exit;
        end;
        MovementHeader.Status := MovementHeader.Status::Exception;
        MovementHeader."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(MovementHeader."Error Message"));
        MovementHeader.Modify();
        MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"ICR Movement Processing", "IP Integration Status"::Exception,
            StrSubstNo(FailedTxt, MovementHeader."Entry No."), ErrorText);
    end;
}
