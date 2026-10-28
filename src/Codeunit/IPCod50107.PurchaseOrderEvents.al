/// <summary>
/// Purchase Order event subscribers. They send the ICR order message (production PO, or PO
/// delivered to a filler location) on PO release and on PO deletion, synchronize the AO quantity
/// from the PO quantity, block deletion of a linked PO unless the AO is Open, and clear the AO link
/// when the PO is deleted so Create PO Link can be run again.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing / 4.3 Quantity & Document Control Assumptions (1) / Interface 3.1 PO/TO/ProdPO
codeunit 50107 "IP Purchase Order Events"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        DeleteNotAllowedErr: Label 'Purchase Order %1 cannot be deleted because linked Assembly Order %2 is not in Open status. Reopen the Assembly Order first.', Comment = '%1 = PO No., %2 = AO No.';
        POReopenedTxt: Label 'Order message for Purchase Order %1 failed. The Purchase Order was reopened and must be released again once the issue is fixed.', Comment = '%1 = PO No.';
        POReopenedMsg: Label 'The order message for Purchase Order %1 could not be sent to the filler, so the Purchase Order was set back to Open.\\Reason: %2\\See the Filler Integration Activity Log, then release the Purchase Order again.', Comment = '%1 = PO No., %2 = Error';
        DeleteNotSentErr: Label 'Purchase Order %1 cannot be deleted because the delete message could not be sent to the filler: %2', Comment = '%1 = PO No., %2 = Error';
        PODeletedTxt: Label 'Linked Purchase Order %1 was deleted. The Assembly Order link was cleared and Create PO Link can be run again.', Comment = '%1 = PO No.';

    /// <summary>
    /// PO release trigger point: sends the ICR order message (Create on first release, Update when
    /// changed) for production POs and for POs delivered to a filler location. If the send fails,
    /// the PO is reopened so it never stays released without the filler having received it.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing / 5.14 Outbound Trigger Points (PO Release - Send Production Request)
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", 'OnAfterReleasePurchaseDoc', '', false, false)]
    local procedure ReleasePurchaseDocOnAfterRelease(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean)
    var
        OutboundProdRequest: Codeunit "IP Outbound Prod. Request";
        ICROrderMessage: Codeunit "IP ICR Order Message";
    begin
        if PreviewMode then
            exit;
        if PurchaseHeader."Document Type" <> PurchaseHeader."Document Type"::Order then
            exit;
        if Context.IsOutboundSuppressed() then
            exit;
        if PurchaseHeader."IP Filler Integration" then begin
            if not OutboundProdRequest.SendOnRelease(PurchaseHeader) then
                ReopenAfterFailedSend(PurchaseHeader, OutboundProdRequest.GetLastFailureText());
        end else
            if not ICROrderMessage.SendPurchaseOrder(PurchaseHeader) then
                ReopenAfterFailedSend(PurchaseHeader, ICROrderMessage.GetLastFailureText());
    end;

    /// <summary>
    /// Sets the PO back to Open after a failed production request. Uses Reopen instead of
    /// raising an error, because an error would roll back the Activity Log entry that records
    /// the failure. With the PO open, Linked PO Released = No, so the AO cannot be released either.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function (2) Purchase Order release / 5.6 Outbound Production Request Processing
    local procedure ReopenAfterFailedSend(var PurchaseHeader: Record "Purchase Header"; FailureText: Text)
    var
        ReleasePurchaseDocument: Codeunit "Release Purchase Document";
        EventType: Enum "IP Integration Event Type";
    begin
        ReleasePurchaseDocument.Reopen(PurchaseHeader);
        if PurchaseHeader."IP Filler Integration" then
            EventType := EventType::"Production Request"
        else
            EventType := EventType::"Purchase Order";
        LogMgt.LogEvent("IP Integration Direction"::Internal, EventType, "IP Integration Status"::Exception,
            PurchaseHeader."Buy-from Vendor No.", PurchaseHeader."IP Linked Assembly Order No.", PurchaseHeader."No.", 0,
            StrSubstNo(POReopenedTxt, PurchaseHeader."No."), FailureText);
        if GuiAllowed() then
            Message(POReopenedMsg, PurchaseHeader."No.", FailureText);
    end;

    /// <summary>
    /// When the linked Fill Item PO line quantity changes, the AO quantity is synchronized
    /// from it (PO quantity is the controlling quantity).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 Quantity & Document Control Assumptions (1) AO quantity synchronizes from PO quantity
    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure PurchaseLineOnAfterValidateQuantity(var Rec: Record "Purchase Line"; var xRec: Record "Purchase Line")
    var
        QuantitySynchronization: Codeunit "IP Quantity Synchronization";
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."IP Linked Assembly Order No." = '' then
            exit;
        if Rec.Quantity = xRec.Quantity then
            exit;
        QuantitySynchronization.SyncAssemblyQtyFromPurchLine(Rec);
    end;

    /// <summary>
    /// A linked PO can only be deleted by a user while the linked AO is in Open status. When a PO
    /// that was sent to the filler is deleted, the Delete message (all lines loekz = 'X') is sent
    /// first; if that fails, the deletion is stopped so BC and the filler stay in line.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function (review: to delete PO, AO must be in Open status) / Interface 3.1 PO/TO/ProdPO (Delete)
    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure PurchaseHeaderOnBeforeDelete(var Rec: Record "Purchase Header"; RunTrigger: Boolean)
    var
        AssemblyHeader: Record "Assembly Header";
        ICROrderMessage: Codeunit "IP ICR Order Message";
    begin
        if Rec.IsTemporary() or (not RunTrigger) then
            exit;
        if Rec."Document Type" <> Rec."Document Type"::Order then
            exit;
        if Rec."IP Linked Assembly Order No." <> '' then
            if AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, Rec."IP Linked Assembly Order No.") then
                if AssemblyHeader.Status <> AssemblyHeader.Status::Open then
                    Error(DeleteNotAllowedErr, Rec."No.", AssemblyHeader."No.");
        if not ICROrderMessage.SendPurchaseOrderDeletion(Rec) then
            Error(DeleteNotSentErr, Rec."No.", ICROrderMessage.GetLastFailureText());
    end;

    /// <summary>
    /// Reset / re-link rule: when a linked PO is deleted, the link fields on the AO are cleared
    /// and logged, so the user can run Create PO Link again on the same AO.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function (Function availability rules - existing linked PO does not exist)
    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterDeleteEvent', '', false, false)]
    local procedure PurchaseHeaderOnAfterDelete(var Rec: Record "Purchase Header")
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."IP Linked Assembly Order No." = '' then
            exit;
        if not AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, Rec."IP Linked Assembly Order No.") then
            exit;
        if AssemblyHeader."IP Linked Purch. Order No." <> Rec."No." then
            exit;

        AssemblyHeader."IP Linked Purch. Order No." := '';
        AssemblyHeader."IP Linked Purch. Line No." := 0;
        AssemblyHeader."IP Filler Status" := AssemblyHeader."IP Filler Status"::" ";
        AssemblyHeader."IP Last BOM Hash" := '';
        AssemblyHeader."IP BOM Sent Date" := 0D;
        Clear(AssemblyHeader."IP Integration Rel. ID");
        AssemblyHeader.Modify();

        LogMgt.LogEvent("IP Integration Direction"::Internal, "IP Integration Event Type"::"PO Deleted", "IP Integration Status"::Success,
            Rec."Buy-from Vendor No.", AssemblyHeader."No.", Rec."No.", 0, StrSubstNo(PODeletedTxt, Rec."No."), '');
    end;
}
