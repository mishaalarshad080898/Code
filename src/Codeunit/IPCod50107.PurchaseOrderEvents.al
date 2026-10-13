/// <summary>
/// Purchase Order event subscribers. They send the production request on PO release,
/// synchronize the AO quantity from the PO quantity, block deletion of a linked PO unless the
/// AO is Open, and clear the AO link when the PO is deleted so Create PO Link can be run again.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing / 4.3 Quantity & Document Control Assumptions (1)
codeunit 50107 "IP Purchase Order Events"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        DeleteNotAllowedErr: Label 'Purchase Order %1 cannot be deleted because linked Assembly Order %2 is not in Open status. Reopen the Assembly Order first.', Comment = '%1 = PO No., %2 = AO No.';
        PODeletedTxt: Label 'Linked Purchase Order %1 was deleted. The Assembly Order link was cleared and Create PO Link can be run again.', Comment = '%1 = PO No.';

    /// <summary>
    /// PO release trigger point: sends the outbound production request for filler-linked POs.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.6 Outbound Production Request Processing / 5.14 Outbound Trigger Points (PO Release - Send Production Request)
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", 'OnAfterReleasePurchaseDoc', '', false, false)]
    local procedure ReleasePurchaseDocOnAfterRelease(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean)
    var
        OutboundProdRequest: Codeunit "IP Outbound Prod. Request";
    begin
        if PreviewMode then
            exit;
        if PurchaseHeader."Document Type" <> PurchaseHeader."Document Type"::Order then
            exit;
        if not PurchaseHeader."IP Filler Integration" then
            exit;
        if Context.IsOutboundSuppressed() then
            exit;
        OutboundProdRequest.SendOnRelease(PurchaseHeader);
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
    /// A linked PO can only be deleted by a user while the linked AO is in Open status.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function (review: to delete PO, AO must be in Open status)
    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure PurchaseHeaderOnBeforeDelete(var Rec: Record "Purchase Header"; RunTrigger: Boolean)
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        if Rec.IsTemporary() or (not RunTrigger) then
            exit;
        if Rec."IP Linked Assembly Order No." = '' then
            exit;
        if not AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, Rec."IP Linked Assembly Order No.") then
            exit;
        if AssemblyHeader.Status <> AssemblyHeader.Status::Open then
            Error(DeleteNotAllowedErr, Rec."No.", AssemblyHeader."No.");
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
