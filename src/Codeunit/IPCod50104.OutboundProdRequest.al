/// <summary>
/// Outbound production request. When a filler-linked Purchase Order (production PO) is released,
/// the ICR order message (interface 3.1, order type = Prod. PO Order Type) is sent through
/// IP ICR Order Message, and the PO transmission flags and AO Filler Status are updated.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing / Interface 3.1 PO/TO/ProdPO
codeunit 50104 "IP Outbound Prod. Request"
{
    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        ICROrderMessage: Codeunit "IP ICR Order Message";
        NoLinkedLineErr: Label 'Purchase Order %1 has no Fill Item line linked to Assembly Order %2.', Comment = '%1 = PO No., %2 = AO No.';

    /// <summary>
    /// Entry point from the PO release event. Sends the Create message on the first release and an
    /// Update message on a later release when the PO changed (an unchanged PO is not resent).
    /// Returns false only when the send failed, so the caller can stop the PO from staying released.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing / 5.14 Outbound Trigger Points (PO Release)
    procedure SendOnRelease(var PurchaseHeader: Record "Purchase Header"): Boolean
    var
        PurchaseLine: Record "Purchase Line";
    begin
        if not GetLinkedLine(PurchaseHeader, PurchaseLine) then
            exit(true);
        exit(SendProductionRequest(PurchaseHeader, PurchaseLine));
    end;

    /// <summary>
    /// Sends the production PO message and updates the PO transmission flags and the AO Filler
    /// Status. Returns false when the filler endpoint did not accept the message.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing
    procedure SendProductionRequest(var PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line"): Boolean
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        if not ICROrderMessage.SendPurchaseOrder(PurchaseHeader) then begin
            LogMgt.UpdateFillerStatus(PurchaseHeader."IP Linked Assembly Order No.", "IP Filler Status"::Exception);
            exit(false);
        end;

        PurchaseHeader."IP Prod. Request Sent" := true;
        PurchaseHeader."IP Prod. Request Sent Qty" := PurchaseLine.Quantity;
        PurchaseHeader.Modify();
        if AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, PurchaseHeader."IP Linked Assembly Order No.") then
            if AssemblyHeader."IP Filler Status" in [AssemblyHeader."IP Filler Status"::" ", AssemblyHeader."IP Filler Status"::Linked, AssemblyHeader."IP Filler Status"::Exception] then
                LogMgt.UpdateFillerStatus(AssemblyHeader."No.", "IP Filler Status"::"Production Request Sent");
        exit(true);
    end;

    /// <summary>
    /// Returns the reason of the last failed send.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (2) Payload failures can occur
    procedure GetLastFailureText(): Text
    begin
        exit(ICROrderMessage.GetLastFailureText());
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
