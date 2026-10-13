/// <summary>
/// Automated transaction processing for a validated inbound completion. Runs in this order:
/// (1) quantity synchronization for overages, (2) Purchase Order receipt posting,
/// (3) phantom lot assignment and Assembly Order output and component consumption posting,
/// (4) scrap posting. Each step is committed and flagged on the inbound entry, so a retry
/// resumes at the failed step and never posts a completed step twice.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 Purchase Order Receipt Processing & Production Synchronization (Business Central Behavior) / 5.8 Partial Completion Processing
codeunit 50109 "IP Inbound Posting"
{
    TableNo = "IP Filler Inbound Entry";

    trigger OnRun()
    begin
        PostEntry(Rec);
    end;

    var
        Context: Codeunit "IP Filler Integration Context";
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        ReceiptPostedTxt: Label 'Purchase receipt %1 posted for %2 on PO %3.', Comment = '%1 = Receipt No., %2 = Quantity, %3 = PO No.';
        OutputPostedTxt: Label 'Assembly output and component consumption posted for %1 on AO %2 (posted assembly %3).', Comment = '%1 = Quantity, %2 = AO No., %3 = Posted Assembly No.';
        CompletedTxt: Label 'Assembly Order %1 is fully completed.', Comment = '%1 = AO No.';

    /// <summary>
    /// Runs every posting step that has not completed yet, with outbound payloads suppressed.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Automated Transaction Processing)
    procedure PostEntry(var InboundEntry: Record "IP Filler Inbound Entry")
    var
        QuantitySynchronization: Codeunit "IP Quantity Synchronization";
        ScrapPosting: Codeunit "IP Scrap Posting";
    begin
        Context.SetSuppressOutbound(true);

        if not InboundEntry."Quantities Synchronized" then begin
            QuantitySynchronization.ApplyOverage(InboundEntry);
            InboundEntry."Quantities Synchronized" := true;
            InboundEntry.Modify();
            Commit();
        end;

        if not InboundEntry."Receipt Posted" then begin
            PostPurchaseReceipt(InboundEntry);
            InboundEntry."Receipt Posted" := true;
            InboundEntry.Modify();
            Commit();
        end;

        if not InboundEntry."Output Posted" then begin
            PostAssemblyOutput(InboundEntry);
            InboundEntry."Output Posted" := true;
            InboundEntry.Modify();
            Commit();
        end;

        if not InboundEntry."Scrap Posted" then begin
            ScrapPosting.PostScrap(InboundEntry);
            InboundEntry."Scrap Posted" := true;
            InboundEntry.Modify();
            Commit();
        end;

        Context.SetSuppressOutbound(false);
    end;

    /// <summary>
    /// Posts the Purchase Order receipt for the authoritative inbound quantity. Only the linked
    /// Fill Item line is received, and the PO is not invoiced. No warehouse documents are used.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 Purchase Order Receipt Processing & Production Synchronization (5) Automatically posts the Purchase Order receipt
    local procedure PostPurchaseReceipt(var InboundEntry: Record "IP Filler Inbound Entry")
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        OtherPurchaseLine: Record "Purchase Line";
        PurchPost: Codeunit "Purch.-Post";
    begin
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, InboundEntry."Purchase Order No.");

        OtherPurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        OtherPurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        OtherPurchaseLine.SetFilter("Line No.", '<>%1', InboundEntry."Purchase Order Line No.");
        OtherPurchaseLine.SetFilter("Qty. to Receive", '<>0');
        if OtherPurchaseLine.FindSet(true) then
            repeat
                OtherPurchaseLine.Validate("Qty. to Receive", 0);
                OtherPurchaseLine.Modify(true);
            until OtherPurchaseLine.Next() = 0;

        PurchaseLine.Get(PurchaseHeader."Document Type", PurchaseHeader."No.", InboundEntry."Purchase Order Line No.");
        PurchaseLine.Validate("Qty. to Receive", InboundEntry."Completed Quantity");
        PurchaseLine.Modify(true);

        PurchaseHeader.Get(PurchaseHeader."Document Type", PurchaseHeader."No.");
        PurchaseHeader.Validate("Posting Date", GetPostingDate(InboundEntry));
        PurchaseHeader."Vendor Shipment No." := CopyStr(InboundEntry."Message ID", 1, MaxStrLen(PurchaseHeader."Vendor Shipment No."));
        PurchaseHeader.Receive := true;
        PurchaseHeader.Invoice := false;
        PurchaseHeader.Ship := false;
        PurchaseHeader.Modify(true);

        PurchPost.Run(PurchaseHeader);

        InboundEntry."Posted Receipt No." := PurchaseHeader."Last Receiving No.";
        LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"PO Receipt", "IP Integration Status"::Success,
            StrSubstNo(ReceiptPostedTxt, PurchaseHeader."Last Receiving No.", InboundEntry."Completed Quantity", PurchaseHeader."No."), '');
    end;

    /// <summary>
    /// Posts the Assembly Order output and component consumption for the current completed
    /// quantity only (partial, repeated, full or overage). Before standard posting validation,
    /// the ADO 1507 phantom lot is assigned to that quantity. Filler Status then becomes
    /// Partially Completed, or Completed when the AO is fully posted.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.4 (6)(7) Assembly output and component consumption / 5.8 Partial Completion Processing / 5.10 Phantom Lot Assignment
    local procedure PostAssemblyOutput(var InboundEntry: Record "IP Filler Inbound Entry")
    var
        AssemblyHeader: Record "Assembly Header";
        PostedAssemblyHeader: Record "Posted Assembly Header";
        PhantomLotMgt: Codeunit "IP Phantom Lot Mgt";
        AssemblyPost: Codeunit "Assembly-Post";
    begin
        AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, InboundEntry."Assembly Order No.");
        AssemblyHeader.Validate("Posting Date", GetPostingDate(InboundEntry));
        AssemblyHeader.Validate("Quantity to Assemble", InboundEntry."Completed Quantity");
        AssemblyHeader.Modify(true);

        PhantomLotMgt.AssignPhantomLot(AssemblyHeader, InboundEntry);

        AssemblyPost.Run(AssemblyHeader);

        PostedAssemblyHeader.SetRange("Order No.", InboundEntry."Assembly Order No.");
        if PostedAssemblyHeader.FindLast() then
            InboundEntry."Posted Assembly No." := PostedAssemblyHeader."No.";

        LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Assembly Output", "IP Integration Status"::Success,
            StrSubstNo(OutputPostedTxt, InboundEntry."Completed Quantity", InboundEntry."Assembly Order No.", InboundEntry."Posted Assembly No."), '');

        if AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, InboundEntry."Assembly Order No.") then
            LogMgt.UpdateFillerStatus(AssemblyHeader."No.", "IP Filler Status"::"Partially Completed")
        else
            LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Assembly Output", "IP Integration Status"::Success,
                StrSubstNo(CompletedTxt, InboundEntry."Assembly Order No."), '');
    end;

    /// <summary>
    /// Posting date for the inbound transaction: the payload posting date, or the work date.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
    local procedure GetPostingDate(InboundEntry: Record "IP Filler Inbound Entry"): Date
    begin
        if InboundEntry."Posting Date" <> 0D then
            exit(InboundEntry."Posting Date");
        exit(WorkDate());
    end;
}
