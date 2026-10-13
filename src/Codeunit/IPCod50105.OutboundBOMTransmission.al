/// <summary>
/// Outbound BOM transmission. On Assembly Order release, sends the AO component lines
/// (components, quantities, linked PO No.), excluding the Fill Item line. A re-release resends
/// only when the BOM changed. "Resend BOM to Filler" always resends. Every send is logged
/// and payload history is retained.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission
codeunit 50105 "IP Outbound BOM Transmission"
{
    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        Transport: Codeunit "IP Filler Transport";
        MessageTypeTok: Label 'BOM', Locked = true;
        SentDescTxt: Label 'BOM (AO lines) sent for Assembly Order %1, linked PO %2.', Comment = '%1 = AO No., %2 = PO No.';
        UnchangedTxt: Label 'Assembly Order %1 re-released without BOM changes. BOM not resent.', Comment = '%1 = AO No.';
        NotLinkedErr: Label 'Assembly Order %1 is not linked to a filler Purchase Order.', Comment = '%1 = AO No.';
        FillerDisabledErr: Label 'Integration is not enabled for filler %1.', Comment = '%1 = Vendor No.';
        ResendConfirmQst: Label 'Resend the BOM for Assembly Order %1 to the filler?', Comment = '%1 = AO No.';
        ResentMsg: Label 'The BOM was resent to the filler.';
        ResendFailedMsg: Label 'The BOM could not be sent. See the Filler Integration Activity Log for details.';

    /// <summary>
    /// Entry point from the AO release event. Sends the BOM only if it has not been sent yet or
    /// has changed since the last successful send.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission (Re-release only resends if BOM changed) / 5.14 Outbound Trigger Points (AO Release)
    procedure SendOnRelease(var AssemblyHeader: Record "Assembly Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        ComponentsText: Text;
        BOMHash: Text;
    begin
        if AssemblyHeader."IP Linked Purch. Order No." = '' then
            exit;
        if not FillerSetup.Get(AssemblyHeader."IP Filler Vendor No.") then
            exit;
        if not FillerSetup."Integration Enabled" then
            exit;

        ComponentsText := BuildComponents(AssemblyHeader);
        BOMHash := CalculateHash(AssemblyHeader, ComponentsText);
        if (AssemblyHeader."IP Last BOM Hash" <> '') and (AssemblyHeader."IP Last BOM Hash" = BOMHash) then begin
            LogMgt.LogEvent("IP Integration Direction"::Outbound, "IP Integration Event Type"::"BOM Transmission", "IP Integration Status"::Skipped,
                FillerSetup."Vendor No.", AssemblyHeader."No.", AssemblyHeader."IP Linked Purch. Order No.", AssemblyHeader."IP Linked Purch. Line No.",
                StrSubstNo(UnchangedTxt, AssemblyHeader."No."), '');
            exit;
        end;
        SendBOM(AssemblyHeader, FillerSetup, "IP Integration Event Type"::"BOM Transmission", ComponentsText, BOMHash);
    end;

    /// <summary>
    /// Manual "Resend BOM to Filler" function. Always resends the current AO lines and logs a
    /// BOM Resend entry.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission (Manual Resend BOM to Filler function supported)
    procedure ResendBOM(var AssemblyHeader: Record "Assembly Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        ComponentsText: Text;
    begin
        if AssemblyHeader."IP Linked Purch. Order No." = '' then
            Error(NotLinkedErr, AssemblyHeader."No.");
        AssemblyHeader.TestField(Status, AssemblyHeader.Status::Released);
        FillerSetup.Get(AssemblyHeader."IP Filler Vendor No.");
        if not FillerSetup."Integration Enabled" then
            Error(FillerDisabledErr, FillerSetup."Vendor No.");
        if GuiAllowed() then
            if not Confirm(ResendConfirmQst, true, AssemblyHeader."No.") then
                exit;

        ComponentsText := BuildComponents(AssemblyHeader);
        if SendBOM(AssemblyHeader, FillerSetup, "IP Integration Event Type"::"BOM Resend", ComponentsText, CalculateHash(AssemblyHeader, ComponentsText)) then begin
            if GuiAllowed() then
                Message(ResentMsg);
        end else
            if GuiAllowed() then
                Message(ResendFailedMsg);
    end;

    /// <summary>
    /// Builds the BOM payload, sends it, and on success stamps BOM Sent Date, the BOM hash and
    /// Filler Status = BOM Sent on the Assembly Order.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission
    local procedure SendBOM(var AssemblyHeader: Record "Assembly Header"; FillerSetup: Record "IP Filler Integration Setup"; EventType: Enum "IP Integration Event Type"; ComponentsText: Text; BOMHash: Text): Boolean
    var
        Payload: JsonObject;
        Components: JsonArray;
        MessageID: Text;
        PayloadText: Text;
    begin
        MessageID := Format(CreateGuid(), 0, 4);
        Components.ReadFrom(ComponentsText);

        Payload.Add('messageType', MessageTypeTok);
        Payload.Add('messageId', MessageID);
        Payload.Add('vendorNo', FillerSetup."Vendor No.");
        Payload.Add('poNo', AssemblyHeader."IP Linked Purch. Order No.");
        Payload.Add('poLineNo', AssemblyHeader."IP Linked Purch. Line No.");
        Payload.Add('assemblyOrderNo', AssemblyHeader."No.");
        Payload.Add('integrationRelationshipId', Format(AssemblyHeader."IP Integration Rel. ID", 0, 4));
        Payload.Add('fgItemNo', AssemblyHeader."Item No.");
        Payload.Add('fgQuantity', AssemblyHeader.Quantity);
        Payload.Add('components', Components);
        Payload.WriteTo(PayloadText);

        if Transport.SendAndLog(FillerSetup, EventType, AssemblyHeader."No.", AssemblyHeader."IP Linked Purch. Order No.", AssemblyHeader."IP Linked Purch. Line No.",
            MessageID, PayloadText, BOMHash, 0, StrSubstNo(SentDescTxt, AssemblyHeader."No.", AssemblyHeader."IP Linked Purch. Order No."))
        then begin
            AssemblyHeader."IP BOM Sent Date" := Today();
            AssemblyHeader."IP Last BOM Hash" := CopyStr(BOMHash, 1, MaxStrLen(AssemblyHeader."IP Last BOM Hash"));
            if AssemblyHeader."IP Filler Status" in [AssemblyHeader."IP Filler Status"::" ", AssemblyHeader."IP Filler Status"::Linked,
                                                     AssemblyHeader."IP Filler Status"::"Production Request Sent", AssemblyHeader."IP Filler Status"::Exception]
            then
                AssemblyHeader."IP Filler Status" := AssemblyHeader."IP Filler Status"::"BOM Sent";
            AssemblyHeader.Modify();
            exit(true);
        end;

        AssemblyHeader."IP Filler Status" := AssemblyHeader."IP Filler Status"::Exception;
        AssemblyHeader.Modify();
        exit(false);
    end;

    /// <summary>
    /// Builds the component array from the AO item lines. The Fill Item component is excluded
    /// from the payload.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission (The Fill Item component is excluded from the payload)
    local procedure BuildComponents(AssemblyHeader: Record "Assembly Header"): Text
    var
        AssemblyLine: Record "Assembly Line";
        Item: Record Item;
        Components: JsonArray;
        ComponentsText: Text;
    begin
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.SetRange(Type, AssemblyLine.Type::Item);
        if AssemblyLine.FindSet() then
            repeat
                if not IsFillItem(AssemblyLine."No.", Item) then
                    Components.Add(BuildComponent(AssemblyLine));
            until AssemblyLine.Next() = 0;
        Components.WriteTo(ComponentsText);
        exit(ComponentsText);
    end;

    /// <summary>
    /// Builds one component entry: item, quantity per, total quantity and unit of measure.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission (BOM components / Component quantities)
    local procedure BuildComponent(AssemblyLine: Record "Assembly Line"): JsonObject
    var
        Component: JsonObject;
    begin
        Component.Add('lineNo', AssemblyLine."Line No.");
        Component.Add('itemNo', AssemblyLine."No.");
        Component.Add('variantCode', AssemblyLine."Variant Code");
        Component.Add('description', AssemblyLine.Description);
        Component.Add('quantityPer', AssemblyLine."Quantity per");
        Component.Add('quantity', AssemblyLine.Quantity);
        Component.Add('unitOfMeasure', AssemblyLine."Unit of Measure Code");
        Component.Add('locationCode', AssemblyLine."Location Code");
        exit(Component);
    end;

    /// <summary>
    /// Returns true when the item is flagged as the Fill Item.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission
    local procedure IsFillItem(ItemNo: Code[20]; var Item: Record Item): Boolean
    begin
        if not Item.Get(ItemNo) then
            exit(false);
        exit(Item."IP Fill Item");
    end;

    /// <summary>
    /// Calculates a SHA-256 hash over the BOM content (linked PO, FG quantity and components).
    /// A re-release compares it with the last sent hash to detect a BOM change.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission (Re-release only resends if BOM changed)
    local procedure CalculateHash(AssemblyHeader: Record "Assembly Header"; ComponentsText: Text): Text
    var
        CryptographyManagement: Codeunit "Cryptography Management";
        HashAlgorithmType: Option MD5,SHA1,SHA256,SHA384,SHA512;
    begin
        exit(CryptographyManagement.GenerateHash(
            AssemblyHeader."IP Linked Purch. Order No." + '|' + Format(AssemblyHeader.Quantity, 0, 9) + '|' + ComponentsText,
            HashAlgorithmType::SHA256));
    end;
}
