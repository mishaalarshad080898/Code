/// <summary>
/// Assembly Order page extension. Shows the filler integration fields (Linked PO No./Line No.,
/// Linked PO Released, Filler Status, BOM Sent Date) and adds the Create PO Link and
/// Resend BOM to Filler functions.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.1 Assembly Order Creation / 5.2 Create PO Link Function / 5.7 Outbound BOM Transmission
pageextension 50100 "IP Assembly Order" extends "Assembly Order"
{
    layout
    {
        addlast(Content)
        {
            group(IPFillerIntegration)
            {
                Caption = 'Filler Integration';

                field("IP Linked Purch. Order No."; Rec."IP Linked Purch. Order No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Purchase Order linked to this Assembly Order by Create PO Link.';

                    trigger OnDrillDown()
                    begin
                        OpenLinkedPurchaseOrder();
                    end;
                }
                field("IP Linked Purch. Line No."; Rec."IP Linked Purch. Line No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Fill Item line of the linked Purchase Order.';
                }
                field("IP Linked PO Released"; Rec."IP Linked PO Released")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether the linked Purchase Order is released. The Assembly Order can only be released when this is Yes.';
                }
                field("IP Filler Status"; Rec."IP Filler Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies where the Assembly Order is in the filler lifecycle.';
                }
                field("IP BOM Sent Date"; Rec."IP BOM Sent Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies when the BOM (AO lines) was last sent to the filler.';
                }
                field("IP Filler Vendor No."; Rec."IP Filler Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the filler vendor.';
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

                action(IPCreatePOLink)
                {
                    ApplicationArea = All;
                    Caption = 'Create PO Link';
                    Image = MakeOrder;
                    Enabled = CanCreatePOLink;
                    ToolTip = 'Create, link and release the filler Purchase Order for this Assembly Order. Available when the Assembly Order is Open and has no linked Purchase Order.';

                    trigger OnAction()
                    var
                        CreatePOLink: Codeunit "IP Create PO Link";
                    begin
                        CurrPage.SaveRecord();
                        CreatePOLink.CreatePOLink(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(IPResendBOM)
                {
                    ApplicationArea = All;
                    Caption = 'Resend BOM to Filler';
                    Image = SendTo;
                    Enabled = CanResendBOM;
                    ToolTip = 'Manually resend the BOM (AO lines, without the Fill Item) to the filler. Every resend is logged.';

                    trigger OnAction()
                    var
                        OutboundBOMTransmission: Codeunit "IP Outbound BOM Transmission";
                    begin
                        OutboundBOMTransmission.ResendBOM(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(IPLinkedPurchaseOrder)
                {
                    ApplicationArea = All;
                    Caption = 'Linked Purchase Order';
                    Image = Document;
                    Enabled = IsLinked;
                    ToolTip = 'Open the linked filler Purchase Order.';

                    trigger OnAction()
                    begin
                        OpenLinkedPurchaseOrder();
                    end;
                }
                action(IPActivityLog)
                {
                    ApplicationArea = All;
                    Caption = 'Filler Integration Activity Log';
                    Image = Log;
                    RunObject = page "IP Filler Integration Log";
                    RunPageLink = "Assembly Order No." = field("No.");
                    ToolTip = 'Open the Activity Log entries for this Assembly Order.';
                }
            }
        }
    }

    var
        CanCreatePOLink: Boolean;
        CanResendBOM: Boolean;
        IsLinked: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        IsLinked := Rec."IP Linked Purch. Order No." <> '';
        CanCreatePOLink := (Rec.Status = Rec.Status::Open) and (not IsLinked);
        CanResendBOM := IsLinked and (Rec.Status = Rec.Status::Released);
    end;

    /// <summary>
    /// Opens the linked Purchase Order card.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.3 Purchase Order Creation (Linked AO reference)
    local procedure OpenLinkedPurchaseOrder()
    var
        PurchaseHeader: Record "Purchase Header";
    begin
        if Rec."IP Linked Purch. Order No." = '' then
            exit;
        PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."IP Linked Purch. Order No.");
        Page.Run(Page::"Purchase Order", PurchaseHeader);
    end;
}
