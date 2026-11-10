/// <summary>
/// Lines (posd) of an inbound ICR movement.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
page 50414 "IP ICR Movement Subform"
{
    Caption = 'ICR Movement Lines';
    PageType = ListPart;
    ApplicationArea = All;
    SourceTable = "IP ICR Movement Line";
    AutoSplitKey = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("PO Item"; Rec."PO Item")
                {
                    ToolTip = 'Specifies the BC document line number (PO_ITEM).';
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the item (MATNR).';
                }
                field("Item Text"; Rec."Item Text")
                {
                    ToolTip = 'Specifies the item text (ITTEXT).';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the quantity (MENGE).';
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    ToolTip = 'Specifies the unit of measure (MEINS).';
                }
                field("Storage Location"; Rec."Storage Location")
                {
                    ToolTip = 'Specifies the ICR warehouse (LGORT).';
                }
                field("Final"; Rec."Final")
                {
                    ToolTip = 'Specifies X when this is the final operation for the line (FINAL).';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the vendor (LIFNR).';
                }
                field("Net Price"; Rec."Net Price")
                {
                    ToolTip = 'Specifies the price (NETPR) for the price unit.';
                }
                field("Price Unit"; Rec."Price Unit")
                {
                    ToolTip = 'Specifies for how many pieces the price applies (PEINH).';
                }
                field("Physical Lot No."; Rec."Physical Lot No.")
                {
                    ToolTip = 'Specifies the physical lot reported by the filler. For covered finished goods it is kept for audit only.';
                }
            }
        }
    }
}
