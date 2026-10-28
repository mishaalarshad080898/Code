/// <summary>
/// Builds and sends the ICR order message (interface 3.1 PO/TO/ProdPO) for production POs (filler
/// POs linked to an Assembly Order), purchase orders delivered to a filler location and transfer
/// orders shipped to a filler location. Covers the Create, Update and Delete scenarios:
/// first send = Create; a later send = Update (lines removed since the last message are resent
/// with loekz = 'X'); document deleted = Delete (all lines sent with loekz = 'X').
/// Every message is logged with its payload; the last successful message of a document is the
/// reference for the next Update / Delete.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO
codeunit 50115 "IP ICR Order Message"
{
    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        Transport: Codeunit "IP Filler Transport";
        LastFailureText: Text;
        FlagTok: Label 'X', Locked = true;
        DateFormatTok: Label '<Year4><Month,2><Day,2>', Locked = true;
        CreateTxt: Label 'Create';
        UpdateTxt: Label 'Update';
        DeleteTxt: Label 'Delete';
        SentDescTxt: Label '%1 message for %2 %3.', Comment = '%1 = Create/Update/Delete, %2 = Document type, %3 = Document No.';
        UnchangedTxt: Label '%1 %2 released again without changes. Order message not resent.', Comment = '%1 = Document type, %2 = Document No.';

    /// <summary>
    /// Sends the Create / Update message for a purchase order (production PO or a PO delivered to a
    /// filler location). Returns true when the message was accepted, was not needed (not a filler
    /// document) or was skipped because nothing changed; false only when the send failed.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Scenarios in scope: Create, Update)
    procedure SendPurchaseOrder(PurchaseHeader: Record "Purchase Header"): Boolean
    var
        FillerSetup: Record "IP Filler Integration Setup";
        Header: JsonObject;
        Items: JsonArray;
        DocType: Enum "IP Integration Doc. Type";
    begin
        LastFailureText := '';
        if not FindPurchaseFillerSetup(PurchaseHeader, FillerSetup) then
            exit(true);
        DocType := GetPurchaseDocType(PurchaseHeader);
        Header := BuildHeader(FillerSetup, PurchaseHeader."No.", GetOrderType(FillerSetup, DocType), PurchaseHeader."Buy-from Vendor No.");
        BuildPurchaseItems(PurchaseHeader, FillerSetup, Items);
        exit(SendOrder(FillerSetup, DocType, PurchaseHeader."No.", PurchaseHeader."IP Linked Assembly Order No.", Header, Items));
    end;

    /// <summary>
    /// Sends the Delete message for a purchase order that was sent to the filler before. Not sent
    /// when the PO was never sent, or when it is fully received (deleted after posting).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Scenarios in scope: Delete / loekz)
    procedure SendPurchaseOrderDeletion(PurchaseHeader: Record "Purchase Header"): Boolean
    var
        FillerSetup: Record "IP Filler Integration Setup";
    begin
        LastFailureText := '';
        if not FindPurchaseFillerSetup(PurchaseHeader, FillerSetup) then
            exit(true);
        if IsPurchaseOrderCompleted(PurchaseHeader) then
            exit(true);
        exit(SendDeletion(FillerSetup, GetPurchaseDocType(PurchaseHeader), PurchaseHeader."No.", PurchaseHeader."IP Linked Assembly Order No."));
    end;

    /// <summary>
    /// Sends the Create / Update message for a transfer order shipped to a filler location.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Scenarios in scope: Create, Update)
    procedure SendTransferOrder(TransferHeader: Record "Transfer Header"): Boolean
    var
        FillerSetup: Record "IP Filler Integration Setup";
        Header: JsonObject;
        Items: JsonArray;
    begin
        LastFailureText := '';
        if not FillerSetup.GetEnabledByLocation(TransferHeader."Transfer-to Code") then
            exit(true);
        Header := BuildHeader(FillerSetup, TransferHeader."No.", FillerSetup."Transfer Order Type", GetTransferSupplierCode(TransferHeader));
        BuildTransferItems(TransferHeader, FillerSetup, Items);
        exit(SendOrder(FillerSetup, "IP Integration Doc. Type"::"Transfer Order", TransferHeader."No.", '', Header, Items));
    end;

    /// <summary>
    /// Sends the Delete message for a transfer order that was sent to the filler before. Not sent
    /// when the TO was never sent, or when it is fully received (deleted after posting).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Scenarios in scope: Delete / loekz)
    procedure SendTransferOrderDeletion(TransferHeader: Record "Transfer Header"): Boolean
    var
        FillerSetup: Record "IP Filler Integration Setup";
    begin
        LastFailureText := '';
        if not FillerSetup.GetEnabledByLocation(TransferHeader."Transfer-to Code") then
            exit(true);
        if IsTransferOrderCompleted(TransferHeader) then
            exit(true);
        exit(SendDeletion(FillerSetup, "IP Integration Doc. Type"::"Transfer Order", TransferHeader."No.", ''));
    end;

    /// <summary>
    /// Returns the reason of the last failed send.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (2) Payload failures can occur
    procedure GetLastFailureText(): Text
    begin
        exit(LastFailureText);
    end;

    /// <summary>
    /// Create / Update: compares with the last successful message of the document. Lines that were
    /// sent before but no longer exist are added with loekz = 'X'. An unchanged document is not resent.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Create, Update)
    local procedure SendOrder(FillerSetup: Record "IP Filler Integration Setup"; DocType: Enum "IP Integration Doc. Type"; DocNo: Code[20]; AssemblyOrderNo: Code[20]; Header: JsonObject; Items: JsonArray): Boolean
    var
        Root: JsonObject;
        LastPayloadText: Text;
        PayloadText: Text;
        IsUpdate: Boolean;
    begin
        LastPayloadText := GetLastSentPayload(DocType, DocNo);
        IsUpdate := LastPayloadText <> '';
        if IsUpdate then
            AddRemovedLines(Items, LastPayloadText);

        Header.Add('item', Items);
        Root.Add('header', Header);
        Root.WriteTo(PayloadText);

        if IsUpdate and (PayloadText = LastPayloadText) then begin
            LogMgt.LogEvent("IP Integration Direction"::Outbound, GetEventType(DocType), "IP Integration Status"::Skipped,
                FillerSetup."Vendor No.", AssemblyOrderNo, GetPurchaseOrderNo(DocType, DocNo), 0, StrSubstNo(UnchangedTxt, DocType, DocNo), '');
            exit(true);
        end;

        if IsUpdate then
            exit(SendAndLogDocument(FillerSetup, DocType, DocNo, AssemblyOrderNo, PayloadText, UpdateTxt));
        exit(SendAndLogDocument(FillerSetup, DocType, DocNo, AssemblyOrderNo, PayloadText, CreateTxt));
    end;

    /// <summary>
    /// Delete: resends the last successful message of the document with loekz = 'X' on every line.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Delete - loekz Marked for deletion)
    local procedure SendDeletion(FillerSetup: Record "IP Filler Integration Setup"; DocType: Enum "IP Integration Doc. Type"; DocNo: Code[20]; AssemblyOrderNo: Code[20]): Boolean
    var
        Root: JsonObject;
        Header: JsonObject;
        Token: JsonToken;
        ItemToken: JsonToken;
        Item: JsonObject;
        LastItems: JsonArray;
        LastPayloadText: Text;
        PayloadText: Text;
    begin
        LastPayloadText := GetLastSentPayload(DocType, DocNo);
        if LastPayloadText = '' then
            exit(true);
        if not Root.ReadFrom(LastPayloadText) then
            exit(true);
        if not Root.Get('header', Token) then
            exit(true);
        Header := Token.AsObject();
        if not Header.Get('item', Token) then
            exit(true);
        LastItems := Token.AsArray();
        foreach ItemToken in LastItems do begin
            Item := ItemToken.AsObject();
            Item.Replace('loekz', FlagTok);
        end;
        Root.WriteTo(PayloadText);
        if PayloadText = LastPayloadText then
            exit(true);
        exit(SendAndLogDocument(FillerSetup, DocType, DocNo, AssemblyOrderNo, PayloadText, DeleteTxt));
    end;

    /// <summary>
    /// Sends the payload, logs it with the document reference and keeps the failure reason.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points (Logged = Yes)
    local procedure SendAndLogDocument(FillerSetup: Record "IP Filler Integration Setup"; DocType: Enum "IP Integration Doc. Type"; DocNo: Code[20]; AssemblyOrderNo: Code[20]; PayloadText: Text; ActionText: Text): Boolean
    var
        IntegrationLog: Record "IP Filler Integration Log";
        LogEntryNo: Integer;
        Sent: Boolean;
    begin
        Sent := Transport.SendAndLog(FillerSetup, GetEventType(DocType), AssemblyOrderNo, GetPurchaseOrderNo(DocType, DocNo), 0,
            Format(CreateGuid(), 0, 4), PayloadText, '', 0, StrSubstNo(SentDescTxt, ActionText, DocType, DocNo), LogEntryNo);
        if IntegrationLog.Get(LogEntryNo) then begin
            IntegrationLog."Document Type" := DocType;
            IntegrationLog."Document No." := DocNo;
            IntegrationLog.Modify();
        end;
        if not Sent then
            LastFailureText := Transport.GetLastSendError();
        exit(Sent);
    end;

    /// <summary>
    /// Header part: ebeln, bukrs, bsart, lifnr, ekorg, ekgrp (defaults from Filler Integration Setup).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (header)
    local procedure BuildHeader(FillerSetup: Record "IP Filler Integration Setup"; DocNo: Code[20]; OrderType: Code[10]; SupplierCode: Code[20]): JsonObject
    var
        Header: JsonObject;
    begin
        Header.Add('ebeln', DocNo);
        Header.Add('bukrs', FillerSetup."ICR Company Code");
        Header.Add('bsart', OrderType);
        Header.Add('lifnr', SupplierCode);
        Header.Add('ekorg', FillerSetup."ICR Purch. Organization");
        Header.Add('ekgrp', FillerSetup."ICR Purch. Group");
        exit(Header);
    end;

    /// <summary>
    /// Item lines of a purchase order. Production PO: the finished good of the linked Assembly
    /// Order with the PO quantity and price. Other POs: the item lines delivered to the filler location.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (item)
    local procedure BuildPurchaseItems(PurchaseHeader: Record "Purchase Header"; FillerSetup: Record "IP Filler Integration Setup"; var Items: JsonArray)
    var
        PurchaseLine: Record "Purchase Line";
        AssemblyHeader: Record "Assembly Header";
        Completed: Boolean;
    begin
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        if PurchaseHeader."IP Filler Integration" then
            PurchaseLine.SetFilter("IP Linked Assembly Order No.", '<>%1', '')
        else
            PurchaseLine.SetRange("Location Code", FillerSetup."Filler Location Code");
        if PurchaseLine.FindSet() then
            repeat
                Completed := (PurchaseLine.Quantity <> 0) and (PurchaseLine."Quantity Received" >= PurchaseLine.Quantity);
                if PurchaseHeader."IP Filler Integration" and AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, PurchaseLine."IP Linked Assembly Order No.") then
                    AddItem(Items, FillerSetup, PurchaseLine."Line No.", AssemblyHeader.Description, AssemblyHeader."Item No.", PurchaseLine.Quantity,
                        AssemblyHeader."Unit of Measure Code", PurchaseLine."Direct Unit Cost", PurchaseLine."Expected Receipt Date", Completed)
                else
                    AddItem(Items, FillerSetup, PurchaseLine."Line No.", PurchaseLine.Description, PurchaseLine."No.", PurchaseLine.Quantity,
                        PurchaseLine."Unit of Measure Code", PurchaseLine."Direct Unit Cost", PurchaseLine."Expected Receipt Date", Completed);
            until PurchaseLine.Next() = 0;
    end;

    /// <summary>
    /// Item lines of a transfer order (shipment-derived lines excluded). Price = item unit cost.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (item)
    local procedure BuildTransferItems(TransferHeader: Record "Transfer Header"; FillerSetup: Record "IP Filler Integration Setup"; var Items: JsonArray)
    var
        TransferLine: Record "Transfer Line";
        Item: Record Item;
        UnitCost: Decimal;
        Completed: Boolean;
    begin
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        TransferLine.SetFilter("Item No.", '<>%1', '');
        if TransferLine.FindSet() then
            repeat
                UnitCost := 0;
                if Item.Get(TransferLine."Item No.") then
                    UnitCost := Item."Unit Cost";
                Completed := (TransferLine.Quantity <> 0) and (TransferLine."Quantity Received" >= TransferLine.Quantity);
                AddItem(Items, FillerSetup, TransferLine."Line No.", TransferLine.Description, TransferLine."Item No.", TransferLine.Quantity,
                    TransferLine."Unit of Measure Code", UnitCost, TransferLine."Receipt Date", Completed);
            until TransferLine.Next() = 0;
    end;

    /// <summary>
    /// One item line: ebelp, loekz, txt01, matnr, werks, matkl, menge, meins, netpr, wepos, eindt
    /// (YYYYMMDD), idlnf, elikz ('X' when fully received), banfn, bnfpo. "Leave empty" fields are sent blank.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (item fields)
    local procedure AddItem(var Items: JsonArray; FillerSetup: Record "IP Filler Integration Setup"; LineNo: Integer; Description: Text; ItemNo: Code[20]; Quantity: Decimal; UnitOfMeasureCode: Code[10]; UnitPrice: Decimal; DeliveryDate: Date; DeliveryCompleted: Boolean)
    var
        Item: JsonObject;
    begin
        Item.Add('ebelp', Format(LineNo, 0, 9));
        Item.Add('loekz', '');
        Item.Add('txt01', Description);
        Item.Add('matnr', ItemNo);
        Item.Add('werks', FillerSetup."ICR Plant");
        Item.Add('matkl', '');
        Item.Add('menge', Quantity);
        Item.Add('meins', UnitOfMeasureCode);
        Item.Add('netpr', UnitPrice);
        Item.Add('wepos', '');
        Item.Add('eindt', FormatDate(DeliveryDate));
        Item.Add('idlnf', '');
        if DeliveryCompleted then
            Item.Add('elikz', FlagTok)
        else
            Item.Add('elikz', '');
        Item.Add('banfn', '');
        Item.Add('bnfpo', '');
        Items.Add(Item);
    end;

    /// <summary>
    /// Update: adds the lines of the last message that no longer exist on the document, marked
    /// for deletion (loekz = 'X').
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (loekz - Update or Delete scenario)
    local procedure AddRemovedLines(var Items: JsonArray; LastPayloadText: Text)
    var
        LastRoot: JsonObject;
        LastHeader: JsonObject;
        LastItem: JsonObject;
        Token: JsonToken;
        ItemToken: JsonToken;
        LastItems: JsonArray;
        CurrentLineNos: List of [Text];
    begin
        foreach ItemToken in Items do
            CurrentLineNos.Add(GetText(ItemToken.AsObject(), 'ebelp'));

        if not LastRoot.ReadFrom(LastPayloadText) then
            exit;
        if not LastRoot.Get('header', Token) then
            exit;
        LastHeader := Token.AsObject();
        if not LastHeader.Get('item', Token) then
            exit;
        LastItems := Token.AsArray();
        foreach ItemToken in LastItems do begin
            LastItem := ItemToken.AsObject();
            if not CurrentLineNos.Contains(GetText(LastItem, 'ebelp')) then begin
                LastItem.Replace('loekz', FlagTok);
                Items.Add(LastItem.Clone());
            end;
        end;
    end;

    /// <summary>
    /// Returns the payload of the last successful order message sent for the document ('' if none).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Create vs Update)
    local procedure GetLastSentPayload(DocType: Enum "IP Integration Doc. Type"; DocNo: Code[20]): Text
    var
        IntegrationLog: Record "IP Filler Integration Log";
    begin
        IntegrationLog.SetCurrentKey("Document No.", "Document Type");
        IntegrationLog.SetRange("Document No.", DocNo);
        IntegrationLog.SetRange("Document Type", DocType);
        IntegrationLog.SetRange(Direction, IntegrationLog.Direction::Outbound);
        IntegrationLog.SetRange(Status, IntegrationLog.Status::Success);
        if not IntegrationLog.FindLast() then
            exit('');
        exit(IntegrationLog.GetPayload());
    end;

    /// <summary>
    /// Finds the filler a purchase order belongs to: the filler vendor of a production PO, or the
    /// filler whose location is the PO header location or any PO item line location.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    local procedure FindPurchaseFillerSetup(PurchaseHeader: Record "Purchase Header"; var FillerSetup: Record "IP Filler Integration Setup"): Boolean
    var
        PurchaseLine: Record "Purchase Line";
    begin
        if PurchaseHeader."Document Type" <> PurchaseHeader."Document Type"::Order then
            exit(false);
        if PurchaseHeader."IP Filler Integration" then begin
            if not FillerSetup.Get(PurchaseHeader."Buy-from Vendor No.") then
                exit(false);
            exit(FillerSetup."Integration Enabled");
        end;
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
    /// True when the PO is fully received, so its deletion is the normal end of the order and no
    /// Delete message is sent.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Delete)
    local procedure IsPurchaseOrderCompleted(PurchaseHeader: Record "Purchase Header"): Boolean
    var
        PurchaseLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
    begin
        PurchaseLine.SetRange("Document Type", PurchaseHeader."Document Type");
        PurchaseLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchaseLine.SetRange(Type, PurchaseLine.Type::Item);
        if PurchaseLine.IsEmpty() then begin
            PurchRcptHeader.SetRange("Order No.", PurchaseHeader."No.");
            exit(not PurchRcptHeader.IsEmpty());
        end;
        PurchaseLine.SetFilter("Outstanding Quantity", '<>0');
        exit(PurchaseLine.IsEmpty());
    end;

    /// <summary>
    /// True when the TO is fully received, so its deletion is the normal end of the order and no
    /// Delete message is sent.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Delete)
    local procedure IsTransferOrderCompleted(TransferHeader: Record "Transfer Header"): Boolean
    var
        TransferLine: Record "Transfer Line";
        TransferReceiptHeader: Record "Transfer Receipt Header";
    begin
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetRange("Derived From Line No.", 0);
        TransferLine.SetFilter("Item No.", '<>%1', '');
        if not TransferLine.FindSet() then begin
            TransferReceiptHeader.SetRange("Transfer Order No.", TransferHeader."No.");
            exit(not TransferReceiptHeader.IsEmpty());
        end;
        repeat
            if TransferLine."Quantity Received" < TransferLine.Quantity then
                exit(false);
        until TransferLine.Next() = 0;
        exit(true);
    end;

    /// <summary>
    /// lifnr of a transfer order: the ICR Supplier Code of the transfer-from warehouse, or the
    /// location code when it is blank.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (lifnr - For transfers: derive from warehouse code)
    local procedure GetTransferSupplierCode(TransferHeader: Record "Transfer Header"): Code[20]
    var
        Location: Record Location;
    begin
        if Location.Get(TransferHeader."Transfer-from Code") then
            if Location."IP ICR Supplier Code" <> '' then
                exit(Location."IP ICR Supplier Code");
        exit(TransferHeader."Transfer-from Code");
    end;

    /// <summary>
    /// Production PO for filler POs linked to an Assembly Order, otherwise Purchase Order.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO
    local procedure GetPurchaseDocType(PurchaseHeader: Record "Purchase Header"): Enum "IP Integration Doc. Type"
    begin
        if PurchaseHeader."IP Filler Integration" then
            exit("IP Integration Doc. Type"::"Production PO");
        exit("IP Integration Doc. Type"::"Purchase Order");
    end;

    /// <summary>
    /// bsart (order type) per document type, from Filler Integration Setup.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (bsart - ZFER / ZRFE)
    local procedure GetOrderType(FillerSetup: Record "IP Filler Integration Setup"; DocType: Enum "IP Integration Doc. Type"): Code[10]
    begin
        case DocType of
            DocType::"Production PO":
                exit(FillerSetup."Prod. PO Order Type");
            DocType::"Transfer Order":
                exit(FillerSetup."Transfer Order Type");
            else
                exit(FillerSetup."Purch. Order Type");
        end;
    end;

    /// <summary>
    /// Activity Log event type per document type.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points
    local procedure GetEventType(DocType: Enum "IP Integration Doc. Type"): Enum "IP Integration Event Type"
    begin
        case DocType of
            DocType::"Production PO":
                exit("IP Integration Event Type"::"Production Request");
            DocType::"Transfer Order":
                exit("IP Integration Event Type"::"Transfer Order");
            else
                exit("IP Integration Event Type"::"Purchase Order");
        end;
    end;

    /// <summary>
    /// Purchase Order No. for the Activity Log (blank for transfer orders).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (5)
    local procedure GetPurchaseOrderNo(DocType: Enum "IP Integration Doc. Type"; DocNo: Code[20]): Code[20]
    begin
        if DocType = DocType::"Transfer Order" then
            exit('');
        exit(DocNo);
    end;

    /// <summary>
    /// Date as YYYYMMDD ('' for a blank date).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (eindt - YYYYMMDD format)
    local procedure FormatDate(DeliveryDate: Date): Text
    begin
        if DeliveryDate = 0D then
            exit('');
        exit(Format(DeliveryDate, 0, DateFormatTok));
    end;

    /// <summary>
    /// Reads a text property from a JSON object ('' when missing).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO
    local procedure GetText(JObject: JsonObject; KeyName: Text): Text
    var
        Token: JsonToken;
    begin
        if not JObject.Get(KeyName, Token) then
            exit('');
        if not Token.IsValue() then
            exit('');
        exit(Token.AsValue().AsText());
    end;
}
