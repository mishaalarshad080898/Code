/// <summary>
/// Transfer Order event subscribers. A transfer order shipped to a filler location sends the ICR
/// order message on release (Create / Update) and on deletion (Delete). If the release message
/// fails, the TO is reopened; if the delete message fails, the deletion is stopped.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO
codeunit 50116 "IP Transfer Order Events"
{
    var
        Context: Codeunit "IP Filler Integration Context";
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        TOReopenedTxt: Label 'Order message for Transfer Order %1 failed. The Transfer Order was reopened and must be released again once the issue is fixed.', Comment = '%1 = TO No.';
        TOReopenedMsg: Label 'The order message for Transfer Order %1 could not be sent to the filler, so the Transfer Order was set back to Open.\\Reason: %2\\See the Filler Integration Activity Log, then release the Transfer Order again.', Comment = '%1 = TO No., %2 = Error';
        DeleteNotSentErr: Label 'Transfer Order %1 cannot be deleted because the delete message could not be sent to the filler: %2', Comment = '%1 = TO No., %2 = Error';

    /// <summary>
    /// TO release trigger point: sends the ICR order message (Create on first release, Update when
    /// changed) for transfer orders to a filler location. Reopens the TO when the send fails.
    /// Skipped when the filler's TO Outbound Trigger is Shipment (sent on shipment posting instead).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Create, Update)
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.2 Transfer Order Shipment to Integrated Filler
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Transfer Document", 'OnAfterReleaseTransferDoc', '', false, false)]
    local procedure ReleaseTransferDocOnAfterRelease(var TransferHeader: Record "Transfer Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        ICROrderMessage: Codeunit "IP ICR Order Message";
    begin
        if TransferHeader.IsTemporary() then
            exit;
        if Context.IsOutboundSuppressed() then
            exit;
        // Inventory Orchestration 6.2: when the filler is set to send on shipment, release sends nothing.
        if FillerSetup.GetEnabledByLocation(TransferHeader."Transfer-to Code") then
            if FillerSetup."TO Outbound Trigger" = FillerSetup."TO Outbound Trigger"::Shipment then
                exit;
        if not ICROrderMessage.SendTransferOrder(TransferHeader) then
            ReopenAfterFailedSend(TransferHeader, ICROrderMessage.GetLastFailureText());
    end;

    /// <summary>
    /// Sets the TO back to Open after a failed order message, instead of raising an error, so the
    /// Activity Log entry that records the failure is kept.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO
    local procedure ReopenAfterFailedSend(var TransferHeader: Record "Transfer Header"; FailureText: Text)
    var
        ReleaseTransferDocument: Codeunit "Release Transfer Document";
    begin
        ReleaseTransferDocument.Reopen(TransferHeader);
        LogMgt.LogEvent("IP Integration Direction"::Internal, "IP Integration Event Type"::"Transfer Order", "IP Integration Status"::Exception,
            '', '', '', 0, StrSubstNo(TOReopenedTxt, TransferHeader."No."), FailureText);
        if GuiAllowed() then
            Message(TOReopenedMsg, TransferHeader."No.", FailureText);
    end;

    /// <summary>
    /// When a TO that was sent to the filler is deleted by a user, the Delete message (all lines
    /// loekz = 'X') is sent first; if that fails, the deletion is stopped.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Delete)
    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnBeforeDeleteEvent', '', false, false)]
    local procedure TransferHeaderOnBeforeDelete(var Rec: Record "Transfer Header"; RunTrigger: Boolean)
    var
        ICROrderMessage: Codeunit "IP ICR Order Message";
    begin
        if Rec.IsTemporary() or (not RunTrigger) then
            exit;
        // BC refuses to delete a TO with items still in transit. Do not tell the filler it is deleted
        // when BC will stop the deletion right after this subscriber.
        if HasQtyInTransit(Rec) then
            exit;
        if not ICROrderMessage.SendTransferOrderDeletion(Rec) then
            Error(DeleteNotSentErr, Rec."No.", ICROrderMessage.GetLastFailureText());
    end;

    /// <summary>
    /// True when a line of the TO was shipped but not yet received (items in transit). BC does not
    /// allow such a TO to be deleted, so no Delete message may be sent for it.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Delete)
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.2 Transfer Order Shipment to Integrated Filler (inventory in transit)
    local procedure HasQtyInTransit(TransferHeader: Record "Transfer Header"): Boolean
    var
        TransferLine: Record "Transfer Line";
    begin
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        if TransferLine.FindSet() then
            repeat
                if TransferLine."Quantity Shipped" <> TransferLine."Quantity Received" then
                    exit(true);
            until TransferLine.Next() = 0;
        exit(false);
    end;
}
