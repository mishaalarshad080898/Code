/// <summary>
/// Positive (100) and negative (101) inventory adjustments reported by ICR. Each posd line becomes
/// one Item Journal line (Positive Adjmt. / Negative Adjmt.) in the adjustment journal batch set up
/// in Filler Integration Setup, at the BC location given by LGORT. Lot-tracked items always use the
/// phantom lot (XXXX); other items get no lot. Positive adjustments take their unit cost from the
/// payload price. The lines are posted automatically, or left in the batch for user review when
/// Auto Post Adjustments is off.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - Positive & negative adjustments (MVT_TYPE 100 / 101)
codeunit 50425 "IP ICR Adjustment Posting"
{
    var
        Validation: Codeunit "IP ICR Movement Validation";
        PhantomLotMgt: Codeunit "IP Phantom Lot Mgt";
        TransferLotMgt: Codeunit "IP Transfer Phantom Lot Mgt";
        MovementLogMgt: Codeunit "IP ICR Movement Log Mgt";
        BatchNotEmptyErr: Label 'Item Journal Batch %1 %2 has lines that do not belong to ICR inbound entry %3. Post or delete them before the adjustment can be auto-posted.', Comment = '%1 = Template, %2 = Batch, %3 = Entry No.';
        LotNotAvailableErr: Label 'Only %1 of item %2 is available under lot %3 at location %4, but %5 must be removed by the negative adjustment.', Comment = '%1 = Available qty, %2 = Item No., %3 = Lot No., %4 = Location, %5 = Qty';
        LineDescTxt: Label 'ICR adjustment %1', Comment = '%1 = HDTEXT';
        PostedTxt: Label '%1 adjustment line(s) posted from Item Journal Batch %2 (document %3).', Comment = '%1 = Number of lines, %2 = Batch name, %3 = Document No.';
        StagedTxt: Label '%1 adjustment line(s) created in Item Journal Batch %2 (document %3) for user review.', Comment = '%1 = Number of lines, %2 = Batch name, %3 = Document No.';
        LineTxt: Label '%1 %2 %3 of item %4 at location %5, lot %6.', Comment = '%1 = Entry type, %2 = Qty, %3 = UoM, %4 = Item No., %5 = Location, %6 = Lot No.';
        DocumentNoTok: Label 'ICR-%1', Locked = true, Comment = '%1 = Entry No.';

    /// <summary>
    /// Creates one adjustment Item Journal line per payload line and posts the batch when Auto Post
    /// Adjustments is on. The entry is marked Processed before posting, so status and posting are
    /// committed together and a posted adjustment is never posted twice.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - Positive & negative adjustments (create Item Journal with positive or negative adjustment)
    procedure PostAdjustment(var MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        MovementLine: Record "IP ICR Inbound Entry Lines";
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        DocumentNo: Code[20];
        LineCount: Integer;
    begin
        Validation.ResolveAdjustmentSetup(MovementHeader, FillerSetup);
        Validation.ValidateAdjustmentLines(MovementHeader);
        if FillerSetup."Auto Post Adjustments" then
            CheckBatchIsEmpty(FillerSetup, MovementHeader);

        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        MovementLine.FindSet();
        repeat
            CreateJournalLine(FillerSetup, MovementHeader, MovementLine, DocumentNo);
            LineCount += 1;
        until MovementLine.Next() = 0;

        MovementHeader."Source Document Type" := MovementHeader."Source Document Type"::"Item Journal";
        MovementHeader."Source Document No." := DocumentNo;
        MovementHeader.Status := MovementHeader.Status::Processed;
        MovementHeader."Processed At" := CurrentDateTime();
        MovementHeader."Error Message" := '';
        MovementHeader.Modify();

        if not FillerSetup."Auto Post Adjustments" then begin
            MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"Inventory Adjustment", "IP Integration Status"::Pending,
                StrSubstNo(StagedTxt, LineCount, FillerSetup."Adj. Jnl. Batch Name", DocumentNo), '');
            exit;
        end;

        ItemJournalLine.SetRange("Journal Template Name", FillerSetup."Adj. Jnl. Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", FillerSetup."Adj. Jnl. Batch Name");
        ItemJournalLine.FindFirst();
        ItemJnlPostBatch.Run(ItemJournalLine);

        MovementHeader.Get(MovementHeader."Entry No.");
        MovementHeader."Posted Document No." := DocumentNo;
        MovementHeader.Modify();
        MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"Inventory Adjustment", "IP Integration Status"::Success,
            StrSubstNo(PostedTxt, LineCount, FillerSetup."Adj. Jnl. Batch Name", DocumentNo), '');
    end;

    /// <summary>
    /// Creates one Item Journal line: entry type from MVT_TYPE (100 = Positive Adjmt., 101 = Negative
    /// Adjmt.), item MATNR, location LGORT, quantity MENGE in MEINS, unit cost from the payload price
    /// (positive adjustments only), no reason code. The document no. comes from the batch's No. Series,
    /// or ICR-(entry no.) when the batch has none.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - Positive & negative adjustments (Location: LGORT / Cost: NETPR / Reason code: not filled)
    local procedure CreateJournalLine(FillerSetup: Record "IP Filler Integration Setup"; MovementHeader: Record "IP ICR Inbound Entry Header"; MovementLine: Record "IP ICR Inbound Entry Lines"; var DocumentNo: Code[20])
    var
        ItemJournalLine: Record "Item Journal Line";
        LastItemJournalLine: Record "Item Journal Line";
        LineNo: Integer;
    begin
        LastItemJournalLine.SetRange("Journal Template Name", FillerSetup."Adj. Jnl. Template Name");
        LastItemJournalLine.SetRange("Journal Batch Name", FillerSetup."Adj. Jnl. Batch Name");
        if LastItemJournalLine.FindLast() then
            LineNo := LastItemJournalLine."Line No.";
        LineNo += 10000;

        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := FillerSetup."Adj. Jnl. Template Name";
        ItemJournalLine."Journal Batch Name" := FillerSetup."Adj. Jnl. Batch Name";
        ItemJournalLine.SetUpNewLine(LastItemJournalLine);
        ItemJournalLine."Line No." := LineNo;
        // All lines of one ICR entry share one document no.
        if DocumentNo = '' then begin
            DocumentNo := ItemJournalLine."Document No.";
            if DocumentNo = '' then
                DocumentNo := CopyStr(StrSubstNo(DocumentNoTok, MovementHeader."Entry No."), 1, MaxStrLen(DocumentNo));
        end;
        ItemJournalLine."Document No." := DocumentNo;
        if MovementHeader."Movement Type" = MovementHeader."Movement Type"::"Positive Adjustment" then
            ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::"Positive Adjmt.")
        else
            ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::"Negative Adjmt.");
        ItemJournalLine.Validate("Posting Date", MovementHeader."Posting Date");
        ItemJournalLine.Validate("Document Date", MovementHeader."Document Date");
        ItemJournalLine.Validate("Item No.", MovementLine."Item No.");
        ItemJournalLine.Validate("Location Code", MovementLine."Location Code");
        if MovementLine."Unit of Measure" <> '' then
            ItemJournalLine.Validate("Unit of Measure Code", MovementLine."Unit of Measure");
        ItemJournalLine.Validate(Quantity, MovementLine.Qty);
        // Cost from the payload for positive adjustments; a negative adjustment takes the cost of the inventory it removes.
        if ItemJournalLine."Entry Type" = ItemJournalLine."Entry Type"::"Positive Adjmt." then
            ItemJournalLine.Validate("Unit Amount", MovementLine.GetUnitPrice());
        ItemJournalLine."External Document No." := CopyStr(MovementHeader."HD Text", 1, MaxStrLen(ItemJournalLine."External Document No."));
        ItemJournalLine.Description := CopyStr(StrSubstNo(LineDescTxt, MovementHeader."HD Text"), 1, MaxStrLen(ItemJournalLine.Description));
        ItemJournalLine.Insert(true);

        AssignPhantomLot(ItemJournalLine, MovementHeader, MovementLine);
    end;

    /// <summary>
    /// Lots: when the item is lot tracked, the adjustment always uses the phantom lot (XXXX from
    /// Company Information); otherwise no lot is assigned. For a negative adjustment, enough
    /// inventory must exist under the phantom lot at the location.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - Positive & negative adjustments (Lots: always phantom lot XXXX when the item is lot tracked)
    local procedure AssignPhantomLot(ItemJournalLine: Record "Item Journal Line"; MovementHeader: Record "IP ICR Inbound Entry Header"; MovementLine: Record "IP ICR Inbound Entry Lines")
    var
        ForReservationEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        LotNo: Code[50];
    begin
        if not TransferLotMgt.IsLotTracked(ItemJournalLine."Item No.") then begin
            LogLine(MovementHeader, MovementLine, ItemJournalLine, '');
            exit;
        end;
        LotNo := PhantomLotMgt.GetPhantomLotNo();
        if ItemJournalLine."Entry Type" = ItemJournalLine."Entry Type"::"Negative Adjmt." then
            CheckLotAvailability(ItemJournalLine, LotNo)
        else
            EnsureLotNoInformation(ItemJournalLine, LotNo);

        ForReservationEntry."Lot No." := LotNo;
        CreateReservEntry.CreateReservEntryFor(
            Database::"Item Journal Line", ItemJournalLine."Entry Type".AsInteger(), ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", 0,
            ItemJournalLine."Line No.", ItemJournalLine."Qty. per Unit of Measure", ItemJournalLine.Quantity, ItemJournalLine."Quantity (Base)",
            ForReservationEntry);
        CreateReservEntry.CreateEntry(
            ItemJournalLine."Item No.", ItemJournalLine."Variant Code", ItemJournalLine."Location Code", ItemJournalLine.Description,
            0D, ItemJournalLine."Posting Date", 0, "Reservation Status"::Prospect);
        LogLine(MovementHeader, MovementLine, ItemJournalLine, LotNo);
    end;

    /// <summary>
    /// A negative adjustment can only remove inventory that exists under the lot at the location.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - Positive & negative adjustments (negative adjustment of phantom lot inventory)
    local procedure CheckLotAvailability(ItemJournalLine: Record "Item Journal Line"; LotNo: Code[50])
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", ItemJournalLine."Item No.");
        ItemLedgerEntry.SetRange("Variant Code", ItemJournalLine."Variant Code");
        ItemLedgerEntry.SetRange("Location Code", ItemJournalLine."Location Code");
        ItemLedgerEntry.SetRange("Lot No.", LotNo);
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.CalcSums("Remaining Quantity");
        if ItemLedgerEntry."Remaining Quantity" < ItemJournalLine."Quantity (Base)" then
            Error(LotNotAvailableErr, ItemLedgerEntry."Remaining Quantity", ItemJournalLine."Item No.", LotNo, ItemJournalLine."Location Code", ItemJournalLine."Quantity (Base)");
    end;

    /// <summary>
    /// Creates the Lot No. Information card for the phantom lot if it is missing, so items that
    /// require lot information on inbound posting still post.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - Positive & negative adjustments (Lots)
    local procedure EnsureLotNoInformation(ItemJournalLine: Record "Item Journal Line"; LotNo: Code[50])
    var
        LotNoInformation: Record "Lot No. Information";
    begin
        if LotNoInformation.Get(ItemJournalLine."Item No.", ItemJournalLine."Variant Code", LotNo) then
            exit;
        LotNoInformation.Init();
        LotNoInformation."Item No." := ItemJournalLine."Item No.";
        LotNoInformation."Variant Code" := ItemJournalLine."Variant Code";
        LotNoInformation."Lot No." := LotNo;
        LotNoInformation.Insert(true);
    end;

    /// <summary>
    /// Auto-posting posts the whole batch, so the batch must not hold lines of anything else.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - Positive & negative adjustments (Journal: parametrized in Filler Integration Setup)
    local procedure CheckBatchIsEmpty(FillerSetup: Record "IP Filler Integration Setup"; MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        ItemJournalLine: Record "Item Journal Line";
    begin
        ItemJournalLine.SetRange("Journal Template Name", FillerSetup."Adj. Jnl. Template Name");
        ItemJournalLine.SetRange("Journal Batch Name", FillerSetup."Adj. Jnl. Batch Name");
        if not ItemJournalLine.IsEmpty() then
            Error(BatchNotEmptyErr, FillerSetup."Adj. Jnl. Template Name", FillerSetup."Adj. Jnl. Batch Name", MovementHeader."Entry No.");
    end;

    /// <summary>
    /// Logs one Activity Log entry per adjustment line (entry type, quantity, location and lot).
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility
    local procedure LogLine(MovementHeader: Record "IP ICR Inbound Entry Header"; MovementLine: Record "IP ICR Inbound Entry Lines"; ItemJournalLine: Record "Item Journal Line"; LotNo: Code[50])
    begin
        MovementLogMgt.LogMovementLine(MovementHeader, MovementLine, "IP Integration Event Type"::"Inventory Adjustment", "IP Integration Status"::Success,
            StrSubstNo(LineTxt, ItemJournalLine."Entry Type", MovementLine.Qty, MovementLine."Unit of Measure", MovementLine."Item No.", MovementLine."Location Code", LotNo), '');
    end;
}
