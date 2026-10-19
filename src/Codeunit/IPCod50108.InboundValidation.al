/// <summary>
/// Validates an inbound filler completion payload before any BC transaction is posted. It checks
/// payload integrity, filler identity, AO/PO relationship, item identity, pricing, quantity and
/// over-receipt tolerance, the ADO 1507 phantom lot configuration, and duplicate transactions.
/// If validation fails, nothing is posted and inventory stays unchanged.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 Purchase Order Receipt Processing & Production Synchronization (Validations and Exception Handling) / 5.15 Inbound Payload Processing (Payload Validation)
codeunit 50108 "IP Inbound Validation"
{
    TableNo = "IP Filler Inbound Entry";

    trigger OnRun()
    begin
        ValidateEntry(Rec);
    end;

    var
        MissingFieldErr: Label 'Payload integrity: %1 is missing on inbound entry %2.', Comment = '%1 = Field caption, %2 = Entry No.';
        QuantityNotPositiveErr: Label 'Payload integrity: Completed Quantity must be greater than zero (received %1).', Comment = '%1 = Quantity';
        NegativePriceErr: Label 'Payload integrity: Unit Price cannot be negative (received %1).', Comment = '%1 = Unit Price';
        ScrapLineInvalidErr: Label 'Payload integrity: scrap line %1 must have an existing Item No. and a quantity greater than zero.', Comment = '%1 = Line No.';
        FillerUnknownErr: Label 'Filler identity: vendor %1 is not set up in Filler Integration Setup.', Comment = '%1 = Vendor No.';
        FillerDisabledErr: Label 'Filler identity: integration is not enabled for vendor %1.', Comment = '%1 = Vendor No.';
        AONotFoundErr: Label 'Assembly Order %1 does not exist.', Comment = '%1 = AO No.';
        PONotFoundErr: Label 'Purchase Order %1 does not exist.', Comment = '%1 = PO No.';
        POLineNotFoundErr: Label 'Purchase Order %1 line %2 does not exist.', Comment = '%1 = PO No., %2 = Line No.';
        RelationshipErr: Label 'Purchase Order relationship: PO %1 is not linked to Assembly Order %2.', Comment = '%1 = PO No., %2 = AO No.';
        VendorMismatchErr: Label 'Purchase Order relationship: PO %1 belongs to vendor %2, but the payload was sent by vendor %3.', Comment = '%1 = PO No., %2 = PO vendor, %3 = Payload vendor';
        ItemMismatchErr: Label 'Item identity: payload item %1 does not match the finished good %2 on Assembly Order %3.', Comment = '%1 = Payload item, %2 = AO item, %3 = AO No.';
        PriceMismatchErr: Label 'Pricing validation failed: received unit price %1 does not match Direct Unit Cost %2 on PO %3 line %4 (currency %5).', Comment = '%1 = Payload price, %2 = PO price, %3 = PO No., %4 = Line No., %5 = Currency Code';
        OverReceiptErr: Label 'Over-receipt tolerance exceeded: receiving %1 on PO %2 gives a total over-receipt of %3, but the allowed over-receipt is %4 (%5% of ordered quantity %6, Over-Receipt Code %7).', Comment = '%1 = Completed qty, %2 = PO No., %3 = Total overage, %4 = Allowed overage, %5 = Tolerance %, %6 = Ordered qty, %7 = Over-Receipt Code';
        OverReceiptCodeMissingErr: Label 'Over-receipt not allowed: the completed quantity %1 is more than the outstanding quantity %2 on PO %3 line %4, but the PO line has no Over-Receipt Code. Set an Over-Receipt Code on the PO line and retry.', Comment = '%1 = Completed qty, %2 = Outstanding qty, %3 = PO No., %4 = Line No.';
        OverReceiptCodeNotFoundErr: Label 'Over-receipt not allowed: Over-Receipt Code %1 on PO %2 line %3 does not exist.', Comment = '%1 = Over-Receipt Code, %2 = PO No., %3 = Line No.';
        AOQuantityErr: Label 'Production quantity: completed quantity %1 is more than the remaining quantity %2 on Assembly Order %3.', Comment = '%1 = Completed qty, %2 = Remaining qty, %3 = AO No.';
        DuplicateErr: Label 'Duplicate transaction: a payload with Message ID %1 (or the same vendor, PO and payload timestamp) has already been processed.', Comment = '%1 = Message ID';

    /// <summary>
    /// Runs all inbound validations in order. The first failure raises an error, which the
    /// orchestrator records as an Exception in the Activity Log.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Payload Validation)
    procedure ValidateEntry(var InboundEntry: Record "IP Filler Inbound Entry")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        AssemblyHeader: Record "Assembly Header";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        PhantomLotMgt: Codeunit "IP Phantom Lot Mgt";
    begin
        CheckPayloadIntegrity(InboundEntry);
        if IsDuplicate(InboundEntry) then
            Error(DuplicateErr, InboundEntry."Message ID");
        CheckFillerIdentity(InboundEntry, FillerSetup);
        CheckPurchaseOrderRelationship(InboundEntry, PurchaseHeader, PurchaseLine);
        CheckPricing(InboundEntry, PurchaseHeader, PurchaseLine);

        // After output is posted in full, standard posting deletes the AO, so AO checks only run before output posting.
        if not InboundEntry."Output Posted" then begin
            CheckAssemblyOrder(InboundEntry, AssemblyHeader);
            CheckItemIdentity(InboundEntry, AssemblyHeader);
            PhantomLotMgt.CheckConfiguration(AssemblyHeader."Item No.");
        end;
        if not InboundEntry."Receipt Posted" then
            CheckQuantityAndOverReceipt(InboundEntry, PurchaseHeader, PurchaseLine, AssemblyHeader);
    end;

    /// <summary>
    /// Duplicate transaction prevention. A payload is a duplicate when another already processed
    /// entry has the same Message ID, or the same Vendor + PO + Payload Timestamp.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (3) Duplicate Processing Prevention Is Required
    procedure IsDuplicate(InboundEntry: Record "IP Filler Inbound Entry"): Boolean
    var
        OtherEntry: Record "IP Filler Inbound Entry";
    begin
        if InboundEntry."Message ID" <> '' then begin
            OtherEntry.SetCurrentKey("Message ID");
            OtherEntry.SetRange("Message ID", InboundEntry."Message ID");
            OtherEntry.SetFilter("Entry No.", '<>%1', InboundEntry."Entry No.");
            OtherEntry.SetRange(Status, OtherEntry.Status::Processed);
            if not OtherEntry.IsEmpty() then
                exit(true);
        end;

        if InboundEntry."Payload Timestamp" = 0DT then
            exit(false);
        OtherEntry.Reset();
        OtherEntry.SetCurrentKey("Vendor No.", "Purchase Order No.", "Payload Timestamp");
        OtherEntry.SetRange("Vendor No.", InboundEntry."Vendor No.");
        OtherEntry.SetRange("Purchase Order No.", InboundEntry."Purchase Order No.");
        OtherEntry.SetRange("Payload Timestamp", InboundEntry."Payload Timestamp");
        OtherEntry.SetFilter("Entry No.", '<>%1', InboundEntry."Entry No.");
        OtherEntry.SetRange(Status, OtherEntry.Status::Processed);
        exit(not OtherEntry.IsEmpty());
    end;

    /// <summary>
    /// Payload integrity: checks required fields, a positive quantity, a non-negative price,
    /// and valid scrap lines.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 Purchase Order Receipt Processing & Production Synchronization (Payload integrity)
    local procedure CheckPayloadIntegrity(InboundEntry: Record "IP Filler Inbound Entry")
    var
        ScrapLine: Record "IP Filler Inbound Scrap Line";
        Item: Record Item;
    begin
        if InboundEntry."Message ID" = '' then
            Error(MissingFieldErr, InboundEntry.FieldCaption("Message ID"), InboundEntry."Entry No.");
        if InboundEntry."Vendor No." = '' then
            Error(MissingFieldErr, InboundEntry.FieldCaption("Vendor No."), InboundEntry."Entry No.");
        if InboundEntry."Assembly Order No." = '' then
            Error(MissingFieldErr, InboundEntry.FieldCaption("Assembly Order No."), InboundEntry."Entry No.");
        if InboundEntry."Purchase Order No." = '' then
            Error(MissingFieldErr, InboundEntry.FieldCaption("Purchase Order No."), InboundEntry."Entry No.");
        if InboundEntry."Item No." = '' then
            Error(MissingFieldErr, InboundEntry.FieldCaption("Item No."), InboundEntry."Entry No.");
        if InboundEntry."Payload Timestamp" = 0DT then
            Error(MissingFieldErr, InboundEntry.FieldCaption("Payload Timestamp"), InboundEntry."Entry No.");
        if InboundEntry."Completed Quantity" <= 0 then
            Error(QuantityNotPositiveErr, InboundEntry."Completed Quantity");
        if InboundEntry."Unit Price" < 0 then
            Error(NegativePriceErr, InboundEntry."Unit Price");

        ScrapLine.SetRange("Inbound Entry No.", InboundEntry."Entry No.");
        if ScrapLine.FindSet() then
            repeat
                if (ScrapLine.Quantity <= 0) or (not Item.Get(ScrapLine."Item No.")) then
                    Error(ScrapLineInvalidErr, ScrapLine."Line No.");
            until ScrapLine.Next() = 0;
    end;

    /// <summary>
    /// Filler identity: the sending vendor must exist in Filler Integration Setup with
    /// integration enabled.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Filler identity)
    local procedure CheckFillerIdentity(InboundEntry: Record "IP Filler Inbound Entry"; var FillerSetup: Record "IP Filler Integration Setup")
    begin
        if not FillerSetup.Get(InboundEntry."Vendor No.") then
            Error(FillerUnknownErr, InboundEntry."Vendor No.");
        if not FillerSetup."Integration Enabled" then
            Error(FillerDisabledErr, InboundEntry."Vendor No.");
    end;

    /// <summary>
    /// Purchase Order relationship: the PO and its Fill Item line must exist, be linked to the AO,
    /// and belong to the sending filler. If no PO line no. was sent, the linked line is used.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Associated Purchase Order)
    local procedure CheckPurchaseOrderRelationship(var InboundEntry: Record "IP Filler Inbound Entry"; var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line")
    begin
        if not PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, InboundEntry."Purchase Order No.") then
            Error(PONotFoundErr, InboundEntry."Purchase Order No.");
        if PurchaseHeader."IP Linked Assembly Order No." <> InboundEntry."Assembly Order No." then
            Error(RelationshipErr, InboundEntry."Purchase Order No.", InboundEntry."Assembly Order No.");
        if PurchaseHeader."Buy-from Vendor No." <> InboundEntry."Vendor No." then
            Error(VendorMismatchErr, PurchaseHeader."No.", PurchaseHeader."Buy-from Vendor No.", InboundEntry."Vendor No.");

        if InboundEntry."Purchase Order Line No." = 0 then begin
            PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
            PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
            PurchaseLine.SetRange("IP Linked Assembly Order No.", InboundEntry."Assembly Order No.");
            if not PurchaseLine.FindFirst() then
                Error(RelationshipErr, InboundEntry."Purchase Order No.", InboundEntry."Assembly Order No.");
            InboundEntry."Purchase Order Line No." := PurchaseLine."Line No.";
            InboundEntry.Modify();
        end else
            if not PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", InboundEntry."Purchase Order Line No.") then
                Error(POLineNotFoundErr, InboundEntry."Purchase Order No.", InboundEntry."Purchase Order Line No.");

        if PurchaseLine."IP Linked Assembly Order No." <> InboundEntry."Assembly Order No." then
            Error(RelationshipErr, InboundEntry."Purchase Order No.", InboundEntry."Assembly Order No.");
    end;

    /// <summary>
    /// Assembly Order existence and its link back to the same PO.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 Purchase Order Receipt Processing & Production Synchronization (Assembly Order existence)
    local procedure CheckAssemblyOrder(InboundEntry: Record "IP Filler Inbound Entry"; var AssemblyHeader: Record "Assembly Header")
    begin
        if not AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, InboundEntry."Assembly Order No.") then
            Error(AONotFoundErr, InboundEntry."Assembly Order No.");
        if AssemblyHeader."IP Linked Purch. Order No." <> InboundEntry."Purchase Order No." then
            Error(RelationshipErr, InboundEntry."Purchase Order No.", InboundEntry."Assembly Order No.");
    end;

    /// <summary>
    /// Item identity: the finished good in the payload must be the AO output item.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 Purchase Order Receipt Processing & Production Synchronization (Item identity)
    local procedure CheckItemIdentity(InboundEntry: Record "IP Filler Inbound Entry"; AssemblyHeader: Record "Assembly Header")
    begin
        if InboundEntry."Item No." <> AssemblyHeader."Item No." then
            Error(ItemMismatchErr, InboundEntry."Item No.", AssemblyHeader."Item No.", AssemblyHeader."No.");
    end;

    /// <summary>
    /// Pricing validation: the received unit price must match the PO line Direct Unit Cost,
    /// compared in the PO currency and rounded to that currency's unit-amount precision. A
    /// mismatch stops receipt, output and consumption posting.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.12 Pricing Validation
    local procedure CheckPricing(InboundEntry: Record "IP Filler Inbound Entry"; PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line")
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        Currency: Record Currency;
        Precision: Decimal;
    begin
        if PurchaseHeader."Currency Code" = '' then begin
            GeneralLedgerSetup.Get();
            Precision := GeneralLedgerSetup."Unit-Amount Rounding Precision";
        end else begin
            Currency.Get(PurchaseHeader."Currency Code");
            Precision := Currency."Unit-Amount Rounding Precision";
        end;
        if Precision = 0 then
            Precision := 0.00001;

        if Round(InboundEntry."Unit Price", Precision) <> Round(PurchaseLine."Direct Unit Cost", Precision) then
            Error(PriceMismatchErr, InboundEntry."Unit Price", PurchaseLine."Direct Unit Cost", PurchaseLine."Document No.", PurchaseLine."Line No.", PurchaseHeader."Currency Code");
    end;

    /// <summary>
    /// Production / PO receipt quantity and over-receipt tolerance. When the completed quantity is
    /// more than the PO outstanding quantity (overage), the PO line must have an Over-Receipt Code
    /// (e.g. 2%, 5%); a blank or unknown code stops processing. The total over-receipt is measured
    /// against the originally requested quantity and must not exceed the code's tolerance %.
    /// On any failure nothing is posted and the entry becomes an Exception.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.9 Receipt Overage Handling
    local procedure CheckQuantityAndOverReceipt(InboundEntry: Record "IP Filler Inbound Entry"; PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line"; AssemblyHeader: Record "Assembly Header")
    var
        OverReceiptCode: Record "Over-Receipt Code";
        OrderedQty: Decimal;
        TolerancePct: Decimal;
        AllowedOverage: Decimal;
        TotalOverage: Decimal;
    begin
        if InboundEntry."Completed Quantity" <= PurchaseLine."Outstanding Quantity" then begin
            if (not InboundEntry."Output Posted") and (InboundEntry."Completed Quantity" > AssemblyHeader."Remaining Quantity") then
                Error(AOQuantityErr, InboundEntry."Completed Quantity", AssemblyHeader."Remaining Quantity", AssemblyHeader."No.");
            exit;
        end;

        OrderedQty := PurchaseHeader."IP Prod. Request Sent Qty";
        if OrderedQty = 0 then
            OrderedQty := PurchaseLine.Quantity;
        if PurchaseLine."Over-Receipt Code" = '' then
            Error(OverReceiptCodeMissingErr, InboundEntry."Completed Quantity", PurchaseLine."Outstanding Quantity", PurchaseLine."Document No.", PurchaseLine."Line No.");
        if not OverReceiptCode.Get(PurchaseLine."Over-Receipt Code") then
            Error(OverReceiptCodeNotFoundErr, PurchaseLine."Over-Receipt Code", PurchaseLine."Document No.", PurchaseLine."Line No.");
        TolerancePct := OverReceiptCode."Over-Receipt Tolerance %";

        AllowedOverage := Round(OrderedQty * TolerancePct / 100, 0.00001);
        TotalOverage := PurchaseLine."Quantity Received" + InboundEntry."Completed Quantity" - OrderedQty;
        if TotalOverage > AllowedOverage then
            Error(OverReceiptErr, InboundEntry."Completed Quantity", PurchaseLine."Document No.", TotalOverage, AllowedOverage, TolerancePct, OrderedQty, PurchaseLine."Over-Receipt Code");
    end;
}
