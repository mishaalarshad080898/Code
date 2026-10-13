/// <summary>
/// Company-wide Phantom Lot configuration (ADO 1507). When enabled, automated Assembly Order
/// output for covered finished goods is tracked with the universal phantom lot (default XXXX).
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment
tableextension 50104 "IP Company Information" extends "Company Information"
{
    fields
    {
        field(50100; "IP Phantom Lot Enabled"; Boolean)
        {
            Caption = 'Phantom Lot Enabled';
            DataClassification = CustomerContent;
        }
        field(50101; "IP Phantom Lot No."; Code[50])
        {
            Caption = 'Phantom Lot No.';
            DataClassification = CustomerContent;
            InitValue = 'XXXX';
        }
        field(50102; "IP Replace Existing FG Lot"; Boolean)
        {
            Caption = 'Replace Existing FG Lot';
            DataClassification = CustomerContent;
            InitValue = true;
        }
    }
}
