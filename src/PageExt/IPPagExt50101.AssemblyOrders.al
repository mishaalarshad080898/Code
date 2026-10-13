/// <summary>
/// Assembly Orders list page extension. Shows Linked PO, Linked PO Released and Filler Status
/// so users can see at a glance which AOs can be released.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.2 Create PO Link Function (Linked PO Released) / 4.1 Operational Assumptions (5)
pageextension 50101 "IP Assembly Orders" extends "Assembly Orders"
{
    layout
    {
        addafter("Item No.")
        {
            field("IP Linked Purch. Order No."; Rec."IP Linked Purch. Order No.")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies the Purchase Order linked to this Assembly Order.';
            }
            field("IP Linked PO Released"; Rec."IP Linked PO Released")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies whether the linked Purchase Order is released.';
            }
            field("IP Filler Status"; Rec."IP Filler Status")
            {
                ApplicationArea = All;
                ToolTip = 'Specifies where the Assembly Order is in the filler lifecycle.';
            }
        }
    }
}
