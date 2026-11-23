/// <summary>
/// Finished goods shipment from the integrated filler to the 3PL (movement 311). BC uses an
/// existing Transfer Order that matches the payload (transfer-from location, items and quantities)
/// or creates a new one, assigns the shipment item tracking (phantom lot XXXX for covered finished
/// goods), posts the Transfer Shipment and hands the receipt over to the existing Difarco
/// integration, which stays unchanged.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing
codeunit 50421 "IP FG Shipment Processing"
{
    var
        Validation: Codeunit "IP ICR Movement Validation";
        TransferLotMgt: Codeunit "IP Transfer Phantom Lot Mgt";
        MovementLogMgt: Codeunit "IP ICR Movement Log Mgt";
        ExistingTOTxt: Label 'Existing Transfer Order %1 matches the shipment (from %2, items and quantities) and is used.', Comment = '%1 = TO No., %2 = Location';
        CreatedTOTxt: Label 'No matching Transfer Order found. Transfer Order %1 created from %2 to %3.', Comment = '%1 = TO No., %2 = From location, %3 = To location';
        NotAllocatedErr: Label '%1 of item %2 could not be allocated to a line of Transfer Order %3.', Comment = '%1 = Qty, %2 = Item No., %3 = TO No.';
        ShipmentPostedTxt: Label 'Transfer Shipment %1 posted for Transfer Order %2. Finished goods are in transit to %3.', Comment = '%1 = Shipment No., %2 = TO No., %3 = Location';
        DifarcoHandoffTxt: Label 'Transfer Order %1 handed off to the existing Difarco integration for receipt at %2.', Comment = '%1 = TO No., %2 = Location';
        LineShippedTxt: Label '%1 %2 of item %3 shipped.', Comment = '%1 = Qty, %2 = UoM, %3 = Item No.';

    /// <summary>
    /// Runs the finished goods shipment steps: receive and validate the payload, find or create the
    /// Transfer Order, set Qty. to Ship, assign item tracking, post the Transfer Shipment, log and
    /// hand off to Difarco.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Business Central Behavior)
    procedure ProcessShipment(var MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        TransferHeader: Record "Transfer Header";
        TransferPostShipment: Codeunit "TransferOrder-Post Shipment";
    begin
        Validation.ResolveFillerSetup(MovementHeader, FillerSetup);

        if FindMatchingTransferOrder(MovementHeader, FillerSetup, TransferHeader) then begin
            SetSourceDocument(MovementHeader, TransferHeader."No.", false);
            MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"FG Transfer Order", "IP Integration Status"::Success,
                StrSubstNo(ExistingTOTxt, TransferHeader."No.", TransferHeader."Transfer-from Code"), '');
        end else begin
            CreateTransferOrder(MovementHeader, FillerSetup, TransferHeader);
            SetSourceDocument(MovementHeader, TransferHeader."No.", true);
            MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"FG Transfer Order", "IP Integration Status"::Success,
                StrSubstNo(CreatedTOTxt, TransferHeader."No.", TransferHeader."Transfer-from Code", TransferHeader."Transfer-to Code"), '');
        end;

        SetQuantityToShip(MovementHeader, TransferHeader);
        AssignTracking(MovementHeader, TransferHeader);

        TransferHeader.Get(TransferHeader."No.");
        TransferHeader."Posting Date" := MovementHeader."Posting Date";
        if TransferHeader."External Document No." = '' then
            TransferHeader."External Document No." := CopyStr(MovementHeader."D Number", 1, MaxStrLen(TransferHeader."External Document No."));
        TransferHeader."IP ICR Inbound Entry No." := MovementHeader."Entry No.";
        TransferHeader.Modify(true);

        // Marked Processed before posting: the shipment posting commits status and shipment together.
        MovementHeader.Status := MovementHeader.Status::Processed;
        MovementHeader."Processed At" := CurrentDateTime();
        MovementHeader."Error Message" := '';
        MovementHeader.Modify();

        TransferPostShipment.SetHideValidationDialog(true);
        TransferPostShipment.Run(TransferHeader);

        MovementHeader.Get(MovementHeader."Entry No.");
        MovementHeader."Posted Document No." := TransferHeader."Last Shipment No.";
        MovementHeader.Modify();
        LogShippedLines(MovementHeader);
        MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"FG Transfer Shipment", "IP Integration Status"::Success,
            StrSubstNo(ShipmentPostedTxt, MovementHeader."Posted Document No.", TransferHeader."No.", TransferHeader."Transfer-to Code"), '');
        MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"Difarco Handoff", "IP Integration Status"::Success,
            StrSubstNo(DifarcoHandoffTxt, TransferHeader."No.", TransferHeader."Transfer-to Code"), '');
    end;

    /// <summary>
    /// Looks for an existing Transfer Order from the filler location whose open (not yet shipped)
    /// quantities match the payload exactly: the same items and, per item, the same quantity in the
    /// base unit of measure. Direct transfers are skipped, because they would bypass the Difarco
    /// receipt.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Find existing Transfer Order that matches: Transfer from, Item(s), Quantity)
    local procedure FindMatchingTransferOrder(MovementHeader: Record "IP ICR Inbound Entry Header"; FillerSetup: Record "IP Filler Integration Setup"; var TransferHeader: Record "Transfer Header"): Boolean
    var
        MovementQty: Dictionary of [Code[20], Decimal];
    begin
        GetMovementQuantities(MovementHeader, MovementQty);
        TransferHeader.SetRange("Transfer-from Code", FillerSetup."Filler Location Code");
        TransferHeader.SetRange("Direct Transfer", false);
        if TransferHeader.FindSet() then
            repeat
                if TransferOrderMatches(TransferHeader, MovementQty) then
                    exit(true);
            until TransferHeader.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// Creates a Transfer Order from the filler location to the 3PL location (with the in-transit
    /// location from setup or the transfer route), one line per payload line.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (If Transfer Order not found create new Transfer Order)
    local procedure CreateTransferOrder(MovementHeader: Record "IP ICR Inbound Entry Header"; FillerSetup: Record "IP Filler Integration Setup"; var TransferHeader: Record "Transfer Header")
    var
        MovementLine: Record "IP ICR Inbound Entry Lines";
        TransferLine: Record "Transfer Line";
        LineNo: Integer;
    begin
        TransferHeader.Init();
        TransferHeader."No." := '';
        TransferHeader.Insert(true);
        TransferHeader.Validate("Transfer-from Code", FillerSetup."Filler Location Code");
        TransferHeader.Validate("Transfer-to Code", FillerSetup."FG 3PL Location Code");
        if FillerSetup."FG In-Transit Code" <> '' then
            TransferHeader.Validate("In-Transit Code", FillerSetup."FG In-Transit Code");
        TransferHeader.TestField("In-Transit Code");
        TransferHeader.Validate("Posting Date", MovementHeader."Posting Date");
        TransferHeader.Validate("Shipment Date", MovementHeader."Posting Date");
        TransferHeader."External Document No." := CopyStr(MovementHeader."D Number", 1, MaxStrLen(TransferHeader."External Document No."));
        TransferHeader."IP ICR Inbound Entry No." := MovementHeader."Entry No.";
        TransferHeader."IP Created by ICR Movement" := true;
        TransferHeader.Modify(true);

        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        MovementLine.FindSet();
        repeat
            LineNo += 10000;
            TransferLine.Init();
            TransferLine."Document No." := TransferHeader."No.";
            TransferLine."Line No." := LineNo;
            TransferLine.Validate("Item No.", MovementLine."Item No.");
            if MovementLine."Unit of Measure" <> '' then
                TransferLine.Validate("Unit of Measure Code", MovementLine."Unit of Measure");
            TransferLine.Validate(Quantity, MovementLine.Qty);
            TransferLine."IP Physical Lot No." := MovementLine."Physical Lot No.";
            TransferLine.Insert(true);
        until MovementLine.Next() = 0;
    end;

    /// <summary>
    /// Sets Qty. to Ship on the Transfer Order from the payload. Other lines are set to 0, so only
    /// the shipped quantity is posted; quantities are allocated per item over the open lines.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Posts Transfer Shipment - quantities unchanged by ADO 1507)
    local procedure SetQuantityToShip(MovementHeader: Record "IP ICR Inbound Entry Header"; TransferHeader: Record "Transfer Header")
    var
        MovementLine: Record "IP ICR Inbound Entry Lines";
        TransferLine: Record "Transfer Line";
        RemainingBase: Decimal;
        OpenBase: Decimal;
        TakeBase: Decimal;
    begin
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        TransferLine.SetFilter("Qty. to Ship", '<>0');
        if TransferLine.FindSet(true) then
            repeat
                TransferLine.Validate("Qty. to Ship", 0);
                TransferLine.Modify(true);
            until TransferLine.Next() = 0;
        TransferLine.SetRange("Qty. to Ship");

        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        MovementLine.FindSet();
        repeat
            RemainingBase := Validation.GetQuantityBase(MovementLine);
            TransferLine.SetRange("Item No.", MovementLine."Item No.");
            if TransferLine.FindSet(true) then
                repeat
                    OpenBase := TransferLine."Outstanding Qty. (Base)" - TransferLine."Qty. to Ship (Base)";
                    if OpenBase > 0 then begin
                        TakeBase := OpenBase;
                        if TakeBase > RemainingBase then
                            TakeBase := RemainingBase;
                        TransferLine.Validate("Qty. to Ship", TransferLine."Qty. to Ship" + Round(TakeBase / TransferLine."Qty. per Unit of Measure", 0.00001));
                        if MovementLine."Physical Lot No." <> '' then
                            TransferLine."IP Physical Lot No." := MovementLine."Physical Lot No.";
                        TransferLine.Modify(true);
                        RemainingBase -= TakeBase;
                    end;
                until (TransferLine.Next() = 0) or (RemainingBase <= 0);
            if RemainingBase > 0 then
                Error(NotAllocatedErr, RemainingBase, MovementLine."Item No.", TransferHeader."No.");
        until MovementLine.Next() = 0;
    end;

    /// <summary>
    /// Assigns the shipment item tracking of every line with Qty. to Ship (phantom lot XXXX for
    /// covered finished goods) and logs it with the physical lot for audit visibility.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (ADO 1507 Phantom Lot)
    local procedure AssignTracking(MovementHeader: Record "IP ICR Inbound Entry Header"; TransferHeader: Record "Transfer Header")
    var
        TransferLine: Record "Transfer Line";
        MovementLine: Record "IP ICR Inbound Entry Lines";
        Description: Text;
    begin
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        TransferLine.SetFilter("Qty. to Ship (Base)", '>0');
        if TransferLine.FindSet() then
            repeat
                Description := TransferLotMgt.AssignShipmentTracking(TransferLine, TransferLine."IP Physical Lot No.");
                if Description <> '' then begin
                    MovementLine.Init();
                    MovementLine."Item No." := TransferLine."Item No.";
                    MovementLine.Qty := TransferLine."Qty. to Ship";
                    MovementLine."Physical Lot No." := TransferLine."IP Physical Lot No.";
                    MovementLogMgt.LogMovementLine(MovementHeader, MovementLine, "IP Integration Event Type"::"Phantom Lot Assignment", "IP Integration Status"::Success, Description, '');
                end;
            until TransferLine.Next() = 0;
    end;

    /// <summary>
    /// Builds the payload quantity per item in the base unit of measure.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Item(s), Quantity)
    local procedure GetMovementQuantities(MovementHeader: Record "IP ICR Inbound Entry Header"; var MovementQty: Dictionary of [Code[20], Decimal])
    var
        MovementLine: Record "IP ICR Inbound Entry Lines";
    begin
        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        if MovementLine.FindSet() then
            repeat
                AddQuantity(MovementQty, MovementLine."Item No.", Validation.GetQuantityBase(MovementLine));
            until MovementLine.Next() = 0;
    end;

    /// <summary>
    /// True when the open quantities of the Transfer Order equal the payload: same items and the same
    /// quantity per item.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Find existing Transfer Order that matches)
    local procedure TransferOrderMatches(TransferHeader: Record "Transfer Header"; MovementQty: Dictionary of [Code[20], Decimal]): Boolean
    var
        TransferLine: Record "Transfer Line";
        TransferQty: Dictionary of [Code[20], Decimal];
        ItemNo: Code[20];
    begin
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        TransferLine.SetFilter("Item No.", '<>%1', '');
        TransferLine.SetFilter("Outstanding Qty. (Base)", '>0');
        if not TransferLine.FindSet() then
            exit(false);
        repeat
            AddQuantity(TransferQty, TransferLine."Item No.", TransferLine."Outstanding Qty. (Base)");
        until TransferLine.Next() = 0;

        if TransferQty.Count() <> MovementQty.Count() then
            exit(false);
        foreach ItemNo in MovementQty.Keys() do begin
            if not TransferQty.ContainsKey(ItemNo) then
                exit(false);
            if TransferQty.Get(ItemNo) <> MovementQty.Get(ItemNo) then
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Stores the Transfer Order on the movement as its source document.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Activity is logged)
    local procedure SetSourceDocument(var MovementHeader: Record "IP ICR Inbound Entry Header"; TransferOrderNo: Code[20]; Created: Boolean)
    begin
        MovementHeader."Source Document Type" := MovementHeader."Source Document Type"::"FG Transfer Order";
        MovementHeader."Source Document No." := TransferOrderNo;
        MovementHeader."TO Created" := Created;
        MovementHeader.Modify();
    end;

    /// <summary>
    /// Logs one Activity Log entry per shipped payload line, including the physical filler lot.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Records Activity Log)
    local procedure LogShippedLines(MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        MovementLine: Record "IP ICR Inbound Entry Lines";
    begin
        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        if MovementLine.FindSet() then
            repeat
                MovementLogMgt.LogMovementLine(MovementHeader, MovementLine, "IP Integration Event Type"::"FG Transfer Shipment", "IP Integration Status"::Success,
                    StrSubstNo(LineShippedTxt, MovementLine.Qty, MovementLine."Unit of Measure", MovementLine."Item No."), '');
            until MovementLine.Next() = 0;
    end;

    /// <summary>
    /// Adds a quantity to the running total of an item.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Quantity)
    local procedure AddQuantity(var QtyPerItem: Dictionary of [Code[20], Decimal]; ItemNo: Code[20]; Qty: Decimal)
    begin
        if QtyPerItem.ContainsKey(ItemNo) then
            QtyPerItem.Set(ItemNo, QtyPerItem.Get(ItemNo) + Qty)
        else
            QtyPerItem.Add(ItemNo, Qty);
    end;
}
