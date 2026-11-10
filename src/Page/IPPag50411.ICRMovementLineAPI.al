/// <summary>
/// API part for the posd lines of an inbound ICR movement (used in the deep insert).
/// Field names follow the ICR JSON (PO_ITEM, MATNR, MENGE, MEINS ...).
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
page 50411 "IP ICR Movement Line API"
{
    PageType = API;
    APIPublisher = 'interparfums';
    APIGroup = 'fillerIntegration';
    APIVersion = 'v1.0';
    EntityName = 'icrMovementLine';
    EntitySetName = 'icrMovementLines';
    EntityCaption = 'ICR Movement Line';
    EntitySetCaption = 'ICR Movement Lines';
    SourceTable = "IP ICR Movement Line";
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
                field(entryNo; Rec."Entry No.")
                {
                    Caption = 'Entry No.';
                }
                field(lineNo; Rec."Line No.")
                {
                    Caption = 'Line No.';
                }
                field(poItem; Rec."PO Item")
                {
                    Caption = 'PO_ITEM';
                }
                field(matnr; Rec."Item No.")
                {
                    Caption = 'MATNR';
                }
                field(werks; Rec.Plant)
                {
                    Caption = 'WERKS';
                }
                field(itText; Rec."Item Text")
                {
                    Caption = 'ITTEXT';
                }
                field(lgort; Rec."Storage Location")
                {
                    Caption = 'LGORT';
                }
                field(menge; Rec.Quantity)
                {
                    Caption = 'MENGE';
                }
                field(meins; Rec."Unit of Measure Code")
                {
                    Caption = 'MEINS';
                }
                field(final; Rec."Final")
                {
                    Caption = 'FINAL';
                }
                field(itemOk; Rec."Item OK")
                {
                    Caption = 'ITEM_OK';
                }
                field(lifnr; Rec."Vendor No.")
                {
                    Caption = 'LIFNR';
                }
                field(lblkz; Rec.LBLKZ)
                {
                    Caption = 'LBLKZ';
                }
                field(netpr; Rec."Net Price")
                {
                    Caption = 'NETPR';
                }
                field(peinh; Rec."Price Unit")
                {
                    Caption = 'PEINH';
                }
                field(physicalLotNo; Rec."Physical Lot No.")
                {
                    Caption = 'Physical Lot No.';
                }
            }
        }
    }
}
