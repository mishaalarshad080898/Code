/// <summary>
/// API endpoint where the middleware posts inbound filler completion payloads (deep insert with
/// scrap lines). Inserted records are logged and then processed by the job queue or manually.
/// Endpoint: /api/interparfums/fillerIntegration/v1.0/companies({id})/fillerCompletions
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Payload Receipt)
page 50105 "IP Filler Completion API"
{
    PageType = API;
    APIPublisher = 'interparfums';
    APIGroup = 'fillerIntegration';
    APIVersion = 'v1.0';
    EntityName = 'fillerCompletion';
    EntitySetName = 'fillerCompletions';
    EntityCaption = 'Filler Completion';
    EntitySetCaption = 'Filler Completions';
    SourceTable = "IP Filler Inbound Entry";
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
                field(vendorNo; Rec."Vendor No.")
                {
                    Caption = 'Vendor No.';
                }
                field(assemblyOrderNo; Rec."Assembly Order No.")
                {
                    Caption = 'Assembly Order No.';
                }
                field(poNo; Rec."Purchase Order No.")
                {
                    Caption = 'Purchase Order No.';
                }
                field(poLineNo; Rec."Purchase Order Line No.")
                {
                    Caption = 'Purchase Order Line No.';
                }
                field(fgItemNo; Rec."Item No.")
                {
                    Caption = 'Finished Good Item No.';
                }
                field(completedQuantity; Rec."Completed Quantity")
                {
                    Caption = 'Completed Quantity';
                }
                field(unitPrice; Rec."Unit Price")
                {
                    Caption = 'Unit Price';
                }
                field(physicalLotNo; Rec."Physical Lot No.")
                {
                    Caption = 'Physical Lot No.';
                }
                field(payloadTimestamp; Rec."Payload Timestamp")
                {
                    Caption = 'Payload Timestamp';
                }
                field(postingDate; Rec."Posting Date")
                {
                    Caption = 'Posting Date';
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                    Editable = false;
                }
                field(errorMessage; Rec."Error Message")
                {
                    Caption = 'Error Message';
                    Editable = false;
                }
                part(scrapLines; "IP Filler Scrap Line API")
                {
                    Caption = 'Scrap Lines';
                    EntityName = 'fillerScrapLine';
                    EntitySetName = 'fillerScrapLines';
                    SubPageLink = "Inbound Entry No." = field("Entry No.");
                }
            }
        }
    }

    trigger OnModifyRecord(): Boolean
    begin
        // Only unprocessed payloads may be corrected through the API.
        Rec.TestField(Status, Rec.Status::Received);
        exit(true);
    end;
}
