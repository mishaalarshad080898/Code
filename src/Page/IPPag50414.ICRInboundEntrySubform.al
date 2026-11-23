/// <summary>
/// Lines (posd) of an inbound ICR entry.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
page 50414 "IP ICR Inbound Entry Subform"
{
    Caption = 'ICR Inbound Entry Lines';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "IP ICR Inbound Entry Lines";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Item Line No"; Rec."Item Line No")
                {
                    ToolTip = 'Specifies the BC document line number (PO_ITEM).';
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item (MATNR).';
                }
                field(ITTEXT; Rec.ITTEXT)
                {
                    ToolTip = 'Specifies the item text (ITTEXT).';
                }
                field(Qty; Rec.Qty)
                {
                    ToolTip = 'Specifies the quantity (MENGE).';
                }
                field("Unit of Measure"; Rec."Unit of Measure")
                {
                    ToolTip = 'Specifies the unit of measure (MEINS).';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'Specifies the ICR warehouse (LGORT).';
                }
                field(FINAL; Rec.FINAL)
                {
                    ToolTip = 'Specifies X when this is the final operation for the line (FINAL).';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the vendor (LIFNR).';
                }
                field(NETPR; Rec.NETPR)
                {
                    ToolTip = 'Specifies the price (NETPR) for the price unit.';
                }
                field(PEINH; Rec.PEINH)
                {
                    ToolTip = 'Specifies for how many pieces the price applies (PEINH).';
                }
                field("Physical Lot No."; Rec."Physical Lot No.")
                {
                    ToolTip = 'Specifies the physical lot reported by the filler. For covered finished goods it is kept for audit only.';
                }
                field("Receipt Posted"; Rec."Receipt Posted")
                {
                    ToolTip = 'Specifies whether the receipt for this line was posted.';
                }
            }
        }
    }
}
