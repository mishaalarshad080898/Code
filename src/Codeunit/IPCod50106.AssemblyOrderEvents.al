/// <summary>
/// Assembly Order event subscribers. They stop the AO from being released until the linked PO
/// is released, send the BOM on release, and restrict direct editing of the AO quantity once
/// the AO is linked to a PO.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function / 5.7 Outbound BOM Transmission / 4.3 Quantity & Document Control Assumptions
codeunit 50106 "IP Assembly Order Events"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        QtyRestrictedErr: Label 'The quantity on Assembly Order %1 cannot be changed directly because it is linked to Purchase Order %2. Change the quantity on the Purchase Order; the Assembly Order is synchronized from it.', Comment = '%1 = AO No., %2 = PO No.';
        NotLinkedReleaseErr: Label 'Assembly Order %1 is at filler location %2 and cannot be released before a Purchase Order is linked. Run Create PO Link first.', Comment = '%1 = AO No., %2 = Location Code';
        PONotReleasedErr: Label 'Assembly Order %1 cannot be released because linked Purchase Order %2 is not released (Linked PO Released = No).', Comment = '%1 = AO No., %2 = PO No.';

    /// <summary>
    /// Restricts direct AO quantity editing once linked. The PO quantity controls, and the AO
    /// quantity can only change through the PO-to-AO synchronization.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 Quantity & Document Control Assumptions (1) Direct AO quantity editing is restricted
    [EventSubscriber(ObjectType::Table, Database::"Assembly Header", 'OnBeforeValidateEvent', 'Quantity', false, false)]
    local procedure AssemblyHeaderOnBeforeValidateQuantity(var Rec: Record "Assembly Header"; var xRec: Record "Assembly Header")
    begin
        if Rec.IsTemporary() then
            exit;
        if Rec."IP Linked Purch. Order No." = '' then
            exit;
        if Rec.Quantity = xRec.Quantity then
            exit;
        if Context.ConsumeAllowAssemblyQtySync() then
            exit;
        Error(QtyRestrictedErr, Rec."No.", Rec."IP Linked Purch. Order No.");
    end;

    /// <summary>
    /// AO release guard: an AO at an integrated filler location can only be released when its
    /// linked PO is released (Linked PO Released = True).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function (2) Purchase Order release - Linked PO Released
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Assembly Document", 'OnBeforeReleaseAssemblyDoc', '', false, false)]
    local procedure ReleaseAssemblyDocOnBeforeRelease(var AssemblyHeader: Record "Assembly Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
    begin
        if AssemblyHeader."IP Linked Purch. Order No." = '' then begin
            if FillerSetup.GetEnabledByLocation(AssemblyHeader."Location Code") then
                Error(NotLinkedReleaseErr, AssemblyHeader."No.", AssemblyHeader."Location Code");
            exit;
        end;
        AssemblyHeader.CalcFields("IP Linked PO Released");
        if not AssemblyHeader."IP Linked PO Released" then
            Error(PONotReleasedErr, AssemblyHeader."No.", AssemblyHeader."IP Linked Purch. Order No.");
    end;

    /// <summary>
    /// AO release trigger point: sends the BOM (AO lines) payload to the filler.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission / 5.14 Outbound Trigger Points (AO Release - Send BOM Components)
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Assembly Document", 'OnAfterReleaseAssemblyDoc', '', false, false)]
    local procedure ReleaseAssemblyDocOnAfterRelease(var AssemblyHeader: Record "Assembly Header")
    var
        OutboundBOMTransmission: Codeunit "IP Outbound BOM Transmission";
    begin
        if AssemblyHeader."IP Linked Purch. Order No." = '' then
            exit;
        if Context.IsOutboundSuppressed() then
            exit;
        OutboundBOMTransmission.SendOnRelease(AssemblyHeader);
    end;
}
