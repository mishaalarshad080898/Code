/// <summary>
/// Keeps the AO-to-PO relationship on the Posted Assembly Order for audit traceability.
/// Field IDs match the Assembly Header extension so standard TransferFields carries the values.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.1 Operational Assumptions (2) One Assembly Order Links to One Purchase Order
tableextension 50101 "IP Posted Assembly Header" extends "Posted Assembly Header"
{
    fields
    {
        field(50100; "IP Linked Purch. Order No."; Code[20])
        {
            Caption = 'Linked Purchase Order No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50101; "IP Linked Purch. Line No."; Integer)
        {
            Caption = 'Linked Purchase Order Line No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50105; "IP Filler Vendor No."; Code[20])
        {
            Caption = 'Filler Vendor No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50106; "IP Integration Rel. ID"; Guid)
        {
            Caption = 'Integration Relationship ID';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }
}
