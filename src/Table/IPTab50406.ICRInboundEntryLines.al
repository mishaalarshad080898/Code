/// <summary>
/// Lines (posd) of an inbound ICR payload, for both FDDs: BC line number (PO_ITEM), item (MATNR),
/// quantity (MENGE), unit of measure (MEINS), price (NETPR / PEINH) and the optional physical filler
/// lot. For phantom-lot finished goods the physical lot is kept for audit visibility only.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
table 50406 "IP ICR Inbound Entry Lines"
{
    Caption = 'ICR Inbound Entry Lines';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Item Line No"; Integer) // PO_ITEM - BC document line no.
        {
            Caption = 'Line No.';
        }
        field(2; "Item No."; Code[20]) // MATNR
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
            ValidateTableRelation = false;
        }
        field(3; "WERKS"; Text[10]) // 1000 default
        {
            Caption = 'WERKS';
        }
        field(4; "ITTEXT"; Text[100]) // leave empty
        {
            Caption = 'ITTEXT';
        }
        field(5; "Location Code"; Code[10]) // LGORT - warehouse (used in adjustments)
        {
            Caption = 'Location Code';
        }
        field(6; "Qty"; Decimal) // MENGE
        {
            Caption = 'Qty';
            DecimalPlaces = 0 : 5;
        }
        field(7; "Unit of Measure"; Code[10]) // MEINS
        {
            Caption = 'Unit of Measure';
        }
        field(8; "FINAL"; Text[10]) // Used for partials - X is when the final operation
        {
            Caption = 'FINAL';
        }
        field(9; "ITEM_OK"; Text[10])
        {
            Caption = 'ITEM_OK';
        }
        field(10; "Vendor No."; Code[20]) // LIFNR
        {
            Caption = 'Vendor No.';
        }
        field(11; "LBLKZ"; Text[10]) // leave empty
        {
            Caption = 'LBLKZ';
        }
        field(12; "Receipt Posted"; Boolean)
        {
            Caption = 'Receipt Posted';
            Editable = false;
        }
        field(13; "NETPR"; Decimal) // Price unit
        {
            Caption = 'NETPR';
            DecimalPlaces = 0 : 5;
        }
        field(14; "PEINH"; Decimal) // For how many pieces (multiplier factor)
        {
            Caption = 'PEINH';
            DecimalPlaces = 0 : 5;
        }
        field(15; "Inbound Header Entry No."; Integer)
        {
            Caption = 'Inbound Header Entry No.';
            TableRelation = "IP ICR Inbound Entry Header";
        }
        field(16; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        // Field 17: added for both FDDs (phantom lot / raw-material lot).
        field(17; "Physical Lot No."; Code[50])
        {
            Caption = 'Physical Lot No. (Filler)';
        }
    }

    keys
    {
        key(PK; "Entry No.", "Inbound Header Entry No.")
        {
            Clustered = true;
        }
        key(HeaderKey; "Inbound Header Entry No.", "Item Line No")
        {
        }
    }

    /// <summary>
    /// Returns the unit price of the line: NETPR is the price for PEINH pieces.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Activity is logged)
    procedure GetUnitPrice(): Decimal
    begin
        if Rec.PEINH = 0 then
            exit(Rec.NETPR);
        exit(Rec.NETPR / Rec.PEINH);
    end;
}
