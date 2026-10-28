/// <summary>
/// ICR supplier code of a warehouse (location). For transfer orders the "lifnr" (supplier) in the
/// order message is derived from the transfer-from warehouse; when blank, the location code is used.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (lifnr - For transfers: derive from warehouse code)
tableextension 50106 "IP Location" extends Location
{
    fields
    {
        field(50100; "IP ICR Supplier Code"; Code[20])
        {
            Caption = 'ICR Supplier Code';
            DataClassification = CustomerContent;
        }
    }
}
