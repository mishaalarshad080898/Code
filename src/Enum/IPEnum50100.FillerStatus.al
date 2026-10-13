/// <summary>
/// Filler Status values shown on the Assembly Order. Tracks where the AO is in the
/// integrated filler (ICR) subcontracting lifecycle, from PO linkage to final completion.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.1 Assembly Order Creation
enum 50100 "IP Filler Status"
{
    Extensible = true;
    Caption = 'Filler Status';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Linked)
    {
        Caption = 'Linked';
    }
    value(2; "Production Request Sent")
    {
        Caption = 'Production Request Sent';
    }
    value(3; "BOM Sent")
    {
        Caption = 'BOM Sent';
    }
    value(4; "Partially Completed")
    {
        Caption = 'Partially Completed';
    }
    value(5; Completed)
    {
        Caption = 'Completed';
    }
    value(6; Exception)
    {
        Caption = 'Exception';
    }
}
