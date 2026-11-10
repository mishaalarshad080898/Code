/// <summary>
/// Posts the BC receipt for a validated Goods Receipt (030) movement from the integrated filler:
/// a Purchase Order receipt (raw materials bought from a supplier and delivered to the filler) or
/// a Transfer Order receipt (raw materials moved to the filler). Only the quantities in the
/// payload are received. Raw-material lot tracking stays standard: the physical lot reported by
/// the filler is used where the item requires it.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing
codeunit 50420 "IP Raw Material Receipt"
{
    var
        MovementLogMgt: Codeunit "IP ICR Movement Log Mgt";
        LotMgt: Codeunit "IP Transfer Phantom Lot Mgt";
        PurchaseReceiptPostedTxt: Label 'Purchase receipt %1 posted for Purchase Order %2 from ICR movement %3.', Comment = '%1 = Receipt No., %2 = PO No., %3 = Entry No.';
        TransferReceiptPostedTxt: Label 'Transfer receipt %1 posted for Transfer Order %2 from ICR movement %3.', Comment = '%1 = Receipt No., %2 = TO No., %3 = Entry No.';
        LineReceivedTxt: Label '%1 %2 of item %3 received on line %4.', Comment = '%1 = Quantity, %2 = UoM, %3 = Item No., %4 = Line No.';

    /// <summary>
    /// Purchase Order receipt: sets Qty. to Receive from the payload (all other lines 0), assigns the
    /// physical raw-material lot where the item is lot tracked, and posts the receipt (Receive only,
    /// no invoice) with the ICR posting date and BOL. The movement is marked Processed in the same
    /// transaction as the posting, so a committed receipt is never posted twice.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Purchase Order receipt / Processes receipt)
    procedure PostPurchaseReceipt(var MovementHeader: Record "IP ICR Movement Header")
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        MovementLine: Record "IP ICR Movement Line";
        ReleasePurchaseDocument: Codeunit "Release Purchase Document";
        PurchPost: Codeunit "Purch.-Post";
    begin
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, MovementHeader."Source Document No.");
        // Reopen so the posting date can be changed; posting releases the PO again (outbound is suppressed).
        if PurchaseHeader.Status <> PurchaseHeader.Status::Open then
            ReleasePurchaseDocument.Reopen(PurchaseHeader);

        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetFilter("Qty. to Receive", '<>0');
        if PurchaseLine.FindSet(true) then
            repeat
                PurchaseLine.Validate("Qty. to Receive", 0);
                PurchaseLine.Modify(true);
            until PurchaseLine.Next() = 0;

        MovementLine.SetRange("Entry No.", MovementHeader."Entry No.");
        MovementLine.FindSet();
        repeat
            PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", MovementLine."PO Item");
            PurchaseLine.Validate("Qty. to Receive", PurchaseLine."Qty. to Receive" + MovementLine.Quantity);
            PurchaseLine.Modify(true);
            AssignPurchaseLot(PurchaseLine, MovementLine);
        until MovementLine.Next() = 0;

        PurchaseHeader.Get(PurchaseHeader."Document Type", PurchaseHeader."No.");
        PurchaseHeader.SetHideValidationDialog(true);
        PurchaseHeader.Validate("Posting Date", MovementHeader."Posting Date");
        PurchaseHeader."Vendor Shipment No." := CopyStr(GetShipmentReference(MovementHeader), 1, MaxStrLen(PurchaseHeader."Vendor Shipment No."));
        PurchaseHeader.Receive := true;
        PurchaseHeader.Invoice := false;
        PurchaseHeader.Modify(true);

        MarkProcessed(MovementHeader);
        PurchPost.Run(PurchaseHeader);

        MovementHeader.Get(MovementHeader."Entry No.");
        MovementHeader."Posted Document No." := PurchaseHeader."Last Receiving No.";
        MovementHeader.Modify();
        LogPostedLines(MovementHeader, "IP Integration Event Type"::"PO Receipt");
        MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"PO Receipt", "IP Integration Status"::Success,
            StrSubstNo(PurchaseReceiptPostedTxt, MovementHeader."Posted Document No.", PurchaseHeader."No.", MovementHeader."Entry No."), '');
    end;

    /// <summary>
    /// Transfer Order receipt: sets Qty. to Receive from the payload (all other lines 0), aligns the
    /// receipt item tracking created at shipment with the quantity received, and posts the
    /// Transfer Receipt into the filler location.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Transfer Order receipt / Processes receipt)
    procedure PostTransferReceipt(var MovementHeader: Record "IP ICR Movement Header")
    var
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        MovementLine: Record "IP ICR Movement Line";
        TransferPostReceipt: Codeunit "TransferOrder-Post Receipt";
    begin
        TransferHeader.Get(MovementHeader."Source Document No.");

        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        TransferLine.SetFilter("Qty. to Receive", '<>0');
        if TransferLine.FindSet(true) then
            repeat
                TransferLine.Validate("Qty. to Receive", 0);
                TransferLine.Modify(true);
            until TransferLine.Next() = 0;

        MovementLine.SetRange("Entry No.", MovementHeader."Entry No.");
        MovementLine.FindSet();
        repeat
            TransferLine.Get(TransferHeader."No.", MovementLine."PO Item");
            TransferLine.Validate("Qty. to Receive", TransferLine."Qty. to Receive" + MovementLine.Quantity);
            TransferLine.Modify(true);
        until MovementLine.Next() = 0;

        TransferLine.SetRange("Qty. to Receive");
        TransferLine.SetFilter("Qty. to Receive (Base)", '>0');
        if TransferLine.FindSet() then
            repeat
                LotMgt.SetInboundTransferQtyToHandle(TransferLine, GetPhysicalLot(MovementHeader, TransferLine."Line No."));
            until TransferLine.Next() = 0;

        TransferHeader.Get(TransferHeader."No.");
        TransferHeader."Posting Date" := MovementHeader."Posting Date";
        TransferHeader.Modify(true);

        MarkProcessed(MovementHeader);
        TransferPostReceipt.SetHideValidationDialog(true);
        TransferPostReceipt.Run(TransferHeader);

        MovementHeader.Get(MovementHeader."Entry No.");
        MovementHeader."Posted Document No." := TransferHeader."Last Receipt No.";
        MovementHeader.Modify();
        LogPostedLines(MovementHeader, "IP Integration Event Type"::"Transfer Receipt");
        MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"Transfer Receipt", "IP Integration Status"::Success,
            StrSubstNo(TransferReceiptPostedTxt, MovementHeader."Posted Document No.", TransferHeader."No.", MovementHeader."Entry No."), '');
    end;

    /// <summary>
    /// Raw-material lot tracking stays unchanged: when the item is lot tracked and the filler reports
    /// the physical lot, that lot is assigned to the received quantity of the PO line. Phantom Lot
    /// (ADO 1507) never applies to raw materials and components.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.2 Core Behavior (Raw-material and component lot tracking remains unchanged)
    local procedure AssignPurchaseLot(PurchaseLine: Record "Purchase Line"; MovementLine: Record "IP ICR Movement Line")
    var
        ForReservationEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        QtyBase: Decimal;
    begin
        if MovementLine."Physical Lot No." = '' then
            exit;
        if not LotMgt.IsLotTracked(PurchaseLine."No.") then
            exit;
        QtyBase := Round(MovementLine.Quantity * PurchaseLine."Qty. per Unit of Measure", 0.00001);
        ForReservationEntry."Lot No." := MovementLine."Physical Lot No.";
        CreateReservEntry.CreateReservEntryFor(
            Database::"Purchase Line", PurchaseLine."Document Type".AsInteger(), PurchaseLine."Document No.", '', 0, PurchaseLine."Line No.",
            PurchaseLine."Qty. per Unit of Measure", MovementLine.Quantity, QtyBase, ForReservationEntry);
        CreateReservEntry.CreateEntry(
            PurchaseLine."No.", PurchaseLine."Variant Code", PurchaseLine."Location Code", PurchaseLine.Description,
            PurchaseLine."Expected Receipt Date", 0D, 0, "Reservation Status"::Surplus);
    end;

    /// <summary>
    /// Marks the movement Processed before the posting runs. Standard posting commits, so the
    /// status and the receipt are committed together; a failed posting rolls both back.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 5.2 Integration Assumptions (2) Duplicate transaction prevention is required
    local procedure MarkProcessed(var MovementHeader: Record "IP ICR Movement Header")
    begin
        MovementHeader.Status := MovementHeader.Status::Processed;
        MovementHeader."Processed At" := CurrentDateTime();
        MovementHeader."Error Message" := '';
        MovementHeader.Modify();
    end;

    /// <summary>
    /// Logs one Activity Log entry per received payload line (quantity, item and price).
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Updates Activity Log)
    local procedure LogPostedLines(MovementHeader: Record "IP ICR Movement Header"; EventType: Enum "IP Integration Event Type")
    var
        MovementLine: Record "IP ICR Movement Line";
    begin
        MovementLine.SetRange("Entry No.", MovementHeader."Entry No.");
        if MovementLine.FindSet() then
            repeat
                MovementLogMgt.LogMovementLine(MovementHeader, MovementLine, EventType, "IP Integration Status"::Success,
                    StrSubstNo(LineReceivedTxt, MovementLine.Quantity, MovementLine."Unit of Measure Code", MovementLine."Item No.", MovementLine."PO Item"), '');
            until MovementLine.Next() = 0;
    end;

    /// <summary>
    /// Returns the physical lot reported for a BC line, if any.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.2 Core Behavior (physical lot where required)
    local procedure GetPhysicalLot(MovementHeader: Record "IP ICR Movement Header"; LineNo: Integer): Code[50]
    var
        MovementLine: Record "IP ICR Movement Line";
    begin
        MovementLine.SetRange("Entry No.", MovementHeader."Entry No.");
        MovementLine.SetRange("PO Item", LineNo);
        MovementLine.SetFilter("Physical Lot No.", '<>%1', '');
        if MovementLine.FindFirst() then
            exit(MovementLine."Physical Lot No.");
        exit('');
    end;

    /// <summary>
    /// Shipment reference stored on the posted receipt: the BOL (D_NUMBER), else the ICR document
    /// number (HDTEXT).
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing
    local procedure GetShipmentReference(MovementHeader: Record "IP ICR Movement Header"): Text
    begin
        if MovementHeader."BOL No." <> '' then
            exit(MovementHeader."BOL No.");
        exit(MovementHeader."ICR Document No.");
    end;
}
