/// <summary>
/// Filler Integration Activity Log page. The operational monitoring and exception management
/// tool, with actions to view the payload and error and to manually resend an outbound payload.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.1 Operational Assumptions (5) / 5.14 Outbound Trigger Points (Retry Request)
page 50101 "IP Filler Integration Log"
{
    Caption = 'Filler Integration Activity Log';
    PageType = List;
    SourceTable = "IP Filler Integration Log";
    SourceTableView = sorting("Entry No.") order(descending);
    UsageCategory = Lists;
    ApplicationArea = All;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the log entry number.';
                }
                field("Created At"; Rec."Created At")
                {
                    ToolTip = 'Specifies when the entry was logged.';
                }
                field(Direction; Rec.Direction)
                {
                    ToolTip = 'Specifies whether the entry is outbound, inbound or internal BC processing.';
                }
                field("Event Type"; Rec."Event Type")
                {
                    ToolTip = 'Specifies the business event that was processed.';
                }
                field(Status; Rec.Status)
                {
                    StyleExpr = StatusStyle;
                    ToolTip = 'Specifies the processing status.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the filler vendor.';
                }
                field("Document Type"; Rec."Document Type")
                {
                    ToolTip = 'Specifies the type of document the order message was sent for.';
                }
                field("Document No."; Rec."Document No.")
                {
                    ToolTip = 'Specifies the document the order message was sent for.';
                }
                field("Assembly Order No."; Rec."Assembly Order No.")
                {
                    ToolTip = 'Specifies the linked Assembly Order.';
                }
                field("Purchase Order No."; Rec."Purchase Order No.")
                {
                    ToolTip = 'Specifies the linked Purchase Order.';
                }
                field("Purchase Order Line No."; Rec."Purchase Order Line No.")
                {
                    ToolTip = 'Specifies the linked Purchase Order line.';
                }
                field(Description; Rec.Description)
                {
                    ToolTip = 'Specifies a description of the event.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ToolTip = 'Specifies the detailed error for exceptions.';
                }
                field("Message ID"; Rec."Message ID")
                {
                    ToolTip = 'Specifies the payload message ID.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the inbound quantity.';
                }
                field("Unit Price"; Rec."Unit Price")
                {
                    ToolTip = 'Specifies the inbound unit price.';
                }
                field("Physical Lot No."; Rec."Physical Lot No.")
                {
                    ToolTip = 'Specifies the physical lot sent by the filler. Kept for audit only; not written to BC finished-goods item tracking.';
                }
                field("Inbound Entry No."; Rec."Inbound Entry No.")
                {
                    ToolTip = 'Specifies the inbound completion entry.';
                }
                field("HTTP Status Code"; Rec."HTTP Status Code")
                {
                    ToolTip = 'Specifies the HTTP status returned by the filler endpoint.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ToolTip = 'Specifies how many times this entry was retried.';
                }
                field("Parent Entry No."; Rec."Parent Entry No.")
                {
                    ToolTip = 'Specifies the original log entry that this entry resends.';
                }
                field("Created By"; Rec."Created By")
                {
                    ToolTip = 'Specifies the user who created the entry.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ResendPayload)
            {
                Caption = 'Resend Payload';
                Image = Refresh;
                Enabled = CanResend;
                ToolTip = 'Manually resend the stored outbound payload. A new log entry is created and the payload history is kept.';

                trigger OnAction()
                var
                    Transport: Codeunit "IP Filler Transport";
                begin
                    if Transport.RetryLogEntry(Rec) then
                        Message(ResentMsg)
                    else
                        Message(ResendFailedMsg);
                    CurrPage.Update(false);
                end;
            }
            action(ShowPayload)
            {
                Caption = 'Show Payload';
                Image = ViewDetails;
                ToolTip = 'Show the stored payload.';

                trigger OnAction()
                begin
                    Message('%1', Rec.GetPayload());
                end;
            }
            action(ShowError)
            {
                Caption = 'Show Error';
                Image = ErrorLog;
                ToolTip = 'Show the full error message.';

                trigger OnAction()
                begin
                    Message('%1', Rec."Error Message");
                end;
            }
        }
    }

    var
        StatusStyle: Text;
        CanResend: Boolean;
        ResentMsg: Label 'The payload was resent.';
        ResendFailedMsg: Label 'The payload could not be resent. See the new log entry for details.';

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Success:
                StatusStyle := 'Favorable';
            Rec.Status::Exception:
                StatusStyle := 'Unfavorable';
            Rec.Status::Pending:
                StatusStyle := 'Ambiguous';
            else
                StatusStyle := 'Standard';
        end;
    end;

    trigger OnAfterGetCurrRecord()
    begin
        CanResend := Rec.Direction = Rec.Direction::Outbound;
    end;
}
