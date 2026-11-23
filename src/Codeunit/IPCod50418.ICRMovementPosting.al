/// <summary>
/// Runs one inbound ICR movement as a single unit of work: validate, then route by movement type.
/// 030 Goods Receipt posts the Purchase Order or inbound Transfer Order receipt; 311 Transfer to
/// 3PL finds or creates the finished goods Transfer Order and posts the shipment. It is started
/// with Codeunit.Run, so any error rolls back the whole movement and nothing is posted.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing / 6.5 Finished Goods Shipment Processing
codeunit 50418 "IP ICR Movement Posting"
{
    TableNo = "IP ICR Inbound Entry Header";

    var
        Validation: Codeunit "IP ICR Movement Validation";
        RawMaterialReceipt: Codeunit "IP Raw Material Receipt";
        FGShipmentProcessing: Codeunit "IP FG Shipment Processing";
        MovementLogMgt: Codeunit "IP ICR Movement Log Mgt";
        ValidatedTxt: Label 'ICR movement %1 validated against %2 %3.', Comment = '%1 = Entry No., %2 = Document type, %3 = Document No.';

    trigger OnRun()
    var
        MovementHeader: Record "IP ICR Inbound Entry Header";
    begin
        MovementHeader.Get(Rec."Entry No.");
        ProcessMovement(MovementHeader);
        Rec := MovementHeader;
    end;

    /// <summary>
    /// Validates the payload and starts the BC transaction for its movement type.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Receives payload, Validates transaction, Processes receipt)
    local procedure ProcessMovement(var MovementHeader: Record "IP ICR Inbound Entry Header")
    begin
        Validation.ValidateHeaderAndLines(MovementHeader);
        case MovementHeader."Movement Type" of
            MovementHeader."Movement Type"::"Goods Receipt":
                ProcessGoodsReceipt(MovementHeader);
            MovementHeader."Movement Type"::"Transfer to 3PL":
                FGShipmentProcessing.ProcessShipment(MovementHeader);
        end;
    end;

    /// <summary>
    /// Goods Receipt (030): resolves the Purchase Order or inbound Transfer Order, validates the
    /// lines and quantities, then posts the receipt.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Purchase Order receipt OR Transfer Order receipt)
    local procedure ProcessGoodsReceipt(var MovementHeader: Record "IP ICR Inbound Entry Header")
    begin
        Validation.ResolveGoodsReceiptSource(MovementHeader);
        MovementHeader.Modify();
        case MovementHeader."Source Document Type" of
            MovementHeader."Source Document Type"::"Purchase Order":
                begin
                    Validation.ValidatePurchaseReceipt(MovementHeader);
                    LogValidated(MovementHeader);
                    RawMaterialReceipt.PostPurchaseReceipt(MovementHeader);
                end;
            MovementHeader."Source Document Type"::"Transfer Order":
                begin
                    Validation.ValidateTransferReceipt(MovementHeader);
                    LogValidated(MovementHeader);
                    RawMaterialReceipt.PostTransferReceipt(MovementHeader);
                end;
        end;
    end;

    /// <summary>
    /// Logs the successful validation step.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.4 Inbound Raw Material Receipt Processing (Validates transaction / Updates Activity Log)
    local procedure LogValidated(MovementHeader: Record "IP ICR Inbound Entry Header")
    begin
        MovementLogMgt.LogMovement(MovementHeader, "IP Integration Event Type"::"ICR Movement Validation", "IP Integration Status"::Success,
            StrSubstNo(ValidatedTxt, MovementHeader."Entry No.", MovementHeader."Source Document Type", MovementHeader."Source Document No."), '');
    end;
}
