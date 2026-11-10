/// <summary>
/// Shows on the Transfer Order whether it was created by an ICR finished goods shipment and links to
/// the movement and its Activity Log entries.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing / 3.5 Operational Visibility
pageextension 50403 "IP Transfer Order" extends "Transfer Order"
{
    layout
    {
        addlast(General)
        {
            field("IP Created by ICR Movement"; Rec."IP Created by ICR Movement")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether BC created this transfer order from an ICR finished goods shipment payload.';
            }
            field("IP ICR Movement Entry No."; Rec."IP ICR Movement Entry No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the ICR movement that shipped this transfer order.';
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            action(IPFillerActivityLog)
            {
                ApplicationArea = All;
                Caption = 'Filler Integration Activity Log';
                Image = Log;
                RunObject = page "IP Filler Integration Log";
                RunPageLink = "Document No." = field("No.");
                ToolTip = 'Open the Activity Log entries of this transfer order.';
            }
            action(IPICRMovement)
            {
                ApplicationArea = All;
                Caption = 'ICR Movement';
                Image = Inventory;
                RunObject = page "IP ICR Movement";
                RunPageLink = "Entry No." = field("IP ICR Movement Entry No.");
                ToolTip = 'Open the ICR movement that shipped this transfer order.';
            }
        }
    }
}
