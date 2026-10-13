/// <summary>
/// Adds the AO-to-PO link fields to the Assembly Order: Linked Purchase Order No., Linked
/// Purchase Order Line No., Filler Status, BOM Sent Date and the read-only Linked PO Released flag.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.1 Assembly Order Creation / 5.2 Create PO Link Function
tableextension 50100 "IP Assembly Header" extends "Assembly Header"
{
    fields
    {
        field(50100; "IP Linked Purch. Order No."; Code[20])
        {
            Caption = 'Linked Purchase Order No.';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Purchase Header"."No." where("Document Type" = const(Order));
        }
        field(50101; "IP Linked Purch. Line No."; Integer)
        {
            Caption = 'Linked Purchase Order Line No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50102; "IP Filler Status"; Enum "IP Filler Status")
        {
            Caption = 'Filler Status';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50103; "IP BOM Sent Date"; Date)
        {
            Caption = 'BOM Sent Date';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50104; "IP Linked PO Released"; Boolean)
        {
            Caption = 'Linked PO Released';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = exist("Purchase Header" where("Document Type" = const(Order),
                                                        "No." = field("IP Linked Purch. Order No."),
                                                        Status = const(Released)));
        }
        field(50105; "IP Filler Vendor No."; Code[20])
        {
            Caption = 'Filler Vendor No.';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = Vendor;
        }
        field(50106; "IP Integration Rel. ID"; Guid)
        {
            Caption = 'Integration Relationship ID';
            DataClassification = SystemMetadata;
            Editable = false;
        }
        field(50107; "IP Last BOM Hash"; Text[100])
        {
            Caption = 'Last BOM Payload Hash';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }

    keys
    {
        key(IPLinkedPO; "IP Linked Purch. Order No.")
        {
        }
    }
}
