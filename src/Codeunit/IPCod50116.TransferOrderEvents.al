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
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Create, Update)
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Transfer Document", 'OnAfterReleaseTransferDoc', '', false, false)]
    local procedure ReleaseTransferDocOnAfterRelease(var TransferHeader: Record "Transfer Header")
    var
        ICROrderMessage: Codeunit "IP ICR Order Message";
    begin
        if TransferHeader.IsTemporary() then
            exit;
        if Context.IsOutboundSuppressed() then
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
        if not ICROrderMessage.SendTransferOrderDeletion(Rec) then
            Error(DeleteNotSentErr, Rec."No.", ICROrderMessage.GetLastFailureText());
    end;
}
