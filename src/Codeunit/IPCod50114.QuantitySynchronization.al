/// <summary>
/// Quantity synchronization between the linked Purchase Order and Assembly Order. The PO
/// quantity controls and the AO quantity follows it. For an inbound overage within the
/// over-receipt tolerance, both the PO quantity and the AO quantity are increased.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 Quantity & Document Control Assumptions (1) / 5.9 Receipt Overage Handling
codeunit 50114 "IP Quantity Synchronization"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        AssemblyNotOpenErr: Label 'Assembly Order %1 must be in Open status before the quantity on linked Purchase Order %2 can be changed. Reopen the Assembly Order first.', Comment = '%1 = AO No., %2 = PO No.';
        OverageSyncTxt: Label 'Overage of %1 applied. PO %2 and AO %3 quantity increased to %4.', Comment = '%1 = Overage qty, %2 = PO No., %3 = AO No., %4 = New quantity';
        NoOverageTxt: Label 'No overage. PO and AO quantities unchanged.';

    /// <summary>
    /// Copies the PO Fill Item line quantity to the linked AO quantity. The AO must be Open,
    /// because a released AO quantity cannot change without a BOM resend.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 Quantity & Document Control Assumptions (1) AO quantity synchronizes from PO quantity
    procedure SyncAssemblyQtyFromPurchLine(PurchaseLine: Record "Purchase Line")
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        if not AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, PurchaseLine."IP Linked Assembly Order No.") then
            exit;
        if AssemblyHeader."IP Linked Purch. Order No." <> PurchaseLine."Document No." then
            exit;
        if AssemblyHeader.Quantity = PurchaseLine.Quantity then
            exit;
        if AssemblyHeader.Status <> AssemblyHeader.Status::Open then
            Error(AssemblyNotOpenErr, AssemblyHeader."No.", PurchaseLine."Document No.");

        Context.SetAllowAssemblyQtySync();
        AssemblyHeader.Validate(Quantity, PurchaseLine.Quantity);
        AssemblyHeader.Modify(true);
    end;

    /// <summary>
    /// Applies an inbound overage. When the completed quantity is more than the PO outstanding
    /// quantity, the PO and AO are reopened, the PO quantity is increased (which syncs the AO
    /// quantity), and both are released again with outbound payloads suppressed. The tolerance
    /// has already been checked by IP Inbound Validation.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.9 Receipt Overage Handling (Update Assembly Order quantity / Purchase Order quantity)
    procedure ApplyOverage(InboundEntry: Record "IP Filler Inbound Entry")
    var
        AssemblyHeader: Record "Assembly Header";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ReleasePurchaseDocument: Codeunit "Release Purchase Document";
        ReleaseAssemblyDocument: Codeunit "Release Assembly Document";
        OverageQty: Decimal;
        AOWasReleased: Boolean;
        POWasReleased: Boolean;
    begin
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, InboundEntry."Purchase Order No.");
        PurchaseLine.Get(PurchaseLine."Document Type"::Order, InboundEntry."Purchase Order No.", InboundEntry."Purchase Order Line No.");
        AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, InboundEntry."Assembly Order No.");

        OverageQty := InboundEntry."Completed Quantity" - PurchaseLine."Outstanding Quantity";
        if OverageQty <= 0 then begin
            LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Quantity Synchronization", "IP Integration Status"::Skipped, NoOverageTxt, '');
            exit;
        end;

        Context.SetSuppressOutbound(true);

        AOWasReleased := AssemblyHeader.Status = AssemblyHeader.Status::Released;
        if AOWasReleased then
            ReleaseAssemblyDocument.Reopen(AssemblyHeader);
        POWasReleased := PurchaseHeader.Status = PurchaseHeader.Status::Released;
        if POWasReleased then
            ReleasePurchaseDocument.Reopen(PurchaseHeader);

        // Validating the PO quantity triggers the PO-to-AO sync (IP Purchase Order Events).
        PurchaseLine.Get(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.");
        PurchaseLine.Validate(Quantity, PurchaseLine.Quantity + OverageQty);
        PurchaseLine.Modify(true);

        if POWasReleased then begin
            PurchaseHeader.Get(PurchaseHeader."Document Type", PurchaseHeader."No.");
            ReleasePurchaseDocument.Run(PurchaseHeader);
        end;
        if AOWasReleased then begin
            AssemblyHeader.Get(AssemblyHeader."Document Type", AssemblyHeader."No.");
            ReleaseAssemblyDocument.Run(AssemblyHeader);
        end;

        LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Quantity Synchronization", "IP Integration Status"::Success,
            StrSubstNo(OverageSyncTxt, OverageQty, PurchaseLine."Document No.", AssemblyHeader."No.", PurchaseLine.Quantity), '');
    end;
}
