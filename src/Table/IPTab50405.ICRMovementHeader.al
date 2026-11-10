/// <summary>
/// Header of an inbound ICR "Movement" payload (one JSON document = one header + posd lines).
/// Holds the ICR header fields (PO_NUMBER, HDTEXT, D_NUMBER, DOC_DATE, PSTNG_DATE, MVT_TYPE,
/// SPEC_STOCK), the processing status and the BC document the movement was posted against.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
table 50405 "IP ICR Movement Header"
{
    Caption = 'ICR Movement Header';
    DataClassification = CustomerContent;
    LookupPageId = "IP ICR Movements";
    DrillDownPageId = "IP ICR Movements";

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
        field(3; "PO Number"; Code[20])
        {
            Caption = 'Order No. (PO_NUMBER)';
        }
        field(4; "ICR Document No."; Text[150])
        {
            Caption = 'ICR Document No. (HDTEXT)';
        }
        field(5; "BOL No."; Text[35])
        {
            Caption = 'BOL No. (D_NUMBER)';
        }
        field(6; "Document Date"; Date)
        {
            Caption = 'Document Date (DOC_DATE)';
        }
        field(7; "Posting Date"; Date)
        {
            Caption = 'Posting Date (PSTNG_DATE)';
        }
        field(8; "Movement Type Code"; Code[10])
        {
            Caption = 'Movement Type Code (MVT_TYPE)';

            trigger OnValidate()
            begin
                Rec."Movement Type" := ParseMovementType(Rec."Movement Type Code");
            end;
        }
        field(9; "Movement Type"; Enum "IP ICR Movement Type")
        {
            Caption = 'Movement Type';
            Editable = false;
        }
        field(10; "Special Stock"; Code[10])
        {
            Caption = 'Special Stock (SPEC_STOCK)';
        }
        field(11; "Vendor No."; Code[20])
        {
            Caption = 'Filler Vendor No.';
            TableRelation = Vendor;
        }
        field(12; Status; Enum "IP Inbound Status")
        {
            Caption = 'Status';
            Editable = false;
        }
        field(13; "Source Document Type"; Enum "IP Movement Source Doc. Type")
        {
            Caption = 'Source Document Type';
            Editable = false;
        }
        field(14; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
            Editable = false;
        }
        field(15; "Posted Document No."; Code[20])
        {
            Caption = 'Posted Document No.';
            Editable = false;
        }
        field(16; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
            Editable = false;
        }
        field(17; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            Editable = false;
        }
        field(18; "Received At"; DateTime)
        {
            Caption = 'Received At';
            Editable = false;
        }
        field(19; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            Editable = false;
        }
        field(20; "TO Created"; Boolean)
        {
            Caption = 'Transfer Order Created';
            Editable = false;
        }
        field(21; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            FieldClass = FlowField;
            CalcFormula = count("IP ICR Movement Line" where("Entry No." = field("Entry No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(StatusKey; Status)
        {
        }
        key(MessageKey; "Message ID")
        {
        }
        key(DocumentKey; "Movement Type Code", "PO Number", "ICR Document No.")
        {
        }
    }

    trigger OnInsert()
    begin
        Rec."Received At" := CurrentDateTime();
        Rec."Movement Type" := ParseMovementType(Rec."Movement Type Code");
        if Rec."Posting Date" = 0D then
            Rec."Posting Date" := WorkDate();
        if Rec."Document Date" = 0D then
            Rec."Document Date" := Rec."Posting Date";
    end;

    trigger OnDelete()
    var
        MovementLine: Record "IP ICR Movement Line";
    begin
        // A processed movement is the audit trail of a posted document and is kept.
        if Rec.Status = Rec.Status::Processed then
            Rec.FieldError(Status);
        MovementLine.SetRange("Entry No.", Rec."Entry No.");
        MovementLine.DeleteAll(true);
    end;

    /// <summary>
    /// Converts the ICR MVT_TYPE code (for example '030' or '311') to the movement type enum.
    /// Unknown codes return blank, so validation can reject them.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Validate transaction)
    procedure ParseMovementType(MovementTypeCode: Code[10]): Enum "IP ICR Movement Type"
    var
        MovementTypeNo: Integer;
    begin
        if not Evaluate(MovementTypeNo, MovementTypeCode) then
            exit(Enum::"IP ICR Movement Type"::" ");
        if not Enum::"IP ICR Movement Type".Ordinals().Contains(MovementTypeNo) then
            exit(Enum::"IP ICR Movement Type"::" ");
        exit(Enum::"IP ICR Movement Type".FromInteger(MovementTypeNo));
    end;
}
