/// <summary>
/// Orchestrates inbound completion processing: duplicate check, validation, then automated
/// posting. Every step is logged. On any failure the entry becomes an Exception with a
/// detailed error in the Activity Log and the AO Filler Status is set to Exception. Retry is
/// manual and resumes from the first step that did not complete.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing / 4.2 Integration Assumptions (2) Payload Transmission Supports Retry and Reprocessing
codeunit 50110 "IP Inbound Processing"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        ValidationPassedTxt: Label 'Inbound payload validated successfully.';
        ProcessedTxt: Label 'Inbound completion processed successfully.';
        DuplicateTxt: Label 'Duplicate payload ignored. Message ID %1 has already been processed.', Comment = '%1 = Message ID';
        RetryTxt: Label 'Manual retry %1 requested.', Comment = '%1 = Retry count';
        AlreadyProcessedErr: Label 'Inbound entry %1 has already been processed.', Comment = '%1 = Entry No.';
        ProcessedMsg: Label 'Inbound entry %1 was processed successfully.', Comment = '%1 = Entry No.';
        ExceptionMsg: Label 'Inbound entry %1 could not be processed:\%2', Comment = '%1 = Entry No., %2 = Error';

    /// <summary>
    /// Processes one inbound completion entry end to end. Returns true when it is fully processed.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Business Central Behavior)
    procedure ProcessEntry(var InboundEntry: Record "IP Filler Inbound Entry"): Boolean
    var
        InboundValidation: Codeunit "IP Inbound Validation";
        ErrorText: Text;
        Success: Boolean;
    begin
        if InboundEntry.Status in [InboundEntry.Status::Processed, InboundEntry.Status::Duplicate] then
            exit(InboundEntry.Status = InboundEntry.Status::Processed);

        if InboundValidation.IsDuplicate(InboundEntry) then begin
            InboundEntry.Status := InboundEntry.Status::Duplicate;
            InboundEntry."Error Message" := CopyStr(StrSubstNo(DuplicateTxt, InboundEntry."Message ID"), 1, MaxStrLen(InboundEntry."Error Message"));
            InboundEntry.Modify();
            LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Inbound Validation", "IP Integration Status"::Skipped, InboundEntry."Error Message", '');
            Commit();
            exit(false);
        end;

        Commit();
        ClearLastError();
        if not Codeunit.Run(Codeunit::"IP Inbound Validation", InboundEntry) then
            exit(SetException(InboundEntry, "IP Integration Event Type"::"Inbound Validation", GetLastErrorText()));
        InboundEntry.Get(InboundEntry."Entry No.");
        LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Inbound Validation", "IP Integration Status"::Success, ValidationPassedTxt, '');
        Commit();

        ClearLastError();
        Success := Codeunit.Run(Codeunit::"IP Inbound Posting", InboundEntry);
        ErrorText := GetLastErrorText();
        Context.ResetContext();
        InboundEntry.Get(InboundEntry."Entry No.");
        if not Success then
            exit(SetException(InboundEntry, "IP Integration Event Type"::"Inbound Processing", ErrorText));

        InboundEntry.Status := InboundEntry.Status::Processed;
        InboundEntry."Processed At" := CurrentDateTime();
        InboundEntry."Error Message" := '';
        InboundEntry.Modify();
        LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Inbound Processing", "IP Integration Status"::Success, ProcessedTxt, '');
        Commit();
        exit(true);
    end;

    /// <summary>
    /// Manual retry of an inbound entry in Exception status. Posting steps that already completed
    /// are skipped, so no transaction is duplicated.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (2) Retry and reprocessing shall preserve transactional integrity
    procedure RetryEntry(var InboundEntry: Record "IP Filler Inbound Entry"): Boolean
    begin
        if InboundEntry.Status = InboundEntry.Status::Processed then
            Error(AlreadyProcessedErr, InboundEntry."Entry No.");
        InboundEntry."Retry Count" += 1;
        InboundEntry.Status := InboundEntry.Status::Received;
        InboundEntry.Modify();
        LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Payload Retry", "IP Integration Status"::Success, StrSubstNo(RetryTxt, InboundEntry."Retry Count"), '');
        exit(ProcessEntry(InboundEntry));
    end;

    /// <summary>
    /// Processes an entry from the UI and shows the result to the user.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
    procedure ProcessEntryWithMessage(var InboundEntry: Record "IP Filler Inbound Entry"; IsRetry: Boolean)
    var
        Success: Boolean;
    begin
        if IsRetry then
            Success := RetryEntry(InboundEntry)
        else
            Success := ProcessEntry(InboundEntry);
        if Success then
            Message(ProcessedMsg, InboundEntry."Entry No.")
        else
            Message(ExceptionMsg, InboundEntry."Entry No.", InboundEntry."Error Message");
    end;

    /// <summary>
    /// Processes all newly received inbound entries in arrival order. Called by the job queue.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
    procedure ProcessReceivedEntries()
    var
        InboundEntry: Record "IP Filler Inbound Entry";
        EntryNos: List of [Integer];
        EntryNo: Integer;
    begin
        InboundEntry.SetCurrentKey(Status);
        InboundEntry.SetRange(Status, InboundEntry.Status::Received);
        if InboundEntry.FindSet() then
            repeat
                EntryNos.Add(InboundEntry."Entry No.");
            until InboundEntry.Next() = 0;

        // Entries are processed from a snapshot because processing changes Status and commits.
        foreach EntryNo in EntryNos do
            if InboundEntry.Get(EntryNo) then
                ProcessEntry(InboundEntry);
    end;

    /// <summary>
    /// Payload Receipt: logs every inbound completion payload in the Activity Log as soon as the
    /// middleware inserts it (after insert, so the Entry No. is known).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Payload Receipt - The payload receipt is logged)
    [EventSubscriber(ObjectType::Table, Database::"IP Filler Inbound Entry", 'OnAfterInsertEvent', '', false, false)]
    local procedure InboundEntryOnAfterInsert(var Rec: Record "IP Filler Inbound Entry")
    begin
        if Rec.IsTemporary() then
            exit;
        LogMgt.LogInboundReceipt(Rec);
    end;

    /// <summary>
    /// Records a failure: the entry becomes Exception, the detailed error is written to the
    /// Activity Log, and the AO Filler Status becomes Exception.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 (Validations and Exception Handling) / 5.9 / 5.12 Integration Status is updated to Exception
    local procedure SetException(var InboundEntry: Record "IP Filler Inbound Entry"; EventType: Enum "IP Integration Event Type"; ErrorText: Text): Boolean
    begin
        Context.ResetContext();
        InboundEntry.Get(InboundEntry."Entry No.");
        InboundEntry.Status := InboundEntry.Status::Exception;
        InboundEntry."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(InboundEntry."Error Message"));
        InboundEntry.Modify();
        LogMgt.LogInbound(InboundEntry, EventType, "IP Integration Status"::Exception, '', ErrorText);
        LogMgt.UpdateFillerStatus(InboundEntry."Assembly Order No.", "IP Filler Status"::Exception);
        Commit();
        exit(false);
    end;
}
