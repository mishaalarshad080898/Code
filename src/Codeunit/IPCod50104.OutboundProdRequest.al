/// <summary>
/// Outbound production request. When a filler-linked Purchase Order is released, this builds and
/// sends the production request payload (Document Date, PO Order Date, Vendor No., PO No.,
/// PO Line No., FG Item No., FG Quantity) and logs it.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing
codeunit 50104 "IP Outbound Prod. Request"
{
    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        Transport: Codeunit "IP Filler Transport";
        MessageTypeTok: Label 'PRODUCTION_REQUEST', Locked = true;
        SentDescTxt: Label 'Production request sent for PO %1 (FG %2, quantity %3).', Comment = '%1 = PO No., %2 = Item No., %3 = Quantity';
        NotResentTxt: Label 'PO %1 re-released without a quantity change. Production request not resent.', Comment = '%1 = PO No.';
        NoLinkedLineErr: Label 'Purchase Order %1 has no Fill Item line linked to Assembly Order %2.', Comment = '%1 = PO No., %2 = AO No.';

    /// <summary>
    /// Entry point from the PO release event. Sends the production request when the PO is
    /// released for the first time, or re-released with a changed quantity.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing / 5.14 Outbound Trigger Points (PO Release)
    procedure SendOnRelease(var PurchaseHeader: Record "Purchase Header")
    var
        PurchaseLine: Record "Purchase Line";
    begin
        if not GetLinkedLine(PurchaseHeader, PurchaseLine) then
            exit;
        if PurchaseHeader."IP Prod. Request Sent" and (PurchaseHeader."IP Prod. Request Sent Qty" = PurchaseLine.Quantity) then begin
            LogMgt.LogEvent("IP Integration Direction"::Outbound, "IP Integration Event Type"::"Production Request", "IP Integration Status"::Skipped,
                PurchaseHeader."Buy-from Vendor No.", PurchaseHeader."IP Linked Assembly Order No.", PurchaseHeader."No.", PurchaseLine."Line No.",
                StrSubstNo(NotResentTxt, PurchaseHeader."No."), '');
            exit;
        end;
        SendProductionRequest(PurchaseHeader, PurchaseLine);
    end;

    /// <summary>
    /// Builds and sends the production request payload. Updates the PO transmission flags and
    /// the AO Filler Status.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing
    procedure SendProductionRequest(var PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        AssemblyHeader: Record "Assembly Header";
        MessageID: Text;
        PayloadText: Text;
    begin
        if not FillerSetup.Get(PurchaseHeader."Buy-from Vendor No.") then
            exit;
        if not FillerSetup."Integration Enabled" then
            exit;
        AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, PurchaseHeader."IP Linked Assembly Order No.");

        MessageID := Format(CreateGuid(), 0, 4);
        PayloadText := BuildPayload(PurchaseHeader, PurchaseLine, AssemblyHeader, MessageID);

        if Transport.SendAndLog(FillerSetup, "IP Integration Event Type"::"Production Request", AssemblyHeader."No.", PurchaseHeader."No.", PurchaseLine."Line No.",
            MessageID, PayloadText, '', 0, StrSubstNo(SentDescTxt, PurchaseHeader."No.", AssemblyHeader."Item No.", AssemblyHeader.Quantity))
        then begin
            PurchaseHeader."IP Prod. Request Sent" := true;
            PurchaseHeader."IP Prod. Request Sent Qty" := PurchaseLine.Quantity;
            PurchaseHeader.Modify();
            if AssemblyHeader."IP Filler Status" in [AssemblyHeader."IP Filler Status"::" ", AssemblyHeader."IP Filler Status"::Linked, AssemblyHeader."IP Filler Status"::Exception] then
                LogMgt.UpdateFillerStatus(AssemblyHeader."No.", "IP Filler Status"::"Production Request Sent");
        end else
            LogMgt.UpdateFillerStatus(AssemblyHeader."No.", "IP Filler Status"::Exception);
    end;

    /// <summary>
    /// Builds the production request JSON. Vendor No. and message type let the filler tell a
    /// production request apart from a raw-material PO on the same API. The AO No. and
    /// relationship ID are echoed back on the completion payload for matching.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing (payload content)
    local procedure BuildPayload(PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line"; AssemblyHeader: Record "Assembly Header"; MessageID: Text): Text
    var
        Payload: JsonObject;
        PayloadText: Text;
    begin
        Payload.Add('messageType', MessageTypeTok);
        Payload.Add('messageId', MessageID);
        Payload.Add('documentDate', Format(PurchaseHeader."Document Date", 0, 9));
        Payload.Add('poOrderDate', Format(PurchaseHeader."Order Date", 0, 9));
        Payload.Add('vendorNo', PurchaseHeader."Buy-from Vendor No.");
        Payload.Add('poNo', PurchaseHeader."No.");
        Payload.Add('poLineNo', PurchaseLine."Line No.");
        Payload.Add('fgItemNo', AssemblyHeader."Item No.");
        Payload.Add('fgQuantity', AssemblyHeader.Quantity);
        Payload.Add('fgUnitOfMeasure', AssemblyHeader."Unit of Measure Code");
        Payload.Add('assemblyOrderNo', AssemblyHeader."No.");
        Payload.Add('integrationRelationshipId', Format(PurchaseHeader."IP Integration Rel. ID", 0, 4));
        Payload.WriteTo(PayloadText);
        exit(PayloadText);
    end;

    /// <summary>
    /// Returns the Fill Item purchase line linked to the Assembly Order.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation (1 Purchase Order = 1 Fill Item line)
    local procedure GetLinkedLine(PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line"): Boolean
    begin
        if PurchaseHeader."IP Linked Assembly Order No." = '' then
            exit(false);
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange("IP Linked Assembly Order No.", PurchaseHeader."IP Linked Assembly Order No.");
        if not PurchaseLine.FindFirst() then
            Error(NoLinkedLineErr, PurchaseHeader."No.", PurchaseHeader."IP Linked Assembly Order No.");
        exit(true);
    end;
}
