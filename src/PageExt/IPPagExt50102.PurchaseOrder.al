/// <summary>
/// Purchase Order page extension. Shows the linked Assembly Order and the integration
/// relationship and production request state, with navigation to the linked AO and Activity Log.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation / 5.6 Outbound Production Request Processing
pageextension 50102 "IP Purchase Order" extends "Purchase Order"
{
    layout
    {
        addlast(Content)
        {
            group(IPFillerIntegration)
            {
                Caption = 'Filler Integration';
                Visible = Rec."IP Filler Integration";

                field("IP Linked Assembly Order No."; Rec."IP Linked Assembly Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Assembly Order this Purchase Order is linked to.';

                    trigger OnDrillDown()
                    begin
                        OpenLinkedAssemblyOrder();
                    end;
                }
                field("IP Prod. Request Sent"; Rec."IP Prod. Request Sent")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the production request was sent to the filler.';
                }
                field("IP Prod. Request Sent Qty"; Rec."IP Prod. Request Sent Qty")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the quantity in the last production request sent.';
                }
                field("IP Integration Rel. ID"; Rec."IP Integration Rel. ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the integration relationship identifier shared by the Assembly Order, Purchase Order and filler messages.';
                }
            }
        }
    }

    actions
    {
        addlast(Processing)
        {
            group(IPFiller)
            {
                Caption = 'Filler Integration';
                Image = Vendor;

                action(IPLinkedAssemblyOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Linked Assembly Order';
                    Image = Document;
                    Enabled = IsLinked;
                    ToolTip = 'Open the linked Assembly Order.';

                    trigger OnAction()
                    begin
                        OpenLinkedAssemblyOrder();
                    end;
                }
                action(IPActivityLog)
                {
                    ApplicationArea = All;
                    Caption = 'Filler Integration Activity Log';
                    Image = Log;
                    RunObject = page "IP Filler Integration Log";
                    RunPageLink = "Purchase Order No." = field("No.");
                    ToolTip = 'Open the Activity Log entries for this Purchase Order.';
                }
            }
        }
    }

    var
        IsLinked: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        IsLinked := Rec."IP Linked Assembly Order No." <> '';
    end;

    /// <summary>
    /// Opens the linked Assembly Order card.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation (Linked AO reference)
    local procedure OpenLinkedAssemblyOrder()
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        if Rec."IP Linked Assembly Order No." = '' then
            exit;
        AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, Rec."IP Linked Assembly Order No.");
        Page.Run(Page::"Assembly Order", AssemblyHeader);
    end;
}
