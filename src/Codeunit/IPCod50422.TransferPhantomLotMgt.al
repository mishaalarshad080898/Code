/// <summary>
/// Item tracking on Transfer Orders for Inventory Orchestration. For covered finished goods with
/// Phantom Lot enabled (ADO 1507) the Transfer Shipment quantity is tracked with the universal
/// phantom lot (XXXX) before standard posting validation; a physical lot in the payload is ignored
/// for BC tracking and never raises a mismatch. With Phantom Lot disabled, or for items that are not
/// covered, standard lot processing is unchanged.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (ADO 1507 Phantom Lot) / 3.2 Core Behavior
codeunit 50422 "IP Transfer Phantom Lot Mgt"
{
    var
        PhantomLotMgt: Codeunit "IP Phantom Lot Mgt";
        PhantomNotEnabledErr: Label 'The shipment payload reports phantom lot %1 for item %2, but Phantom Lot is not enabled on Company Information or the item is not Phantom Lot Covered.', Comment = '%1 = Lot No., %2 = Item No.';
        NotAvailableErr: Label 'Only %1 of item %2 is available under lot %3 at location %4, but %5 must be shipped.', Comment = '%1 = Available qty, %2 = Item No., %3 = Lot No., %4 = Location, %5 = Qty to ship';
        ReservedConflictErr: Label 'Transfer Order %1 line %2 is reserved against lot %3. Remove the reservation before lot %4 can be assigned.', Comment = '%1 = TO No., %2 = Line No., %3 = Reserved lot, %4 = Lot to assign';
        PhantomAssignedTxt: Label 'Phantom lot %1 assigned to %2 of item %3 on Transfer Order %4 line %5. Filler lot %6 kept for audit only.', Comment = '%1 = Phantom lot, %2 = Qty, %3 = Item, %4 = TO No., %5 = Line No., %6 = Physical lot';
        PhysicalAssignedTxt: Label 'Lot %1 assigned to %2 of item %3 on Transfer Order %4 line %5 (standard lot processing).', Comment = '%1 = Lot, %2 = Qty, %3 = Item, %4 = TO No., %5 = Line No.';

    /// <summary>
    /// Assigns the shipment item tracking of a Transfer Order line for its Qty. to Ship. Covered FG
    /// with Phantom Lot enabled: XXXX, after checking the item is lot tracked and enough inventory is
    /// available under XXXX. Otherwise: the physical lot from the payload when the item is lot
    /// tracked, else nothing (standard behavior). Returns the description for the Activity Log.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (BC assigns or validates XXXX on the Transfer Shipment item-tracking quantity)
    procedure AssignShipmentTracking(TransferLine: Record "Transfer Line"; PhysicalLotNo: Code[50]): Text
    var
        LotNo: Code[50];
    begin
        if PhantomLotMgt.IsPhantomLotApplicable(TransferLine."Item No.") then begin
            PhantomLotMgt.CheckConfiguration(TransferLine."Item No.");
            LotNo := PhantomLotMgt.GetPhantomLotNo();
            CheckLotAvailability(TransferLine, LotNo);
            ReplaceOutboundTracking(TransferLine, LotNo);
            exit(StrSubstNo(PhantomAssignedTxt, LotNo, TransferLine."Qty. to Ship", TransferLine."Item No.", TransferLine."Document No.", TransferLine."Line No.", PhysicalLotNo));
        end;

        if PhysicalLotNo = '' then
            exit('');
        if PhysicalLotNo = PhantomLotMgt.GetPhantomLotNo() then
            Error(PhantomNotEnabledErr, PhysicalLotNo, TransferLine."Item No.");
        if not IsLotTracked(TransferLine."Item No.") then
            exit('');
        CheckLotAvailability(TransferLine, PhysicalLotNo);
        ReplaceOutboundTracking(TransferLine, PhysicalLotNo);
        exit(StrSubstNo(PhysicalAssignedTxt, PhysicalLotNo, TransferLine."Qty. to Ship", TransferLine."Item No.", TransferLine."Document No.", TransferLine."Line No."));
    end;

    /// <summary>
    /// Sets Qty. to Handle on the receipt-side item tracking that BC created at shipment, so a
    /// partial Transfer Receipt posts exactly the quantity received. When a lot is given, that lot is
    /// handled first.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Transfer Order receipt)
    procedure SetInboundTransferQtyToHandle(TransferLine: Record "Transfer Line"; PreferredLotNo: Code[50])
    var
        ReservationEntry: Record "Reservation Entry";
        RemainingBase: Decimal;
    begin
        if not IsLotTracked(TransferLine."Item No.") then
            exit;
        FilterTransferTracking(ReservationEntry, TransferLine, 1);
        if ReservationEntry.IsEmpty() then
            exit;
        ReservationEntry.ModifyAll("Qty. to Handle (Base)", 0);
        ReservationEntry.ModifyAll("Qty. to Invoice (Base)", 0);

        RemainingBase := TransferLine."Qty. to Receive (Base)";
        if PreferredLotNo <> '' then begin
            ReservationEntry.SetRange("Lot No.", PreferredLotNo);
            AllocateQtyToHandle(ReservationEntry, RemainingBase);
            ReservationEntry.SetRange("Lot No.");
        end;
        AllocateQtyToHandle(ReservationEntry, RemainingBase);
    end;

    /// <summary>
    /// Returns true when the item has lot-specific item tracking.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Phantom Lot configuration)
    procedure IsLotTracked(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not Item.Get(ItemNo) then
            exit(false);
        if Item."Item Tracking Code" = '' then
            exit(false);
        if not ItemTrackingCode.Get(Item."Item Tracking Code") then
            exit(false);
        exit(ItemTrackingCode."Lot Specific Tracking");
    end;

    /// <summary>
    /// Checks that the transfer-from location holds enough open inventory under the lot for the
    /// quantity to ship ("Covered finished-goods inventory is available under XXXX").
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Covered finished-goods inventory is available under XXXX)
    local procedure CheckLotAvailability(TransferLine: Record "Transfer Line"; LotNo: Code[50])
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", TransferLine."Item No.");
        ItemLedgerEntry.SetRange("Variant Code", TransferLine."Variant Code");
        ItemLedgerEntry.SetRange("Location Code", TransferLine."Transfer-from Code");
        ItemLedgerEntry.SetRange("Lot No.", LotNo);
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.CalcSums("Remaining Quantity");
        if ItemLedgerEntry."Remaining Quantity" < TransferLine."Qty. to Ship (Base)" then
            Error(NotAvailableErr, ItemLedgerEntry."Remaining Quantity", TransferLine."Item No.", LotNo, TransferLine."Transfer-from Code", TransferLine."Qty. to Ship (Base)");
    end;

    /// <summary>
    /// Replaces the shipment-side lot tracking of the line with the given lot for Qty. to Ship.
    /// Unposted tracking with another lot is removed; a reservation against another lot stops
    /// processing, because it cannot be changed silently.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (before standard posting validation)
    local procedure ReplaceOutboundTracking(TransferLine: Record "Transfer Line"; LotNo: Code[50])
    var
        ReservationEntry: Record "Reservation Entry";
        ForReservationEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservedBase: Decimal;
        QtyToCreateBase: Decimal;
    begin
        FilterTransferTracking(ReservationEntry, TransferLine, 0);
        if ReservationEntry.FindSet(true) then
            repeat
                if ReservationEntry."Reservation Status" = ReservationEntry."Reservation Status"::Reservation then begin
                    if ReservationEntry."Lot No." <> LotNo then
                        Error(ReservedConflictErr, TransferLine."Document No.", TransferLine."Line No.", ReservationEntry."Lot No.", LotNo);
                    ReservedBase += Abs(ReservationEntry."Quantity (Base)");
                end else
                    ReservationEntry.Delete();
            until ReservationEntry.Next() = 0;

        QtyToCreateBase := TransferLine."Qty. to Ship (Base)" - ReservedBase;
        if QtyToCreateBase <= 0 then
            exit;
        ForReservationEntry."Lot No." := LotNo;
        CreateReservEntry.CreateReservEntryFor(
            Database::"Transfer Line", 0, TransferLine."Document No.", '', 0, TransferLine."Line No.",
            TransferLine."Qty. per Unit of Measure", Round(QtyToCreateBase / TransferLine."Qty. per Unit of Measure", 0.00001), QtyToCreateBase,
            ForReservationEntry);
        CreateReservEntry.CreateEntry(
            TransferLine."Item No.", TransferLine."Variant Code", TransferLine."Transfer-from Code", TransferLine.Description,
            0D, TransferLine."Shipment Date", 0, "Reservation Status"::Surplus);
    end;

    /// <summary>
    /// Filters the lot tracking entries of a Transfer Order line: direction 0 = shipment side,
    /// 1 = receipt side.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing
    local procedure FilterTransferTracking(var ReservationEntry: Record "Reservation Entry"; TransferLine: Record "Transfer Line"; Direction: Integer)
    begin
        ReservationEntry.SetRange("Source Type", Database::"Transfer Line");
        ReservationEntry.SetRange("Source Subtype", Direction);
        ReservationEntry.SetRange("Source ID", TransferLine."Document No.");
        ReservationEntry.SetRange("Source Batch Name", '');
        ReservationEntry.SetRange("Source Ref. No.", TransferLine."Line No.");
        ReservationEntry.SetFilter("Lot No.", '<>%1', '');
    end;

    /// <summary>
    /// Gives each tracking entry as much Qty. to Handle as it can take until the received quantity
    /// is allocated.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Quantities)
    local procedure AllocateQtyToHandle(var ReservationEntry: Record "Reservation Entry"; var RemainingBase: Decimal)
    var
        TakeBase: Decimal;
    begin
        if RemainingBase <= 0 then
            exit;
        if not ReservationEntry.FindSet(true) then
            exit;
        repeat
            TakeBase := Abs(ReservationEntry."Quantity (Base)") - Abs(ReservationEntry."Qty. to Handle (Base)");
            if TakeBase > RemainingBase then
                TakeBase := RemainingBase;
            if TakeBase > 0 then begin
                ReservationEntry."Qty. to Handle (Base)" := ReservationEntry."Qty. to Handle (Base)" + TakeBase * GetSign(ReservationEntry);
                ReservationEntry."Qty. to Invoice (Base)" := ReservationEntry."Qty. to Handle (Base)";
                ReservationEntry.Modify();
                RemainingBase -= TakeBase;
            end;
        until (ReservationEntry.Next() = 0) or (RemainingBase <= 0);
    end;

    /// <summary>
    /// Qty. to Handle (Base) has the same sign as Quantity (Base) on a tracking entry.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing
    local procedure GetSign(ReservationEntry: Record "Reservation Entry"): Integer
    begin
        if ReservationEntry."Quantity (Base)" < 0 then
            exit(-1);
        exit(1);
    end;
}
