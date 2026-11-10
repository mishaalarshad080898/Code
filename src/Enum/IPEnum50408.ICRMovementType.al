/// <summary>
/// ICR movement type (MVT_TYPE) of an inbound ICR "Movement" payload. The value ids match the
/// ICR codes. Inventory Orchestration processes 030 (Goods Receipt of a PO / inbound TO) and
/// 311 (finished goods transfer to the 3PL). The other codes are accepted and logged, but are
/// rejected as not in scope of this FDD.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
enum 50408 "IP ICR Movement Type"
{
    Extensible = true;
    Caption = 'ICR Movement Type';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(30; "Goods Receipt")
    {
        Caption = '030 - Goods Receipt';
    }
    value(87; "Scrap")
    {
        Caption = '087 - Scrap from External Processing';
    }
    value(100; "Positive Adjustment")
    {
        Caption = '100 - Positive Adjustment';
    }
    value(101; "Negative Adjustment")
    {
        Caption = '101 - Negative Adjustment';
    }
    value(122; "Return to Vendor")
    {
        Caption = '122 - Return to Vendor';
    }
    value(311; "Transfer to 3PL")
    {
        Caption = '311 - Transfer to 3PL';
    }
}
