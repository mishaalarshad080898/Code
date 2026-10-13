/// <summary>
/// ICR scrap integration. Loads scrap received from the filler into the predefined Item Journal
/// Batch (ICR SCRAP) as negative adjustments at the filler location. Lines are posted
/// automatically when Auto Post Scrap is on in Filler Integration Setup, or left in the batch
/// for user review when it is off.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.13 Scrap Handling / 4.3 Quantity & Document Control Assumptions (2)
codeunit 50113 "IP Scrap Posting"
{
    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        BatchNotEmptyErr: Label 'Item Journal Batch %1 %2 has lines that do not belong to this inbound entry. Post or delete them before scrap can be auto-posted.', Comment = '%1 = Template, %2 = Batch';
        ScrapPostedTxt: Label '%1 scrap line(s) posted from Item Journal Batch %2.', Comment = '%1 = Number of lines, %2 = Batch name';
        ScrapStagedTxt: Label '%1 scrap line(s) created in Item Journal Batch %2 for user review.', Comment = '%1 = Number of lines, %2 = Batch name';
        ScrapLineDescTxt: Label 'ICR scrap - %1', Comment = '%1 = Message ID';

    /// <summary>
    /// Creates (and, if set up, posts) the scrap Item Journal lines for an inbound entry.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.13 Scrap Handling (ICR Scrap Integration - Loaded into predefined Item Journal Batch and auto-posted)
    procedure PostScrap(InboundEntry: Record "IP Filler Inbound Entry")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        ScrapLine: Record "IP Filler Inbound Scrap Line";
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        ExternalDocumentNo: Code[35];
        LineCount: Integer;
    begin
        ScrapLine.SetRange("Inbound Entry No.", InboundEntry."Entry No.");
        if ScrapLine.IsEmpty() then
            exit;

        FillerSetup.Get(InboundEntry."Vendor No.");
        FillerSetup.TestField("Scrap Jnl. Template Name");
        FillerSetup.TestField("Scrap Jnl. Batch Name");
        ExternalDocumentNo := CopyStr(InboundEntry."Message ID", 1, MaxStrLen(ExternalDocumentNo));

        DeleteLinesFromPreviousAttempt(FillerSetup, ExternalDocumentNo);
        if FillerSetup."Auto Post Scrap" then
            CheckBatchIsEmpty(FillerSetup);

        ScrapLine.FindSet();
        repeat
            CreateJournalLine(FillerSetup, InboundEntry, ScrapLine, ExternalDocumentNo);
            LineCount += 1;
        until ScrapLine.Next() = 0;

        if FillerSetup."Auto Post Scrap" then begin
            ItemJournalLine.SetRange("Journal Template Name", FillerSetup."Scrap Jnl. Template Name");
            ItemJournalLine.SetRange("Journal Batch Name", FillerSetup."Scrap Jnl. Batch Name");
            ItemJournalLine.FindFirst();
            ItemJnlPostBatch.Run(ItemJournalLine);
            LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Scrap Posting", "IP Integration Status"::Success,
                StrSubstNo(ScrapPostedTxt, LineCount, FillerSetup."Scrap Jnl. Batch Name"), '');
        end else
            LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Scrap Posting", "IP Integration Status"::Pending,
                StrSubstNo(ScrapStagedTxt, LineCount, FillerSetup."Scrap Jnl. Batch Name"), '');
    end;

    /// <summary>
    /// Creates one negative-adjustment Item Journal line for a scrap line. A physical component
    /// lot sent by the filler is assigned to it.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.13 Scrap Handling (Create Item Journal lines / Use ICR SCRAP journal batch / Preserve audit visibility)
    local procedure CreateJournalLine(FillerSetup: Record "IP Filler Integration Setup"; InboundEntry: Record "IP Filler Inbound Entry"; ScrapLine: Record "IP Filler Inbound Scrap Line"; ExternalDocumentNo: Code[35])
    var
        ItemJournalLine: Record "Item Journal Line";
        LastItemJournalLine: Record "Item Journal Line";
        LineNo: Integer;
    begin
        LastItemJournalLine.SetRange("Journal Template Name", FillerSetup."Scrap Jnl. Template Name");
        LastItemJournalLine.SetRange("Journal Batch Name", FillerSetup."Scrap Jnl. Batch Name");
        if LastItemJournalLine.FindLast() then
            LineNo := LastItemJournalLine."Line No.";
        LineNo += 10000;

        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := FillerSetup."Scrap Jnl. Template Name";
        ItemJournalLine."Journal Batch Name" := FillerSetup."Scrap Jnl. Batch Name";
        ItemJournalLine.SetUpNewLine(LastItemJournalLine);
        ItemJournalLine."Line No." := LineNo;
        ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::"Negative Adjmt.");
        if InboundEntry."Posting Date" <> 0D then
            ItemJournalLine.Validate("Posting Date", InboundEntry."Posting Date");
        ItemJournalLine.Validate("Item No.", ScrapLine."Item No.");
        ItemJournalLine.Validate("Location Code", FillerSetup."Filler Location Code");
        if ScrapLine."Unit of Measure Code" <> '' then
            ItemJournalLine.Validate("Unit of Measure Code", ScrapLine."Unit of Measure Code");
        ItemJournalLine.Validate(Quantity, ScrapLine.Quantity);
        if ScrapLine."Reason Code" <> '' then
            ItemJournalLine.Validate("Reason Code", ScrapLine."Reason Code");
        ItemJournalLine."External Document No." := ExternalDocumentNo;
        if ScrapLine.Description <> '' then
            ItemJournalLine.Description := ScrapLine.Description
        else
            ItemJournalLine.Description := CopyStr(StrSubstNo(ScrapLineDescTxt, InboundEntry."Message ID"), 1, MaxStrLen(ItemJournalLine.Description));
        ItemJournalLine.Insert(true);

        if ScrapLine."Lot No." <> '' then
            AssignLot(ItemJournalLine, ScrapLine."Lot No.");
    end;

    /// <summary>
    /// Assigns the physical component lot sent by the filler to the scrap journal line.
    /// Component lot tracking is not converted to the phantom lot.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 (3) Component consumption remains subject to its existing physical lot-tracking requirements
    local procedure AssignLot(ItemJournalLine: Record "Item Journal Line"; LotNo: Code[50])
    var
        ForReservationEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
    begin
        ForReservationEntry."Lot No." := LotNo;
        CreateReservEntry.CreateReservEntryFor(
            Database::"Item Journal Line", ItemJournalLine."Entry Type".AsInteger(), ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", 0,
            ItemJournalLine."Line No.", ItemJournalLine."Qty. per Unit of Measure", ItemJournalLine.Quantity, ItemJournalLine."Quantity (Base)",
            ForReservationEntry);
        CreateReservEntry.CreateEntry(
            ItemJournalLine."Item No.", ItemJournalLine."Variant Code", ItemJournalLine."Location Code", ItemJournalLine.Description,
            0D, ItemJournalLine."Posting Date", 0, "Reservation Status"::Prospect);
    end;

    /// <summary>
    /// Deletes unposted scrap lines left by an earlier failed attempt for the same payload, so
    /// a retry does not duplicate scrap.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (2) preventing unintended duplicate transaction posting
    local procedure DeleteLinesFromPreviousAttempt(FillerSetup: Record "IP Filler Integration Setup"; ExternalDocumentNo: Code[35])
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.SetRange("Journal Template Name", FillerSetup."Scrap Jnl. Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", FillerSetup."Scrap Jnl. Batch Name");
        ItemJournalLine.SetRange("External Document No.", ExternalDocumentNo);
        ItemJournalLine.DeleteAll(true);
    end;

    /// <summary>
    /// Auto-posting posts the whole batch, so the batch must not hold unrelated lines.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.13 Scrap Handling
    local procedure CheckBatchIsEmpty(FillerSetup: Record "IP Filler Integration Setup")
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.SetRange("Journal Template Name", FillerSetup."Scrap Jnl. Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", FillerSetup."Scrap Jnl. Batch Name");
        if not ItemJournalLine.IsEmpty() then
            Error(BatchNotEmptyErr, FillerSetup."Scrap Jnl. Template Name", FillerSetup."Scrap Jnl. Batch Name");
    end;
}
