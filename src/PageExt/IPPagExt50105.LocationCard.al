/// <summary>
/// Location Card page extension for the ICR supplier code used as "lifnr" on transfer orders.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (lifnr - For transfers: derive from warehouse code)
pageextension 50105 "IP Location Card" extends "Location Card"
{
    layout
    {
        addlast(Content)
        {
            group(IPFillerIntegration)
            {
                Caption = 'Filler Integration';

                field("IP ICR Supplier Code"; Rec."IP ICR Supplier Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the supplier code sent to ICR as lifnr when this location is the transfer-from warehouse of a transfer order. If blank, the location code is sent.';
                }
            }
        }
    }
}
