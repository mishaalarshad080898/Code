/// <summary>
/// Adds the linked Assembly Order reference and integration relationship ID to the single
/// Fill Item line of a filler Purchase Order.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation (1 Purchase Order = 1 Fill Item line)
tableextension 50103 "IP Purchase Line" extends "Purchase Line"
{
    fields
    {
        field(50100; "IP Linked Assembly Order No."; Code[20])
        {
            Caption = 'Linked Assembly Order No.';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50101; "IP Integration Rel. ID"; Guid)
        {
            Caption = 'Integration Relationship ID';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }
}
