/// <summary>
/// Adds the linked Assembly Order reference and the integration relationship identifiers to
/// the Purchase Order, plus the production request transmission state.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation / 5.6 Outbound Production Request Processing
tableextension 50102 "IP Purchase Header" extends "Purchase Header"
{
    fields
    {
        field(50100; "IP Linked Assembly Order No."; Code[20])
        {
            Caption = 'Linked Assembly Order No.';
            DataClassification = CustomerContent;
            Editable = false;
            TableRelation = "Assembly Header"."No." where("Document Type" = const(Order));
        }
        field(50101; "IP Filler Integration"; Boolean)
        {
            Caption = 'Filler Integration';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50102; "IP Prod. Request Sent"; Boolean)
        {
            Caption = 'Production Request Sent';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50103; "IP Prod. Request Sent Qty"; Decimal)
        {
            Caption = 'Production Request Sent Qty.';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(50104; "IP Integration Rel. ID"; Guid)
        {
            Caption = 'Integration Relationship ID';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }
}
