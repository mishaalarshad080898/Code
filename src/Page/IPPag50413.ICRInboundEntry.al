/// <summary>
/// Card of an inbound ICR movement: ICR header fields, processing result and the posd lines. A
/// movement that is not processed yet can be corrected here before it is processed or retried.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility / 6.4 / 6.5
page 50413 "IP ICR Inbound Entry"
{
    Caption = 'ICR Inbound Entry';
    PageType = Card;
    ApplicationArea = All;
    SourceTable = "IP ICR Inbound Entry Header";
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';
                Editable = IsEditable;

                field("Entry No."; Rec."Entry No.")
                {
                    Editable = false;
                    ToolTip = 'Specifies the entry number of the movement.';
                }
                field("Message ID"; Rec."Message ID")
                {
                    ToolTip = 'Specifies the message ID of the payload.';
                }
                field("Mvt Type"; Rec."Mvt Type")
                {
                    ToolTip = 'Specifies the ICR movement type code (MVT_TYPE).';
                }
                field("Movement Type"; Rec."Movement Type")
                {
                    ToolTip = 'Specifies the ICR movement type.';
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
                field("Document Date"; Rec."Document Date")
                {
                    ToolTip = 'Specifies the document date (DOC_DATE).';
                }
                field("Posting Date"; Rec."Posting Date")
                {
                    ToolTip = 'Specifies the posting date (PSTNG_DATE).';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the integrated filler.';
                }
            }
            group(ProcessingResult)
            {
                Caption = 'Processing';

                field(Status; Rec.Status)
                {
                    ToolTip = 'Specifies the processing status of the movement.';
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
                field("Posted Receipt No."; Rec."Posted Receipt No.")
                {
                    ToolTip = 'Specifies the posted purchase receipt.';
                }
                field("Posted Assembly No."; Rec."Posted Assembly No.")
                {
                    ToolTip = 'Specifies the posted assembly order (ICR-MRP entries only).';
                }
                field("Source Document Type"; Rec."Source Document Type")
                {
                    ToolTip = 'Specifies the type of BC document the movement was posted against.';
                }
                field("Source Document No."; Rec."Source Document No.")
                {
                    ToolTip = 'Specifies the BC document the movement was posted against.';
                }
                field("TO Created"; Rec."TO Created")
                {
                    ToolTip = 'Specifies whether BC created the finished goods transfer order because no matching one existed.';
                }
                field("Posted Document No."; Rec."Posted Document No.")
                {
                    ToolTip = 'Specifies the posted receipt or shipment.';
                }
                field("Received At"; Rec."Received At")
                {
                    ToolTip = 'Specifies when the movement was received.';
                }
                field("Processed At"; Rec."Processed At")
                {
                    ToolTip = 'Specifies when the movement was processed.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ToolTip = 'Specifies how many times the movement was retried.';
                }
                field("Error Message"; Rec."Error Message")
                {
                    MultiLine = true;
                    ToolTip = 'Specifies why the movement could not be processed.';
                }
            }
            part(Lines; "IP ICR Inbound Entry Subform")
            {
                Caption = 'Lines (posd)';
                SubPageLink = "Inbound Header Entry No." = field("Entry No.");
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
                ToolTip = 'Process this movement now.';

                trigger OnAction()
                var
                    MovementProcessing: Codeunit "IP ICR Movement Processing";
                begin
                    CurrPage.SaveRecord();
                    MovementProcessing.ProcessEntryWithMessage(Rec, false);
                    CurrPage.Update(false);
                end;
            }
            action(Retry)
            {
                Caption = 'Retry';
                Image = Refresh;
                ToolTip = 'Retry this movement after the cause of the exception was fixed.';

                trigger OnAction()
                var
                    MovementProcessing: Codeunit "IP ICR Movement Processing";
                begin
                    CurrPage.SaveRecord();
                    MovementProcessing.ProcessEntryWithMessage(Rec, true);
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
            action(SourceDocument)
            {
                Caption = 'Source Document';
                Image = Document;
                ToolTip = 'Open the Purchase Order or Transfer Order the movement was posted against.';

                trigger OnAction()
                begin
                    ShowSourceDocument();
                end;
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
        IsEditable: Boolean;

    trigger OnAfterGetCurrRecord()
    begin
        IsEditable := Rec.Status in [Rec.Status::Received, Rec.Status::Exception];
    end;

    /// <summary>
    /// Opens the BC document the movement was posted against, if it still exists.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility
    local procedure ShowSourceDocument()
    var
        PurchaseHeader: Record "Purchase Header";
        TransferHeader: Record "Transfer Header";
    begin
        case Rec."Source Document Type" of
            Rec."Source Document Type"::"Purchase Order":
                if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."Source Document No.") then
                    Page.Run(Page::"Purchase Order", PurchaseHeader);
            Rec."Source Document Type"::"Transfer Order",
            Rec."Source Document Type"::"FG Transfer Order":
                if TransferHeader.Get(Rec."Source Document No.") then
                    Page.Run(Page::"Transfer Order", TransferHeader);
        end;
    end;
}
