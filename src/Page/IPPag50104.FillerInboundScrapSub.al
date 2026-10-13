/// <summary>
/// Subpage with the scrap lines declared on an inbound filler completion.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.13 Scrap Handling
page 50104 "IP Filler Inbound Scrap Sub."
{
    Caption = 'Scrap Lines';
    PageType = ListPart;
    SourceTable = "IP Filler Inbound Scrap Line";
    ApplicationArea = All;
    AutoSplitKey = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the scrapped item.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies a description.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the scrapped quantity.';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ToolTip = 'Specifies the unit of measure.';
                }
                field("Lot No."; Rec."Lot No.")
                {
                    ToolTip = 'Specifies the physical component lot that was scrapped.';
                }
                field("Reason Code"; Rec."Reason Code")
                {
                    ToolTip = 'Specifies the scrap reason.';
                }
            }
        }
    }
}
