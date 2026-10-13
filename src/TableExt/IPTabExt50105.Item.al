/// <summary>
/// Item flags used by the filler integration. Fill Item marks the filling service item that
/// becomes the single PO line and is excluded from the BOM payload. Phantom Lot Covered marks
/// finished goods covered by ADO 1507 phantom lot processing.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation / 5.7 Outbound BOM Transmission / 5.10 Phantom Lot Assignment
tableextension 50105 "IP Item" extends Item
{
    fields
    {
        field(50100; "IP Fill Item"; Boolean)
        {
            Caption = 'Fill Item';
            DataClassification = CustomerContent;
        }
        field(50101; "IP Phantom Lot Covered"; Boolean)
        {
            Caption = 'Phantom Lot Covered';
            DataClassification = CustomerContent;
        }
    }
}
