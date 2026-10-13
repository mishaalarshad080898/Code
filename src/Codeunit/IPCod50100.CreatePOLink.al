/// <summary>
/// Create PO Link function on the Assembly Order. Creates the linked Purchase Order with one
/// Fill Item line, sets up the integration relationship records on both documents, writes the
/// Activity Log and releases the PO automatically. The PO release then triggers the outbound
/// production request (see IP Purchase Order Events).
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function / 5.3 Purchase Order Creation
codeunit 50100 "IP Create PO Link"
{
    TableNo = "Assembly Header";

    trigger OnRun()
    begin
        CreatePOLink(Rec);
    end;

    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        AlreadyLinkedErr: Label 'Assembly Order %1 is already linked to Purchase Order %2.', Comment = '%1 = Assembly Order No., %2 = Purchase Order No.';
        NoFillerSetupErr: Label 'Location %1 on Assembly Order %2 is not set up as an integration-enabled filler location in Filler Integration Setup.', Comment = '%1 = Location Code, %2 = Assembly Order No.';
        NoFillItemErr: Label 'Assembly Order %1 has no Fill Item line. Add the filling service item (Item with Fill Item = Yes) to the Assembly Order lines.', Comment = '%1 = Assembly Order No.';
        MultipleFillItemsErr: Label 'Assembly Order %1 has more than one Fill Item line. Only one Fill Item line is allowed (1 Purchase Order = 1 Fill Item line).', Comment = '%1 = Assembly Order No.';
        LinkCreatedTxt: Label 'Purchase Order %1 created and linked to Assembly Order %2.', Comment = '%1 = Purchase Order No., %2 = Assembly Order No.';
        LinkCreatedMsg: Label 'Purchase Order %1 has been created, linked and released.', Comment = '%1 = Purchase Order No.';

    /// <summary>
    /// Runs the Create PO Link function for an Assembly Order.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function
    procedure CreatePOLink(var AssemblyHeader: Record "Assembly Header")
    var
        FillerSetup: Record "IP Filler Integration Setup";
        FillAssemblyLine: Record "Assembly Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ReleasePurchaseDocument: Codeunit "Release Purchase Document";
        RelationshipID: Guid;
    begin
        CheckFunctionAvailability(AssemblyHeader);
        GetFillerSetup(AssemblyHeader, FillerSetup);
        FindFillItemLine(AssemblyHeader, FillAssemblyLine);

        RelationshipID := CreateGuid();
        CreatePurchaseOrder(AssemblyHeader, FillerSetup, FillAssemblyLine, RelationshipID, PurchaseHeader, PurchaseLine);
        LinkAssemblyOrder(AssemblyHeader, FillerSetup, PurchaseLine, RelationshipID);

        LogMgt.LogEvent("IP Integration Direction"::Internal, "IP Integration Event Type"::"Create PO Link", "IP Integration Status"::Success,
            FillerSetup."Vendor No.", AssemblyHeader."No.", PurchaseHeader."No.", PurchaseLine."Line No.",
            StrSubstNo(LinkCreatedTxt, PurchaseHeader."No.", AssemblyHeader."No."), '');

        // Purchase Orders are automatically released; the release triggers the outbound production request.
        ReleasePurchaseDocument.Run(PurchaseHeader);
        AssemblyHeader.Get(AssemblyHeader."Document Type", AssemblyHeader."No.");

        if GuiAllowed() then
            Message(LinkCreatedMsg, PurchaseHeader."No.");
    end;

    /// <summary>
    /// Function availability rules: AO Status = Open and no linked PO exists yet.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function (Function availability rules)
    procedure CheckFunctionAvailability(AssemblyHeader: Record "Assembly Header")
    begin
        AssemblyHeader.TestField("Document Type", AssemblyHeader."Document Type"::Order);
        AssemblyHeader.TestField(Status, AssemblyHeader.Status::Open);
        AssemblyHeader.TestField("Item No.");
        AssemblyHeader.TestField(Quantity);
        if AssemblyHeader."IP Linked Purch. Order No." <> '' then
            Error(AlreadyLinkedErr, AssemblyHeader."No.", AssemblyHeader."IP Linked Purch. Order No.");
    end;

    /// <summary>
    /// Finds the integration-enabled filler for the Assembly Order location.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    local procedure GetFillerSetup(AssemblyHeader: Record "Assembly Header"; var FillerSetup: Record "IP Filler Integration Setup")
    begin
        if not FillerSetup.GetEnabledByLocation(AssemblyHeader."Location Code") then
            Error(NoFillerSetupErr, AssemblyHeader."Location Code", AssemblyHeader."No.");
    end;

    /// <summary>
    /// Finds the single Fill Item line on the Assembly Order. Its quantity per must be 1, so the
    /// PO quantity mirrors the AO quantity one to one.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation (1 Purchase Order = 1 Fill Item line)
    procedure FindFillItemLine(AssemblyHeader: Record "Assembly Header"; var FillAssemblyLine: Record "Assembly Line")
    var
        AssemblyLine: Record "Assembly Line";
        Item: Record Item;
        Found: Boolean;
    begin
        AssemblyLine.SetRange("Document Type", AssemblyHeader."Document Type");
        AssemblyLine.SetRange("Document No.", AssemblyHeader."No.");
        AssemblyLine.SetRange(Type, AssemblyLine.Type::Item);
        if AssemblyLine.FindSet() then
            repeat
                if Item.Get(AssemblyLine."No.") then
                    if Item."IP Fill Item" then begin
                        if Found then
                            Error(MultipleFillItemsErr, AssemblyHeader."No.");
                        FillAssemblyLine := AssemblyLine;
                        Found := true;
                    end;
            until AssemblyLine.Next() = 0;

        if not Found then
            Error(NoFillItemErr, AssemblyHeader."No.");
        FillAssemblyLine.TestField("Quantity per", 1);
    end;

    /// <summary>
    /// Creates the Purchase Order header for the filler vendor and location, with one Fill Item
    /// line whose quantity equals the Assembly Order quantity, plus the linked AO reference and
    /// integration relationship identifiers.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation
    local procedure CreatePurchaseOrder(AssemblyHeader: Record "Assembly Header"; FillerSetup: Record "IP Filler Integration Setup"; FillAssemblyLine: Record "Assembly Line"; RelationshipID: Guid; var PurchaseHeader: Record "Purchase Header"; var PurchaseLine: Record "Purchase Line")
    begin
        PurchaseHeader.Init();
        PurchaseHeader."Document Type" := PurchaseHeader."Document Type"::Order;
        PurchaseHeader."No." := '';
        PurchaseHeader.Insert(true);
        PurchaseHeader.Validate("Buy-from Vendor No.", FillerSetup."Vendor No.");
        PurchaseHeader.Validate("Order Date", WorkDate());
        PurchaseHeader.Validate("Location Code", FillerSetup."Filler Location Code");
        if AssemblyHeader."Due Date" <> 0D then
            PurchaseHeader.Validate("Expected Receipt Date", AssemblyHeader."Due Date");
        PurchaseHeader."IP Linked Assembly Order No." := AssemblyHeader."No.";
        PurchaseHeader."IP Filler Integration" := true;
        PurchaseHeader."IP Integration Rel. ID" := RelationshipID;
        PurchaseHeader.Modify(true);

        PurchaseLine.Init();
        PurchaseLine."Document Type" := PurchaseHeader."Document Type";
        PurchaseLine."Document No." := PurchaseHeader."No.";
        PurchaseLine."Line No." := 10000;
        PurchaseLine.Validate(Type, PurchaseLine.Type::Item);
        PurchaseLine.Validate("No.", FillAssemblyLine."No.");
        if FillAssemblyLine."Variant Code" <> '' then
            PurchaseLine.Validate("Variant Code", FillAssemblyLine."Variant Code");
        PurchaseLine.Validate("Location Code", FillerSetup."Filler Location Code");
        PurchaseLine.Validate("Unit of Measure Code", FillAssemblyLine."Unit of Measure Code");
        PurchaseLine.Validate(Quantity, AssemblyHeader.Quantity);
        // Link fields are set after the quantity so the PO-to-AO quantity sync is not triggered on creation.
        PurchaseLine."IP Linked Assembly Order No." := AssemblyHeader."No.";
        PurchaseLine."IP Integration Rel. ID" := RelationshipID;
        PurchaseLine.Insert(true);
    end;

    /// <summary>
    /// Writes the link fields (Linked PO No., Linked PO Line No., vendor, relationship ID, Filler
    /// Status = Linked) onto the Assembly Order.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.1 Assembly Order Creation / 5.2 Create PO Link Function (Establishes integration relationship records)
    local procedure LinkAssemblyOrder(var AssemblyHeader: Record "Assembly Header"; FillerSetup: Record "IP Filler Integration Setup"; PurchaseLine: Record "Purchase Line"; RelationshipID: Guid)
    begin
        AssemblyHeader."IP Linked Purch. Order No." := PurchaseLine."Document No.";
        AssemblyHeader."IP Linked Purch. Line No." := PurchaseLine."Line No.";
        AssemblyHeader."IP Filler Vendor No." := FillerSetup."Vendor No.";
        AssemblyHeader."IP Integration Rel. ID" := RelationshipID;
        AssemblyHeader."IP Filler Status" := AssemblyHeader."IP Filler Status"::Linked;
        AssemblyHeader."IP Last BOM Hash" := '';
        AssemblyHeader."IP BOM Sent Date" := 0D;
        AssemblyHeader.Modify();
    end;
}
