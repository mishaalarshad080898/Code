/// <summary>
/// Company Information page extension for the company-wide ADO 1507 Phantom Lot configuration.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment
pageextension 50103 "IP Company Information" extends "Company Information"
{
    layout
    {
        addlast(Content)
        {
            group(IPPhantomLot)
            {
                Caption = 'Phantom Lot (ADO 1507)';

                field("IP Phantom Lot Enabled"; Rec."IP Phantom Lot Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether automated Assembly Order output for covered finished goods is tracked with the universal phantom lot.';
                }
                field("IP Phantom Lot No."; Rec."IP Phantom Lot No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the universal phantom lot number (default XXXX).';
                }
                field("IP Replace Existing FG Lot"; Rec."IP Replace Existing FG Lot")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether an unposted physical finished-goods lot on the Assembly Order is replaced with the phantom lot (Yes) or stops posting with a conflict message (No).';
                }
            }
        }
    }
}
