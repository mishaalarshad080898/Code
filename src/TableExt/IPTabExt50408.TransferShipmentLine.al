/// <summary>
/// Keeps the physical filler lot on the posted Transfer Shipment line for audit visibility.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (physical lot retained for audit visibility)
tableextension 50408 "IP Transfer Shipment Line" extends "Transfer Shipment Line"
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
