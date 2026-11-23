/// <summary>
/// API part for the posd lines of an inbound ICR entry (used in the deep insert).
/// Field names follow the ICR JSON (PO_ITEM, MATNR, MENGE, MEINS ...).
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
page 50411 "IP ICR Inbound Entry Line API"
{
    PageType = API;
    APIPublisher = 'interparfums';
    APIGroup = 'fillerIntegration';
    APIVersion = 'v1.0';
    EntityName = 'icrInboundEntryLine';
    EntitySetName = 'icrInboundEntryLines';
    EntityCaption = 'ICR Inbound Entry Line';
    EntitySetCaption = 'ICR Inbound Entry Lines';
    SourceTable = "IP ICR Inbound Entry Lines";
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
                    Editable = false;
                }
                field(inboundHeaderEntryNo; Rec."Inbound Header Entry No.")
                {
                    Caption = 'Inbound Header Entry No.';
                }
                field(poItem; Rec."Item Line No")
                {
                    Caption = 'PO_ITEM';
                }
                field(matnr; Rec."Item No.")
                {
                    Caption = 'MATNR';
                }
                field(werks; Rec.WERKS)
                {
                    Caption = 'WERKS';
                }
                field(itText; Rec.ITTEXT)
                {
                    Caption = 'ITTEXT';
                }
                field(lgort; Rec."Location Code")
                {
                    Caption = 'LGORT';
                }
                field(menge; Rec.Qty)
                {
                    Caption = 'MENGE';
                }
                field(meins; Rec."Unit of Measure")
                {
                    Caption = 'MEINS';
                }
                field(final; Rec.FINAL)
                {
                    Caption = 'FINAL';
                }
                field(itemOk; Rec.ITEM_OK)
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
                field(netpr; Rec.NETPR)
                {
                    Caption = 'NETPR';
                }
                field(peinh; Rec.PEINH)
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
