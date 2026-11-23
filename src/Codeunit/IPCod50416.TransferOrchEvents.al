/// <summary>
/// Transfer Order event subscribers for Inventory Orchestration. Posting a Transfer Shipment to an
/// integrated filler location is the authoritative business event that sends the raw material
/// Transfer Order to the filler. The ICR movement reference and the physical filler lot are carried
/// from the Transfer Order to the posted Transfer Shipment.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.2 Transfer Order Shipment to Integrated Filler / 6.3 Outbound Integration Trigger Points
codeunit 50416 "IP Transfer Orch. Events"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        MovementLogMgt: Codeunit "IP ICR Movement Log Mgt";
        ValidationFailedTxt: Label 'Transfer Shipment %1 of Transfer Order %2 was posted, but the payload was not generated because validation failed. Fix the issue and resend from the Transfer Order.', Comment = '%1 = Shipment No., %2 = TO No.';
        SendFailedTxt: Label 'Transfer Shipment %1 of Transfer Order %2 was posted, but the payload could not be sent to the filler. Resend it from the Activity Log.', Comment = '%1 = Shipment No., %2 = TO No.';
        SentTxt: Label 'Transfer Shipment %1 of Transfer Order %2 posted. Inventory is in transit to filler location %3 and the filler was notified.', Comment = '%1 = Shipment No., %2 = TO No., %3 = Location Code';

    /// <summary>
    /// TO shipment trigger point: after a Transfer Shipment to an integrated filler location is
    /// posted, the shipment is validated and the Transfer Order payload is generated, transmitted and
    /// logged. Inventory stays in standard in-transit status. A failure never rolls back the posted
    /// shipment: it is written to the Activity Log so the payload can be resent.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.2 Transfer Order Shipment to Integrated Filler (Business Central Behavior)
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnAfterTransferOrderPostShipment', '', false, false)]
    local procedure TransferOrderPostShipmentOnAfterPost(var TransferHeader: Record "Transfer Header"; var TransferShipmentHeader: Record "Transfer Shipment Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        OrchValidation: Codeunit "IP Outbound Orch. Validation";
        ICROrderMessage: Codeunit "IP ICR Order Message";
        ErrorText: Text;
    begin
        if TransferHeader.IsTemporary() then
            exit;
        if Context.IsOutboundSuppressed() then
            exit;
        if not FillerSetup.GetEnabledByLocation(TransferHeader."Transfer-to Code") then
            exit;
        if FillerSetup."TO Outbound Trigger" <> FillerSetup."TO Outbound Trigger"::Shipment then
            exit;

        if not OrchValidation.ValidateTransferShipment(TransferHeader, FillerSetup, ErrorText) then begin
            MovementLogMgt.LogDocument("IP Integration Direction"::Outbound, "IP Integration Event Type"::"Outbound Validation", "IP Integration Status"::Exception,
                FillerSetup."Vendor No.", "IP Integration Doc. Type"::"Transfer Order", TransferHeader."No.",
                StrSubstNo(ValidationFailedTxt, TransferShipmentHeader."No.", TransferHeader."No."), ErrorText);
            exit;
        end;

        if not ICROrderMessage.SendTransferOrder(TransferHeader) then begin
            MovementLogMgt.LogDocument("IP Integration Direction"::Outbound, "IP Integration Event Type"::"Transfer Shipment", "IP Integration Status"::Exception,
                FillerSetup."Vendor No.", "IP Integration Doc. Type"::"Transfer Order", TransferHeader."No.",
                StrSubstNo(SendFailedTxt, TransferShipmentHeader."No.", TransferHeader."No."), ICROrderMessage.GetLastFailureText());
            exit;
        end;

        MovementLogMgt.LogDocument("IP Integration Direction"::Internal, "IP Integration Event Type"::"Transfer Shipment", "IP Integration Status"::Success,
            FillerSetup."Vendor No.", "IP Integration Doc. Type"::"Transfer Order", TransferHeader."No.",
            StrSubstNo(SentTxt, TransferShipmentHeader."No.", TransferHeader."No.", TransferHeader."Transfer-to Code"), '');
    end;

    /// <summary>
    /// Copies the ICR movement reference to the posted Transfer Shipment header.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (Activity is logged) / 3.5 Operational Visibility
    [EventSubscriber(ObjectType::Table, Database::"Transfer Shipment Header", 'OnAfterCopyFromTransferHeader', '', false, false)]
    local procedure TransferShipmentHeaderOnAfterCopyFromTransferHeader(var TransferShipmentHeader: Record "Transfer Shipment Header"; TransferHeader: Record "Transfer Header")
    begin
        TransferShipmentHeader."IP ICR Inbound Entry No." := TransferHeader."IP ICR Inbound Entry No.";
        TransferShipmentHeader."IP Created by ICR Movement" := TransferHeader."IP Created by ICR Movement";
    end;

    /// <summary>
    /// Copies the physical filler lot (audit only) to the posted Transfer Shipment line.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (physical lot retained for audit visibility)
    [EventSubscriber(ObjectType::Table, Database::"Transfer Shipment Line", 'OnAfterCopyFromTransferLine', '', false, false)]
    local procedure TransferShipmentLineOnAfterCopyFromTransferLine(var TransferShipmentLine: Record "Transfer Shipment Line"; TransferLine: Record "Transfer Line")
    begin
        TransferShipmentLine."IP Physical Lot No." := TransferLine."IP Physical Lot No.";
    end;
}
