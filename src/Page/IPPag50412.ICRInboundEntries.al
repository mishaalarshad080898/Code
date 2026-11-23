/// <summary>
/// List of all inbound ICR entries of both FDDs (production PO completions, scrap, adjustments, raw
/// material receipts and finished goods shipments) with their status, the BC document they were
/// posted against and the error, if any. Inventory Orchestration entries can be processed or
/// retried from here.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility / 5.2 Integration Assumptions (1) retry processing
page 50412 "IP ICR Inbound Entries"
{
    Caption = 'ICR Inbound Entries';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "IP ICR Inbound Entry Header";
    CardPageId = "IP ICR Inbound Entry";
    Editable = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Movements)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the entry number of the movement.';
                }
                field("Received At"; Rec."Received At")
                {
                    ToolTip = 'Specifies when the movement was received.';
                }
                field("Movement Type"; Rec."Movement Type")
                {
                    ToolTip = 'Specifies the ICR movement type (MVT_TYPE).';
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies the processing status of the movement.';
                    StyleExpr = StatusStyle;
                }
                field("PO Number"; Rec."PO Number")
                {
                    ToolTip = 'Specifies the BC order number sent by ICR (PO_NUMBER).';
                }
                field("HD Text"; Rec."HD Text")
                {
                    ToolTip = 'Specifies the document number in the ICR system (HDTEXT).';
                }
                field("D Number"; Rec."D Number")
                {
                    ToolTip = 'Specifies the bill of lading (D_NUMBER).';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the integrated filler.';
                }
                field("Assembly Order No."; Rec."Assembly Order No.")
                {
                    ToolTip = 'Specifies the Assembly Order of the production PO (ICR-MRP entries only).';
                }
                field("Receipt Posted"; Rec."Receipt Posted")
                {
                    ToolTip = 'Specifies whether the receipt step was posted.';
                }
                field("Output Posted"; Rec."Output Posted")
                {
                    ToolTip = 'Specifies whether the assembly output step was posted (ICR-MRP entries only).';
                }
                field("Scrap Posted"; Rec."Scrap Posted")
                {
                    ToolTip = 'Specifies whether the scrap step was posted (ICR-MRP entries only).';
                }
                field("Source Document Type"; Rec."Source Document Type")
                {
                    ToolTip = 'Specifies the type of BC document the movement was posted against.';
                }
                field("Source Document No."; Rec."Source Document No.")
                {
                    ToolTip = 'Specifies the BC document the movement was posted against.';
                }
                field("Posted Document No."; Rec."Posted Document No.")
                {
                    ToolTip = 'Specifies the posted receipt or shipment.';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ToolTip = 'Specifies the posting date (PSTNG_DATE).';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ToolTip = 'Specifies how many times the movement was retried.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    ToolTip = 'Specifies why the movement could not be processed.';
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
                ToolTip = 'Process the selected Inventory Orchestration entry (030 raw material receipt or 311 finished goods shipment) now.';

                trigger OnAction()
                var
                    MovementProcessing: Codeunit "IP ICR Movement Processing";
                begin
                    MovementProcessing.ProcessEntryWithMessage(Rec, false);
                    CurrPage.Update(false);
                end;
            }
            action(Retry)
            {
                Caption = 'Retry';
                Image = Refresh;
                ToolTip = 'Retry a movement in status Exception after the cause was fixed.';

                trigger OnAction()
                var
                    MovementProcessing: Codeunit "IP ICR Movement Processing";
                begin
                    MovementProcessing.ProcessEntryWithMessage(Rec, true);
                    CurrPage.Update(false);
                end;
            }
            action(ProcessAll)
            {
                Caption = 'Process All Received';
                Image = ExecuteBatch;
                ToolTip = 'Process all Inventory Orchestration entries in status Received.';

                trigger OnAction()
                var
                    MovementProcessing: Codeunit "IP ICR Movement Processing";
                begin
                    MovementProcessing.ProcessReceivedEntries();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(ActivityLog)
            {
                Caption = 'Filler Integration Activity Log';
                Image = Log;
                RunObject = page "IP Filler Integration Log";
                RunPageLink = "ICR Inbound Entry No." = field("Entry No.");
                ToolTip = 'Open the Activity Log entries of this movement.';
            }
        }
        area(Promoted)
        {
            actionref(Process_Promoted; Process)
            {
            }
            actionref(Retry_Promoted; Retry)
            {
            }
            actionref(ActivityLog_Promoted; ActivityLog)
            {
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
                StatusStyle := 'Ambiguous';
            else
                StatusStyle := 'Standard';
        end;
    end;
}
