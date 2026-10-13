/// <summary>
/// Card for one inbound filler completion: payload values, processing step flags, posted
/// document references and declared scrap lines.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
page 50103 "IP Filler Inbound Entry"
{
    Caption = 'Filler Inbound Completion';
    PageType = Card;
    SourceTable = "IP Filler Inbound Entry";
    ApplicationArea = All;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(Payload)
            {
                Caption = 'Payload';
                Editable = IsEditable;

                field("Entry No."; Rec."Entry No.")
                {
                    Editable = false;
                    ToolTip = 'Specifies the inbound entry number.';
                }
                field("Message ID"; Rec."Message ID")
                {
                    ToolTip = 'Specifies the unique message ID sent by the filler.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the filler vendor.';
                }
                field("Assembly Order No."; Rec."Assembly Order No.")
                {
                    ToolTip = 'Specifies the Assembly Order being completed.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ToolTip = 'Specifies the linked Purchase Order.';
                }
                field("Purchase Order Line No."; Rec."Purchase Order Line No.")
                {
                    ToolTip = 'Specifies the linked Purchase Order line.';
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the finished good.';
                }
                field("Completed Quantity"; Rec."Completed Quantity")
                {
                    ToolTip = 'Specifies the authoritative completed quantity.';
                }
                field("Unit Price"; Rec."Unit Price")
                {
                    ToolTip = 'Specifies the unit price sent by the filler.';
                }
                field("Physical Lot No."; Rec."Physical Lot No.")
                {
                    ToolTip = 'Specifies the physical lot from the filler. Kept for audit only; not written to BC finished-goods item tracking.';
                }
                field("Payload Timestamp"; Rec."Payload Timestamp")
                {
                    ToolTip = 'Specifies the payload timestamp.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ToolTip = 'Specifies the posting date. If blank, the work date is used.';
                }
            }
            group(ProcessingStatus)
            {
                Caption = 'Processing';

                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies the processing status.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    MultiLine = true;
                    ToolTip = 'Specifies the reason for the exception.';
                }
                field("Quantities Synchronized"; Rec."Quantities Synchronized")
                {
                    ToolTip = 'Specifies whether the PO/AO quantities were synchronized for overage.';
                }
                field("Receipt Posted"; Rec."Receipt Posted")
                {
                    ToolTip = 'Specifies whether the PO receipt has been posted.';
                }
                field("Posted Receipt No."; Rec."Posted Receipt No.")
                {
                    ToolTip = 'Specifies the posted purchase receipt.';
                }
                field("Output Posted"; Rec."Output Posted")
                {
                    ToolTip = 'Specifies whether assembly output and consumption have been posted.';
                }
                field("Posted Assembly No."; Rec."Posted Assembly No.")
                {
                    ToolTip = 'Specifies the posted assembly order.';
                }
                field("Scrap Posted"; Rec."Scrap Posted")
                {
                    ToolTip = 'Specifies whether scrap has been processed.';
                }
                field("Received At"; Rec."Received At")
                {
                    ToolTip = 'Specifies when the payload was received.';
                }
                field("Processed At"; Rec."Processed At")
                {
                    ToolTip = 'Specifies when processing completed.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ToolTip = 'Specifies the number of manual retries.';
                }
            }
            part(ScrapLines; "IP Filler Inbound Scrap Sub.")
            {
                Caption = 'Scrap Lines';
                SubPageLink = "Inbound Entry No." = field("Entry No.");
                Editable = IsEditable;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Process)
            {
                Caption = 'Process';
                Image = Start;
                ToolTip = 'Validate and process this inbound completion.';

                trigger OnAction()
                var
                    InboundProcessing: Codeunit "IP Inbound Processing";
                begin
                    InboundProcessing.ProcessEntryWithMessage(Rec, false);
                    CurrPage.Update(false);
                end;
            }
            action(Retry)
            {
                Caption = 'Retry';
                Image = Refresh;
                ToolTip = 'Manually retry this inbound completion. Steps that already posted are skipped.';

                trigger OnAction()
                var
                    InboundProcessing: Codeunit "IP Inbound Processing";
                begin
                    InboundProcessing.ProcessEntryWithMessage(Rec, true);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        IsEditable: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        // Payload values can only be corrected before any posting step has run.
        IsEditable := (Rec.Status in [Rec.Status::Received, Rec.Status::Exception]) and
                      (not Rec."Quantities Synchronized") and (not Rec."Receipt Posted");
    end;
}
