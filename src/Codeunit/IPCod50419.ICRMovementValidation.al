/// <summary>
/// Validates an inbound ICR movement before any BC posting: duplicate prevention, required
/// information, document existence, items, units of measure and quantities. Resolves the BC
/// document (Purchase Order or inbound Transfer Order) and the integrated filler the movement
/// belongs to. Any failure raises an error, so no posting takes place.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Validations and Exception Handling) / 6.5 Finished Goods Shipment Processing (Validations and Exception Handling)
codeunit 50419 "IP ICR Movement Validation"
{
    var
        OrchValidation: Codeunit "IP Outbound Orch. Validation";
        UOMMgt: Codeunit "Unit of Measure Management";
        NoLinesErr: Label 'ICR movement %1 has no lines.', Comment = '%1 = Entry No.';
        UnknownMovementTypeErr: Label 'ICR movement %1 has movement type %2, which is not a known ICR movement type.', Comment = '%1 = Entry No., %2 = MVT_TYPE';
        NotInScopeErr: Label 'ICR movement type %1 is not processed by Inventory Orchestration. Only 030 (Goods Receipt) and 311 (Transfer to 3PL) are in scope.', Comment = '%1 = Movement type';
        PONumberMissingErr: Label 'ICR movement %1 (Goods Receipt) has no order number (PO_NUMBER).', Comment = '%1 = Entry No.';
        DocumentNotFoundErr: Label 'Order %1 of ICR movement %2 does not exist as a Purchase Order or Transfer Order.', Comment = '%1 = PO_NUMBER, %2 = Entry No.';
        ProductionPOErr: Label 'Purchase Order %1 is a production PO linked to Assembly Order %2. Its goods receipt is processed by the ICR-MRP filler completion process, not by Inventory Orchestration.', Comment = '%1 = PO No., %2 = AO No.';
        NotFillerPOErr: Label 'Purchase Order %1 is not delivered to an integrated filler location.', Comment = '%1 = PO No.';
        NotFillerTOErr: Label 'Transfer Order %1 is not shipped to an integrated filler location (Transfer-to Code %2).', Comment = '%1 = TO No., %2 = Location Code';
        LineFieldMissingErr: Label '%1 is missing on line %2 of ICR movement %3.', Comment = '%1 = Field, %2 = Line No., %3 = Entry No.';
        LineQtyErr: Label 'Quantity must be greater than zero on line %1 of ICR movement %2.', Comment = '%1 = Line No., %2 = Entry No.';
        ItemMissingErr: Label 'Item %1 on line %2 of ICR movement %3 does not exist.', Comment = '%1 = Item No., %2 = Line No., %3 = Entry No.';
        UOMMissingErr: Label 'Unit of measure %1 is not set up for item %2.', Comment = '%1 = UoM, %2 = Item No.';
        DocLineNotFoundErr: Label 'Line %1 of %2 %3 does not exist.', Comment = '%1 = Line No., %2 = Document type, %3 = Document No.';
        DocLineItemErr: Label 'Line %1 of %2 %3 is for item %4, but the ICR movement reports item %5.', Comment = '%1 = Line No., %2 = Document type, %3 = Document No., %4 = BC item, %5 = ICR item';
        DocLineUOMErr: Label 'Line %1 of %2 %3 uses unit of measure %4, but the ICR movement reports %5.', Comment = '%1 = Line No., %2 = Document type, %3 = Document No., %4 = BC UoM, %5 = ICR UoM';
        DocLineLocationErr: Label 'Line %1 of Purchase Order %2 is for location %3, not filler location %4.', Comment = '%1 = Line No., %2 = PO No., %3 = Location, %4 = Filler location';
        OverReceiptErr: Label 'The ICR movement receives %1 on line %2 of %3 %4, but only %5 is outstanding.', Comment = '%1 = Qty, %2 = Line No., %3 = Document type, %4 = Document No., %5 = Outstanding qty';
        NoFillerSetupErr: Label 'The integrated filler of ICR movement %1 cannot be determined. Send the filler vendor (LIFNR) or set up exactly one enabled filler.', Comment = '%1 = Entry No.';
        FillerNotEnabledErr: Label 'Filler %1 is not set up or not enabled in Filler Integration Setup.', Comment = '%1 = Vendor No.';
        SetupFieldMissingErr: Label '%1 must be set up for filler %2 in Filler Integration Setup.', Comment = '%1 = Field caption, %2 = Vendor No.';
        PurchaseOrderTxt: Label 'Purchase Order';
        TransferOrderTxt: Label 'Transfer Order';

    /// <summary>
    /// Duplicate prevention: a movement is a duplicate when another movement that was already
    /// processed has the same Message ID, or the same movement type, order number and ICR document
    /// number (HDTEXT).
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 5.2 Integration Assumptions (2) Duplicate transaction prevention is required
    procedure IsDuplicate(MovementHeader: Record "IP ICR Inbound Entry Header"): Boolean
    var
        OtherMovement: Record "IP ICR Inbound Entry Header";
    begin
        OtherMovement.SetFilter("Entry No.", '<>%1', MovementHeader."Entry No.");
        OtherMovement.SetRange(Status, OtherMovement.Status::Processed);
        if MovementHeader."Message ID" <> '' then begin
            OtherMovement.SetRange("Message ID", MovementHeader."Message ID");
            if not OtherMovement.IsEmpty() then
                exit(true);
            OtherMovement.SetRange("Message ID");
        end;
        if MovementHeader."HD Text" = '' then
            exit(false);
        OtherMovement.SetRange("Mvt Type", MovementHeader."Mvt Type");
        OtherMovement.SetRange("PO Number", MovementHeader."PO Number");
        OtherMovement.SetRange("HD Text", MovementHeader."HD Text");
        exit(not OtherMovement.IsEmpty());
    end;

    /// <summary>
    /// Header and line checks shared by all movement types: the movement type is known and in
    /// scope, lines exist, and every line has an existing item, a quantity above zero and a valid
    /// unit of measure.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Required information) / 6.5 (Items, Quantities)
    procedure ValidateHeaderAndLines(MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        MovementLine: Record "IP ICR Inbound Entry Lines";
        Item: Record Item;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if MovementHeader."Movement Type" = MovementHeader."Movement Type"::" " then
            Error(UnknownMovementTypeErr, MovementHeader."Entry No.", MovementHeader."Mvt Type");
        if not (MovementHeader."Movement Type" in [MovementHeader."Movement Type"::"Goods Receipt", MovementHeader."Movement Type"::"Transfer to 3PL"]) then
            Error(NotInScopeErr, MovementHeader."Movement Type");
        if (MovementHeader."Movement Type" = MovementHeader."Movement Type"::"Goods Receipt") and (MovementHeader."PO Number" = '') then
            Error(PONumberMissingErr, MovementHeader."Entry No.");

        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        if not MovementLine.FindSet() then
            Error(NoLinesErr, MovementHeader."Entry No.");
        repeat
            if MovementLine."Item No." = '' then
                Error(LineFieldMissingErr, MovementLine.FieldCaption("Item No."), MovementLine."Entry No.", MovementHeader."Entry No.");
            if MovementLine.Qty <= 0 then
                Error(LineQtyErr, MovementLine."Entry No.", MovementHeader."Entry No.");
            if not Item.Get(MovementLine."Item No.") then
                Error(ItemMissingErr, MovementLine."Item No.", MovementLine."Entry No.", MovementHeader."Entry No.");
            if MovementLine."Unit of Measure" <> '' then
                if not ItemUnitOfMeasure.Get(MovementLine."Item No.", MovementLine."Unit of Measure") then
                    Error(UOMMissingErr, MovementLine."Unit of Measure", MovementLine."Item No.");
            if (MovementHeader."Movement Type" = MovementHeader."Movement Type"::"Goods Receipt") and (MovementLine."Item Line No" = 0) then
                Error(LineFieldMissingErr, MovementLine.FieldCaption("Item Line No"), MovementLine."Entry No.", MovementHeader."Entry No.");
        until MovementLine.Next() = 0;
    end;

    /// <summary>
    /// Goods Receipt (030): finds the BC document for PO_NUMBER. A raw material Purchase Order
    /// delivered to a filler location, or an inbound Transfer Order to a filler location. Sets the
    /// source document and filler vendor on the movement.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Purchase Order receipt OR Transfer Order receipt / Document existence)
    procedure ResolveGoodsReceiptSource(var MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        PurchaseHeader: Record "Purchase Header";
        TransferHeader: Record "Transfer Header";
        FillerSetup: Record "IP Filler Integration Setup";
    begin
        if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, MovementHeader."PO Number") then begin
            if PurchaseHeader."IP Filler Integration" then
                Error(ProductionPOErr, PurchaseHeader."No.", PurchaseHeader."IP Linked Assembly Order No.");
            if not OrchValidation.FindPurchaseFillerSetup(PurchaseHeader, FillerSetup) then
                Error(NotFillerPOErr, PurchaseHeader."No.");
            MovementHeader."Source Document Type" := MovementHeader."Source Document Type"::"Purchase Order";
            MovementHeader."Source Document No." := PurchaseHeader."No.";
            MovementHeader."Vendor No." := FillerSetup."Vendor No.";
            exit;
        end;

        if TransferHeader.Get(MovementHeader."PO Number") then begin
            if not FillerSetup.GetEnabledByLocation(TransferHeader."Transfer-to Code") then
                Error(NotFillerTOErr, TransferHeader."No.", TransferHeader."Transfer-to Code");
            MovementHeader."Source Document Type" := MovementHeader."Source Document Type"::"Transfer Order";
            MovementHeader."Source Document No." := TransferHeader."No.";
            MovementHeader."Vendor No." := FillerSetup."Vendor No.";
            exit;
        end;

        Error(DocumentNotFoundErr, MovementHeader."PO Number", MovementHeader."Entry No.");
    end;

    /// <summary>
    /// Purchase Order receipt checks: every PO_ITEM is an existing item line of the PO at the
    /// filler location, for the same item and unit of measure, and the total quantity received per
    /// line is not more than the outstanding quantity.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Validate: Document existence, Quantities)
    procedure ValidatePurchaseReceipt(MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        MovementLine: Record "IP ICR Inbound Entry Lines";
        PurchaseLine: Record "Purchase Line";
        QtyPerLine: Dictionary of [Integer, Decimal];
        LineNo: Integer;
    begin
        FillerSetup.Get(MovementHeader."Vendor No.");
        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        MovementLine.FindSet();
        repeat
            if not PurchaseLine.Get(PurchaseLine."Document Type"::Order, MovementHeader."Source Document No.", MovementLine."Item Line No") then
                Error(DocLineNotFoundErr, MovementLine."Item Line No", PurchaseOrderTxt, MovementHeader."Source Document No.");
            if (PurchaseLine.Type <> PurchaseLine.Type::Item) or (PurchaseLine."No." <> MovementLine."Item No.") then
                Error(DocLineItemErr, PurchaseLine."Line No.", PurchaseOrderTxt, PurchaseLine."Document No.", PurchaseLine."No.", MovementLine."Item No.");
            if PurchaseLine."Location Code" <> FillerSetup."Filler Location Code" then
                Error(DocLineLocationErr, PurchaseLine."Line No.", PurchaseLine."Document No.", PurchaseLine."Location Code", FillerSetup."Filler Location Code");
            CheckUnitOfMeasure(MovementLine, PurchaseLine."Unit of Measure Code", PurchaseLine."Line No.", PurchaseOrderTxt, PurchaseLine."Document No.");
            AddQuantity(QtyPerLine, PurchaseLine."Line No.", MovementLine.Qty);
        until MovementLine.Next() = 0;

        foreach LineNo in QtyPerLine.Keys() do begin
            PurchaseLine.Get(PurchaseLine."Document Type"::Order, MovementHeader."Source Document No.", LineNo);
            if QtyPerLine.Get(LineNo) > PurchaseLine."Outstanding Quantity" then
                Error(OverReceiptErr, QtyPerLine.Get(LineNo), LineNo, PurchaseOrderTxt, PurchaseLine."Document No.", PurchaseLine."Outstanding Quantity");
        end;
    end;

    /// <summary>
    /// Transfer Order receipt checks: every PO_ITEM is an existing line of the TO for the same item
    /// and unit of measure, and the total quantity received per line is not more than the quantity
    /// in transit.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Validate: Document existence, Quantities)
    procedure ValidateTransferReceipt(MovementHeader: Record "IP ICR Inbound Entry Header")
    var
        MovementLine: Record "IP ICR Inbound Entry Lines";
        TransferLine: Record "Transfer Line";
        QtyPerLine: Dictionary of [Integer, Decimal];
        LineNo: Integer;
    begin
        MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
        MovementLine.FindSet();
        repeat
            if not TransferLine.Get(MovementHeader."Source Document No.", MovementLine."Item Line No") then
                Error(DocLineNotFoundErr, MovementLine."Item Line No", TransferOrderTxt, MovementHeader."Source Document No.");
            if TransferLine."Item No." <> MovementLine."Item No." then
                Error(DocLineItemErr, TransferLine."Line No.", TransferOrderTxt, TransferLine."Document No.", TransferLine."Item No.", MovementLine."Item No.");
            CheckUnitOfMeasure(MovementLine, TransferLine."Unit of Measure Code", TransferLine."Line No.", TransferOrderTxt, TransferLine."Document No.");
            AddQuantity(QtyPerLine, TransferLine."Line No.", MovementLine.Qty);
        until MovementLine.Next() = 0;

        foreach LineNo in QtyPerLine.Keys() do begin
            TransferLine.Get(MovementHeader."Source Document No.", LineNo);
            if QtyPerLine.Get(LineNo) > TransferLine."Qty. in Transit" then
                Error(OverReceiptErr, QtyPerLine.Get(LineNo), LineNo, TransferOrderTxt, TransferLine."Document No.", TransferLine."Qty. in Transit");
        end;
    end;

    /// <summary>
    /// Finished goods shipment (311): determines the integrated filler that shipped the goods. Uses
    /// the filler vendor on the movement, else the vendor (LIFNR) on the first line, else the only
    /// enabled filler. Checks that the filler location and the 3PL destination are set up.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Validate: Destination)
    procedure ResolveFillerSetup(var MovementHeader: Record "IP ICR Inbound Entry Header"; var FillerSetup: Record "IP Filler Integration Setup")
    var
        MovementLine: Record "IP ICR Inbound Entry Lines";
        Location: Record Location;
    begin
        if MovementHeader."Vendor No." = '' then begin
            MovementLine.SetRange("Inbound Header Entry No.", MovementHeader."Entry No.");
            MovementLine.SetFilter("Vendor No.", '<>%1', '');
            if MovementLine.FindFirst() then
                MovementHeader."Vendor No." := MovementLine."Vendor No.";
        end;
        if MovementHeader."Vendor No." = '' then begin
            FillerSetup.SetRange("Integration Enabled", true);
            if FillerSetup.Count() <> 1 then
                Error(NoFillerSetupErr, MovementHeader."Entry No.");
            FillerSetup.FindFirst();
            MovementHeader."Vendor No." := FillerSetup."Vendor No.";
        end;

        if not FillerSetup.Get(MovementHeader."Vendor No.") then
            Error(FillerNotEnabledErr, MovementHeader."Vendor No.");
        if not FillerSetup."Integration Enabled" then
            Error(FillerNotEnabledErr, MovementHeader."Vendor No.");
        if FillerSetup."Filler Location Code" = '' then
            Error(SetupFieldMissingErr, FillerSetup.FieldCaption("Filler Location Code"), FillerSetup."Vendor No.");
        if FillerSetup."FG 3PL Location Code" = '' then
            Error(SetupFieldMissingErr, FillerSetup.FieldCaption("FG 3PL Location Code"), FillerSetup."Vendor No.");
        Location.Get(FillerSetup."FG 3PL Location Code");
        Location.TestField("Use As In-Transit", false);
    end;

    /// <summary>
    /// Converts the movement line quantity to the item's base unit of measure. A blank MEINS means
    /// the base unit of measure.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Quantity match)
    procedure GetQuantityBase(MovementLine: Record "IP ICR Inbound Entry Lines"): Decimal
    var
        Item: Record Item;
    begin
        Item.Get(MovementLine."Item No.");
        if MovementLine."Unit of Measure" = '' then
            exit(MovementLine.Qty);
        exit(Round(MovementLine.Qty * UOMMgt.GetQtyPerUnitOfMeasure(Item, MovementLine."Unit of Measure"), UOMMgt.QtyRndPrecision()));
    end;

    /// <summary>
    /// The ICR unit of measure (MEINS), when sent, must be the unit of measure of the BC line.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Quantities)
    local procedure CheckUnitOfMeasure(MovementLine: Record "IP ICR Inbound Entry Lines"; LineUnitOfMeasureCode: Code[10]; LineNo: Integer; DocTypeText: Text; DocNo: Code[20])
    begin
        if MovementLine."Unit of Measure" = '' then
            exit;
        if MovementLine."Unit of Measure" <> LineUnitOfMeasureCode then
            Error(DocLineUOMErr, LineNo, DocTypeText, DocNo, LineUnitOfMeasureCode, MovementLine."Unit of Measure");
    end;

    /// <summary>
    /// Adds a quantity to the running total of a BC line, so several posd lines for the same BC line
    /// are checked together against the outstanding quantity.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Quantities)
    local procedure AddQuantity(var QtyPerLine: Dictionary of [Integer, Decimal]; LineNo: Integer; Qty: Decimal)
    begin
        if QtyPerLine.ContainsKey(LineNo) then
            QtyPerLine.Set(LineNo, QtyPerLine.Get(LineNo) + Qty)
        else
            QtyPerLine.Add(LineNo, Qty);
    end;
}
