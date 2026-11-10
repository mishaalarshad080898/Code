/// <summary>
/// Business event that sends a raw material Transfer Order to the integrated filler. Shipment
/// (default) follows the Inventory Orchestration FDD: the posted Transfer Shipment is the
/// authoritative event. Release keeps the earlier behavior of sending on Transfer Order release.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.2 Transfer Order Shipment to Integrated Filler / 6.3 Outbound Integration Trigger Points
enum 50410 "IP TO Outbound Trigger"
{
    Extensible = true;
    Caption = 'Transfer Order Outbound Trigger';

    value(0; Shipment)
    {
        Caption = 'Shipment Posting';
    }
    value(1; Release)
    {
        Caption = 'Release';
    }
}
