/// <summary>
/// Item Card page extension for the Fill Item and Phantom Lot Covered flags.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation (Fill Item) / 5.10 Phantom Lot Assignment (covered finished good)
pageextension 50104 "IP Item Card" extends "Item Card"
{
    layout
    {
        addlast(Content)
        {
            group(IPFillerIntegration)
            {
                Caption = 'Filler Integration';

                field("IP Fill Item"; Rec."IP Fill Item")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies that this item is the filling service (Fill Item). It becomes the single linked Purchase Order line and is excluded from the BOM payload.';
                }
                field("IP Phantom Lot Covered"; Rec."IP Phantom Lot Covered")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies that this finished good is covered by ADO 1507 phantom lot processing.';
                }
            }
        }
    }
}
