/// <summary>
/// Inventory Orchestration fields on the Transfer Order: the ICR movement that shipped it and
/// whether BC created the Transfer Order from a finished goods shipment payload.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing
tableextension 50405 "IP Transfer Header" extends "Transfer Header"
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
