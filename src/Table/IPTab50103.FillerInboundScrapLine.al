/// <summary>
/// Scrap declared by the filler on an inbound completion payload. Each line is loaded into the
/// predefined ICR SCRAP Item Journal Batch as a negative adjustment.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.13 Scrap Handling (ICR Scrap Integration)
table 50103 "IP Filler Inbound Scrap Line"
{
    Caption = 'Filler Inbound Scrap Line';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Inbound Entry No."; Integer)
        {
            Caption = 'Inbound Entry No.';
            TableRelation = "IP Filler Inbound Entry";
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
        }
        field(4; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(5; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Unit of Measure Code';
            TableRelation = "Item Unit of Measure".Code where("Item No." = field("Item No."));
        }
        field(6; "Lot No."; Code[50])
        {
            Caption = 'Lot No.';
        }
        field(7; "Reason Code"; Code[10])
        {
            Caption = 'Reason Code';
            TableRelation = "Reason Code";
        }
        field(8; Description; Text[100])
        {
            Caption = 'Description';
        }
    }

    keys
    {
        key(PK; "Inbound Entry No.", "Line No.")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        ScrapLine: Record "IP Filler Inbound Scrap Line";
    begin
        if Rec."Line No." <> 0 then
            exit;
        ScrapLine.SetRange("Inbound Entry No.", Rec."Inbound Entry No.");
        if ScrapLine.FindLast() then
            Rec."Line No." := ScrapLine."Line No." + 10000
        else
            Rec."Line No." := 10000;
    end;
}
