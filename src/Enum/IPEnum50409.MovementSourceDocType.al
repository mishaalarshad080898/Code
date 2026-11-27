/// <summary>
/// BC document an inbound ICR movement was posted against: the raw material Purchase Order or
/// inbound Transfer Order received by the filler (030), or the finished goods Transfer Order
/// shipped from the filler to the 3PL (311), or the Item Journal of an adjustment (100 / 101).
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
enum 50409 "IP Movement Source Doc. Type"
{
    Extensible = true;
    Caption = 'Movement Source Document Type';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; "Purchase Order")
    {
        Caption = 'Purchase Order';
    }
    value(2; "Transfer Order")
    {
        Caption = 'Transfer Order';
    }
    value(3; "FG Transfer Order")
    {
        Caption = 'Finished Goods Transfer Order';
    }
    value(4; "Item Journal")
    {
        Caption = 'Item Journal';
    }
}
