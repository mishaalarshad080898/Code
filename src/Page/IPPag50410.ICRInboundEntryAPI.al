/// <summary>
/// API endpoint where the middleware posts inbound ICR "Movement" payloads (header plus posd lines
/// in one deep insert). Field names follow the ICR JSON (PO_NUMBER, HDTEXT, MVT_TYPE ...). Inserted
/// movements are logged and then processed by the job queue or manually.
/// Endpoint: /api/interparfums/fillerIntegration/v1.0/companies({id})/icrInboundEntries
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Receives payload) / 6.5 Finished Goods Shipment Processing (Inbound payload received)
page 50410 "IP ICR Inbound Entry API"
{
    PageType = API;
    APIPublisher = 'interparfums';
    APIGroup = 'fillerIntegration';
    APIVersion = 'v1.0';
    EntityName = 'icrInboundEntry';
    EntitySetName = 'icrInboundEntries';
    EntityCaption = 'ICR Inbound Entry';
    EntitySetCaption = 'ICR Inbound Entries';
    SourceTable = "IP ICR Inbound Entry Header";
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
                field(hdText; Rec."HD Text")
                {
                    Caption = 'HDTEXT';
                }
                field(dNumber; Rec."D Number")
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
                field(mvtType; Rec."Mvt Type")
                {
                    Caption = 'MVT_TYPE';
                }
                field(specStock; Rec."Spec Stock")
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
                part(posd; "IP ICR Inbound Entry Line API")
                {
                    Caption = 'posd';
                    EntityName = 'icrInboundEntryLine';
                    EntitySetName = 'icrInboundEntryLines';
                    SubPageLink = "Inbound Header Entry No." = field("Entry No.");
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
