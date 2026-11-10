/// <summary>
/// API endpoint where the middleware posts inbound ICR "Movement" payloads (header plus posd lines
/// in one deep insert). Field names follow the ICR JSON (PO_NUMBER, HDTEXT, MVT_TYPE ...). Inserted
/// movements are logged and then processed by the job queue or manually.
/// Endpoint: /api/interparfums/fillerIntegration/v1.0/companies({id})/icrMovements
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Receives payload) / 6.5 Finished Goods Shipment Processing (Inbound payload received)
page 50410 "IP ICR Movement API"
{
    PageType = API;
    APIPublisher = 'interparfums';
    APIGroup = 'fillerIntegration';
    APIVersion = 'v1.0';
    EntityName = 'icrMovement';
    EntitySetName = 'icrMovements';
    EntityCaption = 'ICR Movement';
    EntitySetCaption = 'ICR Movements';
    SourceTable = "IP ICR Movement Header";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    Extensible = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                    Editable = false;
                }
                field(entryNo; Rec."Entry No.")
                {
                    Caption = 'Entry No.';
                    Editable = false;
                }
                field(messageId; Rec."Message ID")
                {
                    Caption = 'Message ID';
                }
                field(poNumber; Rec."PO Number")
                {
                    Caption = 'PO_NUMBER';
                }
                field(hdText; Rec."ICR Document No.")
                {
                    Caption = 'HDTEXT';
                }
                field(dNumber; Rec."BOL No.")
                {
                    Caption = 'D_NUMBER';
                }
                field(docDate; Rec."Document Date")
                {
                    Caption = 'DOC_DATE';
                }
                field(postingDate; Rec."Posting Date")
                {
                    Caption = 'PSTNG_DATE';
                }
                field(mvtType; Rec."Movement Type Code")
                {
                    Caption = 'MVT_TYPE';
                }
                field(specStock; Rec."Special Stock")
                {
                    Caption = 'SPEC_STOCK';
                }
                field(vendorNo; Rec."Vendor No.")
                {
                    Caption = 'Filler Vendor No.';
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                    Editable = false;
                }
                field(sourceDocumentNo; Rec."Source Document No.")
                {
                    Caption = 'Source Document No.';
                    Editable = false;
                }
                field(postedDocumentNo; Rec."Posted Document No.")
                {
                    Caption = 'Posted Document No.';
                    Editable = false;
                }
                field(errorMessage; Rec."Error Message")
                {
                    Caption = 'Error Message';
                    Editable = false;
                }
                part(posd; "IP ICR Movement Line API")
                {
                    Caption = 'posd';
                    EntityName = 'icrMovementLine';
                    EntitySetName = 'icrMovementLines';
                    SubPageLink = "Entry No." = field("Entry No.");
                }
            }
        }
    }

    trigger OnModifyRecord(): Boolean
    begin
        // Only unprocessed movements may be corrected through the API.
        Rec.TestField(Status, Rec.Status::Received);
        exit(true);
    end;
}
