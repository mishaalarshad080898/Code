/// <summary>
/// Writes Inventory Orchestration entries to the Filler Integration Activity Log: receipt of an
/// ICR movement, each validation and posting step, the Difarco hand-off and every failure.
/// Each entry carries the ICR movement and BC document references for monitoring.
/// </summary>
/// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility / 5.2 Integration Assumptions (4)
codeunit 50423 "IP ICR Movement Log Mgt"
{
    /// <summary>
    /// Logs a header-level step of an inbound ICR movement and returns the log Entry No.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility (Filler Integration Activity Log)
    procedure LogMovement(MovementHeader: Record "IP ICR Inbound Entry Header"; EventType: Enum "IP Integration Event Type"; Status: Enum "IP Integration Status"; Description: Text; ErrorText: Text): Integer
    var
        IntegrationLog: Record "IP Filler Integration Log";
    begin
        InitMovementLog(IntegrationLog, MovementHeader, EventType);
        exit(InsertLog(IntegrationLog, Status, Description, ErrorText));
    end;

    /// <summary>
    /// Logs a line-level step of an inbound ICR movement (quantity, price and physical filler lot)
    /// and returns the log Entry No. The physical lot is kept here for audit visibility only.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.5 Finished Goods Shipment Processing (physical lot retained in the activity log)
    procedure LogMovementLine(MovementHeader: Record "IP ICR Inbound Entry Header"; MovementLine: Record "IP ICR Inbound Entry Lines"; EventType: Enum "IP Integration Event Type"; Status: Enum "IP Integration Status"; Description: Text; ErrorText: Text): Integer
    var
        IntegrationLog: Record "IP Filler Integration Log";
    begin
        InitMovementLog(IntegrationLog, MovementHeader, EventType);
        IntegrationLog."Purchase Order Line No." := MovementLine."Item Line No";
        IntegrationLog.Quantity := MovementLine.Qty;
        IntegrationLog."Unit Price" := MovementLine.GetUnitPrice();
        IntegrationLog."Physical Lot No." := MovementLine."Physical Lot No.";
        exit(InsertLog(IntegrationLog, Status, Description, ErrorText));
    end;

    /// <summary>
    /// Logs an outbound trigger point step (PO release / TO shipment) for a BC document, for
    /// example a validation failure that stopped payload generation.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 6.3 Outbound Integration Trigger Points (Records processing activity / Records failures)
    procedure LogDocument(Direction: Enum "IP Integration Direction"; EventType: Enum "IP Integration Event Type"; Status: Enum "IP Integration Status"; VendorNo: Code[20]; DocType: Enum "IP Integration Doc. Type"; DocNo: Code[20]; Description: Text; ErrorText: Text): Integer
    var
        IntegrationLog: Record "IP Filler Integration Log";
    begin
        IntegrationLog.Init();
        IntegrationLog."Entry No." := 0;
        IntegrationLog.Direction := Direction;
        IntegrationLog."Event Type" := EventType;
        IntegrationLog."Vendor No." := VendorNo;
        IntegrationLog."Document Type" := DocType;
        IntegrationLog."Document No." := DocNo;
        if DocType = DocType::"Purchase Order" then
            IntegrationLog."Purchase Order No." := DocNo;
        exit(InsertLog(IntegrationLog, Status, Description, ErrorText));
    end;

    /// <summary>
    /// Fills in the common fields of a movement log entry, including the BC document the movement
    /// was posted against.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility
    local procedure InitMovementLog(var IntegrationLog: Record "IP Filler Integration Log"; MovementHeader: Record "IP ICR Inbound Entry Header"; EventType: Enum "IP Integration Event Type")
    begin
        IntegrationLog.Init();
        IntegrationLog."Entry No." := 0;
        IntegrationLog.Direction := IntegrationLog.Direction::Inbound;
        IntegrationLog."Event Type" := EventType;
        IntegrationLog."Vendor No." := MovementHeader."Vendor No.";
        IntegrationLog."ICR Inbound Entry No." := MovementHeader."Entry No.";
        IntegrationLog."Message ID" := MovementHeader."Message ID";
        IntegrationLog."Payload Timestamp" := MovementHeader."Received At";
        IntegrationLog."Retry Count" := MovementHeader."Retry Count";
        case MovementHeader."Source Document Type" of
            MovementHeader."Source Document Type"::"Purchase Order":
                begin
                    IntegrationLog."Document Type" := IntegrationLog."Document Type"::"Purchase Order";
                    IntegrationLog."Purchase Order No." := MovementHeader."Source Document No.";
                end;
            MovementHeader."Source Document Type"::"Transfer Order",
            MovementHeader."Source Document Type"::"FG Transfer Order":
                IntegrationLog."Document Type" := IntegrationLog."Document Type"::"Transfer Order";
        end;
        IntegrationLog."Document No." := MovementHeader."Source Document No.";
        if IntegrationLog."Document No." = '' then
            IntegrationLog."Document No." := MovementHeader."PO Number";
    end;

    /// <summary>
    /// Sets status, description and error text, then inserts the log entry.
    /// </summary>
    /// Comment - Functional Design Document for ICR - Inventory Orchestration - 3.5 Operational Visibility
    local procedure InsertLog(var IntegrationLog: Record "IP Filler Integration Log"; Status: Enum "IP Integration Status"; Description: Text; ErrorText: Text): Integer
    begin
        IntegrationLog.Status := Status;
        IntegrationLog.Description := CopyStr(Description, 1, MaxStrLen(IntegrationLog.Description));
        IntegrationLog."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(IntegrationLog."Error Message"));
        IntegrationLog.Insert(true);
        exit(IntegrationLog."Entry No.");
    end;
}
