/// <summary>
/// Filler Integration Activity Log. Central monitoring and exception table for every outbound
/// payload, inbound payload, automated BC posting step, validation failure and retry.
/// Entries are never overwritten, so prior payload history is retained.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.1 Operational Assumptions (5) / 4.2 Integration Assumptions (5)
table 50101 "IP Filler Integration Log"
{
    Caption = 'Filler Integration Activity Log';
    DataClassification = CustomerContent;
    LookupPageId = "IP Filler Integration Log";
    DrillDownPageId = "IP Filler Integration Log";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
        }
        field(3; Direction; Enum "IP Integration Direction")
        {
            Caption = 'Direction';
        }
        field(4; "Event Type"; Enum "IP Integration Event Type")
        {
            Caption = 'Event Type';
        }
        field(5; Status; Enum "IP Integration Status")
        {
            Caption = 'Status';
        }
        field(6; "Assembly Order No."; Code[20])
        {
            Caption = 'Assembly Order No.';
        }
        field(7; "Purchase Order No."; Code[20])
        {
            Caption = 'Purchase Order No.';
        }
        field(8; "Purchase Order Line No."; Integer)
        {
            Caption = 'Purchase Order Line No.';
        }
        field(9; "Inbound Entry No."; Integer)
        {
            Caption = 'Inbound Entry No.';
            TableRelation = "IP Filler Inbound Entry";
        }
        field(10; "Message ID"; Text[100])
        {
            Caption = 'Message ID';
        }
        field(11; "Payload Timestamp"; DateTime)
        {
            Caption = 'Payload Timestamp';
        }
        field(12; Payload; Blob)
        {
            Caption = 'Payload';
        }
        field(13; "Payload Hash"; Text[100])
        {
            Caption = 'Payload Hash';
        }
        field(14; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(15; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
        }
        field(16; "HTTP Status Code"; Integer)
        {
            Caption = 'HTTP Status Code';
        }
        field(17; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(18; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            AutoFormatType = 2;
        }
        field(19; "Physical Lot No."; Code[50])
        {
            Caption = 'Physical Lot No. (Filler)';
        }
        field(20; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
        }
        field(21; "Parent Entry No."; Integer)
        {
            Caption = 'Parent Entry No.';
            TableRelation = "IP Filler Integration Log";
        }
        field(22; "Created At"; DateTime)
        {
            Caption = 'Created At';
        }
        field(23; "Created By"; Code[50])
        {
            Caption = 'Created By';
            DataClassification = EndUserIdentifiableInformation;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(AssemblyOrder; "Assembly Order No.", "Event Type")
        {
        }
        key(PurchaseOrder; "Purchase Order No.")
        {
        }
        key(StatusKey; Status, Direction)
        {
        }
    }

    trigger OnInsert()
    begin
        Rec."Created At" := CurrentDateTime();
        Rec."Created By" := CopyStr(UserId(), 1, MaxStrLen(Rec."Created By"));
    end;

    /// <summary>
    /// Writes the payload text into the Payload blob so it can be retained and resent.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.7 Outbound BOM Transmission (Prior payload history retained)
    procedure SetPayload(PayloadText: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Rec.Payload);
        if PayloadText = '' then
            exit;
        Rec.Payload.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.WriteText(PayloadText);
    end;

    /// <summary>
    /// Reads the stored payload text from the Payload blob.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points (Retry Request - Resend Payload)
    procedure GetPayload(): Text
    var
        InStr: InStream;
        PayloadBuilder: TextBuilder;
        PayloadLine: Text;
    begin
        Rec.CalcFields(Payload);
        if not Rec.Payload.HasValue() then
            exit('');
        Rec.Payload.CreateInStream(InStr, TextEncoding::UTF8);
        while not InStr.EOS() do begin
            InStr.ReadText(PayloadLine);
            PayloadBuilder.Append(PayloadLine);
        end;
        exit(PayloadBuilder.ToText());
    end;
}
