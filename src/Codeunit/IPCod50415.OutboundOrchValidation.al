/// <summary>
/// Validations that run before an outbound payload is generated at the Inventory Orchestration
/// trigger points: Purchase Order release and Transfer Order shipment to an integrated filler.
/// Each check returns false plus the reason, so the caller can log the failure and leave the
/// document available for correction instead of raising an error.
/// Duplicate transmission prevention is done by the ICR order message: an unchanged document is
/// not sent again.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.1 Purchase Order Release / 6.2 Transfer Order Shipment to Integrated Filler / 6.3 Outbound Integration Trigger Points
codeunit 50415 "IP Outbound Orch. Validation"
{
    var
        VendorMissingErr: Label 'Vendor %1 on Purchase Order %2 does not exist.', Comment = '%1 = Vendor No., %2 = PO No.';
        VendorBlockedErr: Label 'Vendor %1 on Purchase Order %2 is blocked and is not eligible for filler integration.', Comment = '%1 = Vendor No., %2 = PO No.';
        FillerDisabledErr: Label 'Filler integration is not enabled for filler %1 in Filler Integration Setup.', Comment = '%1 = Vendor No.';
        NoEndpointErr: Label 'No API Endpoint URL is set up for filler %1 in Filler Integration Setup.', Comment = '%1 = Vendor No.';
        NoFillerLinesErr: Label '%1 %2 has no item lines for filler location %3.', Comment = '%1 = Document type, %2 = Document No., %3 = Location Code';
        LineFieldMissingErr: Label '%1 must have a value on line %2 of %3 %4.', Comment = '%1 = Field caption, %2 = Line No., %3 = Document type, %4 = Document No.';
        LineQtyErr: Label 'Quantity must be greater than zero on line %1 of %2 %3.', Comment = '%1 = Line No., %2 = Document type, %3 = Document No.';
        NotShippedErr: Label 'Transfer Order %1 has no shipped quantity to send to filler location %2.', Comment = '%1 = TO No., %2 = Location Code';
        PurchaseOrderTxt: Label 'Purchase Order';
        TransferOrderTxt: Label 'Transfer Order';

    /// <summary>
    /// PO release validation: vendor eligibility, integrated filler configuration and the required
    /// Purchase Order information (item, quantity, unit of measure and expected receipt date on
    /// every line delivered to the filler location). Returns true when the PO is not a filler PO.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.1 Purchase Order Release (Validations and Exception Handling)
    procedure ValidatePurchaseOrderRelease(PurchaseHeader: Record "Purchase Header"; var ErrorText: Text): Boolean
    var
        FillerSetup: Record "IP Filler Integration Setup";
        PurchaseLine: Record "Purchase Line";
        Vendor: Record Vendor;
    begin
        ErrorText := '';
        if not FindPurchaseFillerSetup(PurchaseHeader, FillerSetup) then
            exit(true);

        if not Vendor.Get(PurchaseHeader."Buy-from Vendor No.") then
            exit(SetError(ErrorText, StrSubstNo(VendorMissingErr, PurchaseHeader."Buy-from Vendor No.", PurchaseHeader."No.")));
        if Vendor.Blocked = Vendor.Blocked::All then
            exit(SetError(ErrorText, StrSubstNo(VendorBlockedErr, Vendor."No.", PurchaseHeader."No.")));
        if not CheckFillerConfiguration(FillerSetup, ErrorText) then
            exit(false);

        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.SetRange("Location Code", FillerSetup."Filler Location Code");
        if not PurchaseLine.FindSet() then
            exit(SetError(ErrorText, StrSubstNo(NoFillerLinesErr, PurchaseOrderTxt, PurchaseHeader."No.", FillerSetup."Filler Location Code")));
        repeat
            if PurchaseLine."No." = '' then
                exit(SetError(ErrorText, StrSubstNo(LineFieldMissingErr, PurchaseLine.FieldCaption("No."), PurchaseLine."Line No.", PurchaseOrderTxt, PurchaseHeader."No.")));
            if PurchaseLine.Quantity <= 0 then
                exit(SetError(ErrorText, StrSubstNo(LineQtyErr, PurchaseLine."Line No.", PurchaseOrderTxt, PurchaseHeader."No.")));
            if PurchaseLine."Unit of Measure Code" = '' then
                exit(SetError(ErrorText, StrSubstNo(LineFieldMissingErr, PurchaseLine.FieldCaption("Unit of Measure Code"), PurchaseLine."Line No.", PurchaseOrderTxt, PurchaseHeader."No.")));
            if PurchaseLine."Expected Receipt Date" = 0D then
                exit(SetError(ErrorText, StrSubstNo(LineFieldMissingErr, PurchaseLine.FieldCaption("Expected Receipt Date"), PurchaseLine."Line No.", PurchaseOrderTxt, PurchaseHeader."No.")));
        until PurchaseLine.Next() = 0;
        exit(true);
    end;

    /// <summary>
    /// TO shipment validation, run after the Transfer Shipment is posted. It checks the posted
    /// shipment itself (Transfer Shipment Lines), not the Transfer Order lines: after posting, BC has
    /// already reset Qty. to Ship on the order, and lines not shipped this time must not be checked.
    /// Checks: filler configuration is complete, the shipment has at least one item line with a
    /// quantity, and every shipped line has a unit of measure.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.2 Transfer Order Shipment to Integrated Filler (Validations and Exception Handling)
    procedure ValidateTransferShipment(TransferHeader: Record "Transfer Header"; TransferShipmentHeader: Record "Transfer Shipment Header"; FillerSetup: Record "IP Filler Integration Setup"; var ErrorText: Text): Boolean
    var
        TransferShipmentLine: Record "Transfer Shipment Line";
    begin
        ErrorText := '';
        if not CheckFillerConfiguration(FillerSetup, ErrorText) then
            exit(false);

        // Only the lines of this posted shipment, with an item and a shipped quantity.
        TransferShipmentLine.SetRange("Document No.", TransferShipmentHeader."No.");
        TransferShipmentLine.SetFilter("Item No.", '<>%1', '');
        TransferShipmentLine.SetFilter(Quantity, '>0');
        if not TransferShipmentLine.FindSet() then
            exit(SetError(ErrorText, StrSubstNo(NotShippedErr, TransferHeader."No.", FillerSetup."Filler Location Code")));
        repeat
            if TransferShipmentLine."Unit of Measure Code" = '' then
                exit(SetError(ErrorText, StrSubstNo(LineFieldMissingErr, TransferShipmentLine.FieldCaption("Unit of Measure Code"), TransferShipmentLine."Line No.", TransferOrderTxt, TransferHeader."No.")));
        until TransferShipmentLine.Next() = 0;
        exit(true);
    end;

    /// <summary>
    /// Finds the enabled filler setup for a PO: the PO header location or any item line location
    /// that is an integrated filler location. Production POs (linked to an Assembly Order) are left
    /// to the ICR-MRP production request process.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.1 Purchase Order Release (Integrated filler eligibility is validated)
    procedure FindPurchaseFillerSetup(PurchaseHeader: Record "Purchase Header"; var FillerSetup: Record "IP Filler Integration Setup"): Boolean
    var
        PurchaseLine: Record "Purchase Line";
    begin
        if PurchaseHeader."Document Type" <> PurchaseHeader."Document Type"::Order then
            exit(false);
        if PurchaseHeader."IP Filler Integration" then
            exit(false);
        if FillerSetup.GetEnabledByLocation(PurchaseHeader."Location Code") then
            exit(true);
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        PurchaseLine.SetFilter("Location Code", '<>%1', '');
        if PurchaseLine.FindSet() then
            repeat
                if FillerSetup.GetEnabledByLocation(PurchaseLine."Location Code") then
                    exit(true);
            until PurchaseLine.Next() = 0;
        exit(false);
    end;

    /// <summary>
    /// Integrated filler configuration check: integration enabled and an endpoint set up.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.3 Outbound Integration Trigger Points (Validate integrated filler configuration)
    local procedure CheckFillerConfiguration(FillerSetup: Record "IP Filler Integration Setup"; var ErrorText: Text): Boolean
    begin
        if not FillerSetup."Integration Enabled" then
            exit(SetError(ErrorText, StrSubstNo(FillerDisabledErr, FillerSetup."Vendor No.")));
        if FillerSetup."API Endpoint URL" = '' then
            exit(SetError(ErrorText, StrSubstNo(NoEndpointErr, FillerSetup."Vendor No.")));
        exit(true);
    end;

    /// <summary>
    /// Stores the validation error and returns false, so a check can end with exit(SetError(...)).
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.1 Purchase Order Release (If validation fails, payload generation does not occur)
    local procedure SetError(var ErrorText: Text; NewErrorText: Text): Boolean
    begin
        ErrorText := NewErrorText;
        exit(false);
    end;
}
