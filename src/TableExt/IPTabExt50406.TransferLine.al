/// <summary>
/// Physical filler lot reported in the finished goods shipment payload. Kept for audit visibility
/// only: when Phantom Lot is enabled, BC item tracking uses the phantom lot (XXXX) instead.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (physical lot retained for audit visibility)
tableextension 50406 "IP Transfer Line" extends "Transfer Line"
{
    fields
    {
        field(50405; "IP Physical Lot No."; Code[50])
        {
            Caption = 'Physical Lot No. (Filler)';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
