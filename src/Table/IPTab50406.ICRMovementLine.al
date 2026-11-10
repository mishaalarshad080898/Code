/// <summary>
/// Line (posd) of an inbound ICR "Movement" payload: BC line number (PO_ITEM), item (MATNR),
/// quantity (MENGE) and unit of measure (MEINS), plus the optional physical filler lot, which is
/// kept for audit visibility only when Phantom Lot processing applies.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
table 50406 "IP ICR Movement Line"
{
    Caption = 'ICR Movement Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            TableRelation = "IP ICR Movement Header";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "PO Item"; Integer)
        {
            Caption = 'BC Line No. (PO_ITEM)';
        }
        field(4; "Item No."; Code[20])
        {
            Caption = 'Item No. (MATNR)';
            TableRelation = Item;
            ValidateTableRelation = false;
        }
        field(5; Plant; Code[10])
        {
            Caption = 'Plant (WERKS)';
        }
        field(6; "Item Text"; Text[100])
        {
            Caption = 'Item Text (ITTEXT)';
        }
        field(7; "Storage Location"; Code[10])
        {
            Caption = 'Storage Location (LGORT)';
        }
        field(8; Quantity; Decimal)
        {
            Caption = 'Quantity (MENGE)';
            DecimalPlaces = 0 : 5;
        }
        field(9; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure (MEINS)';
        }
        field(10; "Final"; Code[10])
        {
            Caption = 'Final (FINAL)';
        }
        field(11; "Item OK"; Code[10])
        {
            Caption = 'Item OK (ITEM_OK)';
        }
        field(12; "Vendor No."; Code[20])
        {
            Caption = 'Vendor (LIFNR)';
        }
        field(13; "LBLKZ"; Code[10])
        {
            Caption = 'LBLKZ';
        }
        field(14; "Net Price"; Decimal)
        {
            Caption = 'Net Price (NETPR)';
            DecimalPlaces = 0 : 5;
        }
        field(15; "Price Unit"; Decimal)
        {
            Caption = 'Price Unit (PEINH)';
            DecimalPlaces = 0 : 5;
        }
        field(16; "Physical Lot No."; Code[50])
        {
            Caption = 'Physical Lot No. (Filler)';
        }
    }

    keys
    {
        key(PK; "Entry No.", "Line No.")
        {
            Clustered = true;
        }
        key(ItemKey; "Entry No.", "Item No.")
        {
        }
    }

    trigger OnInsert()
    var
        MovementLine: Record "IP ICR Movement Line";
    begin
        if Rec."Line No." <> 0 then
            exit;
        MovementLine.SetRange("Entry No.", Rec."Entry No.");
        if MovementLine.FindLast() then
            Rec."Line No." := MovementLine."Line No." + 10000
        else
            Rec."Line No." := 10000;
    end;

    /// <summary>
    /// Returns the unit price of the line: NETPR is the price for PEINH pieces.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Activity is logged)
    procedure GetUnitPrice(): Decimal
    begin
        if Rec."Price Unit" = 0 then
            exit(Rec."Net Price");
        exit(Rec."Net Price" / Rec."Price Unit");
    end;
}
