/// <summary>
/// API part for the scrap lines of an inbound filler completion (used in a deep insert).
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.13 Scrap Handling / 5.15 Inbound Payload Processing (Scrap information)
page 50106 "IP Filler Scrap Line API"
{
    PageType = API;
    APIPublisher = 'interparfums';
    APIGroup = 'fillerIntegration';
    APIVersion = 'v1.0';
    EntityName = 'fillerScrapLine';
    EntitySetName = 'fillerScrapLines';
    EntityCaption = 'Filler Scrap Line';
    EntitySetCaption = 'Filler Scrap Lines';
    SourceTable = "IP Filler Inbound Scrap Line";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    Extensible = false;

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
                field(inboundEntryNo; Rec."Inbound Entry No.")
                {
                    Caption = 'Inbound Entry No.';
                }
                field(lineNo; Rec."Line No.")
                {
                    Caption = 'Line No.';
                }
                field(itemNo; Rec."Item No.")
                {
                    Caption = 'Item No.';
                }
                field(quantity; Rec.Quantity)
                {
                    Caption = 'Quantity';
                }
                field(unitOfMeasureCode; Rec."Unit of Measure Code")
                {
                    Caption = 'Unit of Measure Code';
                }
                field(lotNo; Rec."Lot No.")
                {
                    Caption = 'Lot No.';
                }
                field(reasonCode; Rec."Reason Code")
                {
                    Caption = 'Reason Code';
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                }
            }
        }
    }
}
