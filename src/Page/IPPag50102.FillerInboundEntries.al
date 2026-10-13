/// <summary>
/// List of inbound filler completion payloads, with Process and manual Retry actions.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing / 4.2 Integration Assumptions (2)
page 50102 "IP Filler Inbound Entries"
{
    Caption = 'Filler Inbound Completions';
    PageType = List;
    SourceTable = "IP Filler Inbound Entry";
    SourceTableView = sorting("Entry No.") order(descending);
    CardPageId = "IP Filler Inbound Entry";
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the inbound entry number.';
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the processing status.';
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
                field("Payload Timestamp"; Rec."Payload Timestamp")
                {
                    ToolTip = 'Specifies the payload timestamp.';
                }
                field("Receipt Posted"; Rec."Receipt Posted")
                {
                    ToolTip = 'Specifies whether the PO receipt has been posted.';
                }
                field("Output Posted"; Rec."Output Posted")
                {
                    ToolTip = 'Specifies whether assembly output and consumption have been posted.';
                }
                field("Scrap Posted"; Rec."Scrap Posted")
                {
                    ToolTip = 'Specifies whether scrap has been processed.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ToolTip = 'Specifies the reason for the exception.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ToolTip = 'Specifies the number of manual retries.';
                }
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
                ToolTip = 'Validate and process the selected inbound completion.';

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
                ToolTip = 'Manually retry an inbound completion in Exception status. Steps that already posted are skipped.';

                trigger OnAction()
                var
                    InboundProcessing: Codeunit "IP Inbound Processing";
                begin
                    InboundProcessing.ProcessEntryWithMessage(Rec, true);
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(ActivityLog)
            {
                Caption = 'Activity Log';
                Image = Log;
                RunObject = page "IP Filler Integration Log";
                RunPageLink = "Inbound Entry No." = field("Entry No.");
                ToolTip = 'Open the Activity Log entries for this inbound completion.';
            }
        }
    }

    var
        StatusStyle: Text;

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Processed:
                StatusStyle := 'Favorable';
            Rec.Status::Exception:
                StatusStyle := 'Unfavorable';
            Rec.Status::Duplicate:
                StatusStyle := 'Subordinate';
            else
                StatusStyle := 'Standard';
        end;
    end;
}
