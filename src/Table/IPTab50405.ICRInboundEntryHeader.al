/// <summary>
/// Header of every inbound ICR payload ("Movement": one JSON = one header + posd lines), for both
/// FDDs. ICR-MRP integration v3 uses it for production PO completions (030 on a PO linked to an
/// Assembly Order), scrap (087) and adjustments (100 / 101). Inventory Orchestration uses it for raw
/// material receipts (030 on a normal PO or inbound TO) and finished goods transfers to the 3PL (311).
/// Step flags (Receipt / Output / Scrap Posted) and the Processed status make retry safe: nothing
/// that already posted is posted twice.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing / 4.2 Integration Assumptions (1)(2)(3)
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
table 50405 "IP ICR Inbound Entry Header"
{
    Caption = 'ICR Inbound Entry';
    DataClassification = CustomerContent;
    LookupPageId = "IP ICR Inbound Entries";
    DrillDownPageId = "IP ICR Inbound Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            DataClassification = SystemMetadata;
        }
        field(2; "PO Number"; Code[20]) // PO_NUMBER - Order No.
        {
            Caption = 'PO Number';
            DataClassification = CustomerContent;
        }
        field(3; "HD Text"; Text[150]) // HDTEXT - Document # in ICR system
        {
            Caption = 'HD Text';
            DataClassification = CustomerContent;
        }
        field(4; "D Number"; Code[35]) // D_NUMBER - BOL
        {
            Caption = 'D Number';
            DataClassification = CustomerContent;
        }
        field(5; "Document Date"; Date) // DOC_DATE
        {
            Caption = 'Document Date';
            DataClassification = CustomerContent;
        }
        field(6; "Posting Date"; Date) // PSTNG_DATE
        {
            Caption = 'Posting Date';
            DataClassification = CustomerContent;
        }
        field(7; "Mvt Type"; Code[10]) // MVT_TYPE
        {
            Caption = 'Mvt Type';
            DataClassification = CustomerContent;

            trigger OnValidate()
            begin
                Rec."Movement Type" := ParseMovementType(Rec."Mvt Type");
            end;
        }
        field(8; "Spec Stock"; Code[10]) // SPEC_STOCK - leave empty
        {
            Caption = 'Spec Stock';
            DataClassification = CustomerContent;
        }
        field(9; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            Editable = false;
        }
        field(10; "Posted Receipt No."; Code[20])
        {
            Caption = 'Posted Receipt No.';
            Editable = false;
            TableRelation = "Purch. Rcpt. Header";
        }
        field(11; "Posted Assembly Order No."; Code[20])
        {
            Caption = 'Posted Assembly Order No.';
            Editable = false;
            TableRelation = "Posted Assembly Header";
        }
        field(12; Status; Enum "IP Inbound Status")
        {
            Caption = 'Status';
            Editable = false;
        }
        field(13; "Received At"; DateTime)
        {
            Caption = 'Received At';
            Editable = false;
        }
        field(14; "Receipt Posted"; Boolean)
        {
            Caption = 'Receipt Posted';
            Editable = false;
            InitValue = false;
        }
        field(15; "Output Posted"; Boolean)
        {
            Caption = 'Output Posted';
            Editable = false;
            InitValue = false;
        }
        field(16; "Scrap Posted"; Boolean)
        {
            Caption = 'Scrap Posted';
            Editable = false;
            InitValue = false;
        }
        field(17; "Error Message"; Text[500])
        {
            Caption = 'Error Message';
            Editable = false;
        }
        field(18; "Posted Assembly No."; Code[20])
        {
            Caption = 'Posted Assembly No.';
            Editable = false;
        }
        field(19; "Message ID"; Text[100])
        {
            Caption = 'Message ID';
        }
        field(20; "Assembly Order No."; Code[20])
        {
            Caption = 'Assembly Order No.';
            Editable = false;
        }
        field(21; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            Editable = false;
        }
        // Fields 22-27: added for Inventory Orchestration.
        field(22; "Movement Type"; Enum "IP ICR Movement Type")
        {
            Caption = 'Movement Type';
            Editable = false;
        }
        field(23; "Vendor No."; Code[20])
        {
            Caption = 'Filler Vendor No.';
            TableRelation = Vendor;
        }
        field(24; "Source Document Type"; Enum "IP Movement Source Doc. Type")
        {
            Caption = 'Source Document Type';
            Editable = false;
        }
        field(25; "Source Document No."; Code[20])
        {
            Caption = 'Source Document No.';
            Editable = false;
        }
        field(26; "Posted Document No."; Code[20])
        {
            Caption = 'Posted Document No.';
            Editable = false;
        }
        field(27; "TO Created"; Boolean)
        {
            Caption = 'Transfer Order Created';
            Editable = false;
        }
        field(28; "No. of Lines"; Integer)
        {
            Caption = 'No. of Lines';
            FieldClass = FlowField;
            CalcFormula = count("IP ICR Inbound Entry Lines" where("Inbound Header Entry No." = field("Entry No.")));
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(StatusKey; Status, "Mvt Type")
        {
        }
        key(MessageKey; "Message ID")
        {
        }
        key(DocumentKey; "Mvt Type", "PO Number", "HD Text")
        {
        }
    }

    trigger OnInsert()
    begin
        CheckMovementType();
        Rec."Movement Type" := ParseMovementType(Rec."Mvt Type");
        Rec."Received At" := CurrentDateTime();
        Rec.Status := Rec.Status::Received;
        if Rec."Posting Date" = 0D then
            Rec."Posting Date" := WorkDate();
        if Rec."Document Date" = 0D then
            Rec."Document Date" := Rec."Posting Date";
        // The receipt is logged in OnAfterInsert (codeunit "IP ICR Movement Processing"): here the
        // AutoIncrement Entry No. is not assigned yet, so the log entry could not reference it.
    end;

    trigger OnDelete()
    var
        Line: Record "IP ICR Inbound Entry Lines";
    begin
        // A processed entry is the audit trail of a posted document and is kept.
        if Rec.Status = Rec.Status::Processed then
            Rec.FieldError(Status);
        Line.SetRange("Inbound Header Entry No.", Rec."Entry No.");
        if not Line.IsEmpty() then
            Line.DeleteAll();
    end;

    /// <summary>
    /// Rejects unknown movement types at insert and, for goods receipts (030) and scrap (087), links
    /// the entry to the Assembly Order of a production PO so the ICR-MRP process picks it up.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Validate payload)
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Validate transaction)
    local procedure CheckMovementType()
    var
        PurchaseHeader: Record "Purchase Header";
        UnsupportedMvtErr: Label 'MVT_TYPE %1 is not supported. Allowed: 030, 087, 100, 101, 122, 311.', Comment = '%1 = movement type';
    begin
        case Rec."Mvt Type" of
            '030', '087', '100', '101', '122', '311':
                ;
            else
                Error(UnsupportedMvtErr, Rec."Mvt Type");
        end;
        case Rec."Mvt Type" of
            '030', '087':
                if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, Rec."PO Number") then
                    Rec."Assembly Order No." := PurchaseHeader."IP Linked Assembly Order No.";
        end;
    end;

    /// <summary>
    /// True when the entry belongs to Inventory Orchestration: a raw material receipt (030 not linked
    /// to an Assembly Order), a finished goods transfer to the 3PL (311) or a positive / negative
    /// adjustment (100 / 101). All other entries are processed by the ICR-MRP inbound process.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 / 6.5 (one inbound table for both FDDs)
    procedure IsInventoryOrchestration(): Boolean
    begin
        case Rec."Mvt Type" of
            '030':
                exit(Rec."Assembly Order No." = '');
            '311', '100', '101':
                exit(true);
        end;
        exit(false);
    end;

    /// <summary>
    /// Converts the ICR MVT_TYPE code (for example '030' or '311') to the movement type enum.
    /// Unknown codes return blank.
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
