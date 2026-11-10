/// <summary>
/// Shows on the posted Transfer Shipment the ICR movement it came from, so the finished goods
/// shipment can be traced after the Transfer Order is received by Difarco.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing / 3.5 Operational Visibility
pageextension 50404 "IP Posted Transfer Shipment" extends "Posted Transfer Shipment"
{
    layout
    {
        addlast(General)
        {
            field("IP Created by ICR Movement"; Rec."IP Created by ICR Movement")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether the transfer order was created from an ICR finished goods shipment payload.';
            }
            field("IP ICR Movement Entry No."; Rec."IP ICR Movement Entry No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the ICR movement this shipment was posted from.';
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            action(IPICRMovement)
            {
                ApplicationArea = All;
                Caption = 'ICR Movement';
                Image = Inventory;
                RunObject = page "IP ICR Movement";
                RunPageLink = "Entry No." = field("IP ICR Movement Entry No.");
                ToolTip = 'Open the ICR movement this shipment was posted from.';
            }
        }
    }
}
