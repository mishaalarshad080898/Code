/// <summary>
/// Inbound filler completion payload (staging). The middleware inserts one record per
/// completion event through the Filler Completion API. The inbound quantity is authoritative.
/// Step flags (Quantities Synchronized, Receipt Posted, Output Posted, Scrap Posted) make
/// retry safe: steps that already posted are never posted twice.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing / 4.2 Integration Assumptions (1)(2)(3)
table 50102 "IP Filler Inbound Entry"
{
    Caption = 'Filler Inbound Entry';
    DataClassification = CustomerContent;
    LookupPageId = "IP Filler Inbound Entries";
    DrillDownPageId = "IP Filler Inbound Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Message ID"; Text[100])
        {
            Caption = 'Message ID';
        }
        field(3; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
        }
        field(4; "Assembly Order No."; Code[20])
        {
            Caption = 'Assembly Order No.';
        }
        field(5; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
        }
        field(6; "Purchase Order Line No."; Integer)
        {
            Caption = 'Purchase Order Line No.';
        }
        field(7; "Item No."; Code[20])
        {
            Caption = 'Finished Good Item No.';
            TableRelation = Item;
        }
        field(8; "Completed Quantity"; Decimal)
        {
            Caption = 'Completed Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(9; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            AutoFormatType = 2;
        }
        field(10; "Physical Lot No."; Code[50])
        {
            Caption = 'Physical Lot No. (Filler)';
        }
        field(11; "Payload Timestamp"; DateTime)
        {
            Caption = 'Payload Timestamp';
        }
        field(12; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(13; Status; Enum "IP Inbound Status")
        {
            Caption = 'Status';
            Editable = false;
        }
        field(14; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            Editable = false;
        }
        field(15; "Received At"; DateTime)
        {
            Caption = 'Received At';
            Editable = false;
        }
        field(16; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            Editable = false;
        }
        field(17; "Quantities Synchronized"; Boolean)
        {
            Caption = 'Quantities Synchronized';
            Editable = false;
        }
        field(18; "Receipt Posted"; Boolean)
        {
            Caption = 'Receipt Posted';
            Editable = false;
        }
        field(19; "Output Posted"; Boolean)
        {
            Caption = 'Output Posted';
            Editable = false;
        }
        field(20; "Scrap Posted"; Boolean)
        {
            Caption = 'Scrap Posted';
            Editable = false;
        }
        field(21; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            Editable = false;
        }
        field(22; "Posted Receipt No."; Code[20])
        {
            Caption = 'Posted Receipt No.';
            Editable = false;
            TableRelation = "Purch. Rcpt. Header";
        }
        field(23; "Posted Assembly No."; Code[20])
        {
            Caption = 'Posted Assembly Order No.';
            Editable = false;
            TableRelation = "Posted Assembly Header";
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(MessageID; "Message ID")
        {
        }
        key(StatusKey; Status)
        {
        }
        key(DuplicateCheck; "Vendor No.", "Purchase Order No.", "Payload Timestamp")
        {
        }
    }

    trigger OnInsert()
    begin
        Rec.Status := Rec.Status::Received;
        Rec."Received At" := CurrentDateTime();
    end;

    trigger OnDelete()
    var
        ScrapLine: Record "IP Filler Inbound Scrap Line";
    begin
        ScrapLine.SetRange("Inbound Entry No.", Rec."Entry No.");
        ScrapLine.DeleteAll(true);
    end;
}
