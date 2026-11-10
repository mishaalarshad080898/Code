/// <summary>
/// Keeps the ICR movement reference on the posted Transfer Shipment, so the shipment can be traced
/// back to the inbound finished goods payload after the Transfer Order is gone.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing / 3.5 Operational Visibility
tableextension 50407 "IP Transfer Shipment Header" extends "Transfer Shipment Header"
{
    fields
    {
        field(50405; "IP ICR Movement Entry No."; Integer)
        {
            Caption = 'ICR Movement Entry No.';
            DataClassification = CustomerContent;
            TableRelation = "IP ICR Movement Header";
            Editable = false;
        }
        field(50406; "IP Created by ICR Movement"; Boolean)
        {
            Caption = 'Created by ICR Movement';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
