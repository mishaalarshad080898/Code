/// <summary>
/// Writes entries to the Filler Integration Activity Log and maintains the Assembly Order
/// Filler Status. Every integration event, automated BC posting, validation failure and retry
/// goes through this codeunit.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.1 Operational Assumptions (5) / 4.2 Integration Assumptions (5)
codeunit 50101 "IP Filler Integration Log Mgt"
{
    var
        PayloadReceivedTxt: Label 'Inbound completion payload received.';

    /// <summary>
    /// Creates a log entry for a document-level event (AO / PO) and returns its Entry No.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (5) Operational Integration Visibility Is Centralized
    procedure LogEvent(Direction: Enum "IP Integration Direction"; EventType: Enum "IP Integration Event Type"; Status: Enum "IP Integration Status"; VendorNo: Code[20]; AssemblyOrderNo: Code[20]; PurchaseOrderNo: Code[20]; PurchaseLineNo: Integer; Description: Text; ErrorText: Text): Integer
    var
        IntegrationLog: Record "IP Filler Integration Log";
    begin
        InitLog(IntegrationLog, Direction, EventType, VendorNo, AssemblyOrderNo, PurchaseOrderNo, PurchaseLineNo);
        exit(InsertLog(IntegrationLog, Status, Description, ErrorText));
    end;

    /// <summary>
    /// Creates a log entry for an outbound payload, storing the payload, its hash, the HTTP
    /// status and any error, so the payload can be resent later.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points (Logged = Yes)
    procedure LogOutboundPayload(EventType: Enum "IP Integration Event Type"; Status: Enum "IP Integration Status"; VendorNo: Code[20]; AssemblyOrderNo: Code[20]; PurchaseOrderNo: Code[20]; PurchaseLineNo: Integer; MessageID: Text; PayloadText: Text; PayloadHash: Text; HttpStatusCode: Integer; ParentEntryNo: Integer; Description: Text; ErrorText: Text): Integer
    var
        IntegrationLog: Record "IP Filler Integration Log";
    begin
        InitLog(IntegrationLog, IntegrationLog.Direction::Outbound, EventType, VendorNo, AssemblyOrderNo, PurchaseOrderNo, PurchaseLineNo);
        IntegrationLog."Message ID" := CopyStr(MessageID, 1, MaxStrLen(IntegrationLog."Message ID"));
        IntegrationLog."Payload Timestamp" := CurrentDateTime();
        IntegrationLog."Payload Hash" := CopyStr(PayloadHash, 1, MaxStrLen(IntegrationLog."Payload Hash"));
        IntegrationLog."HTTP Status Code" := HttpStatusCode;
        IntegrationLog."Parent Entry No." := ParentEntryNo;
        IntegrationLog.SetPayload(PayloadText);
        exit(InsertLog(IntegrationLog, Status, Description, ErrorText));
    end;

    /// <summary>
    /// Logs receipt of an inbound completion payload. The physical filler lot is kept here for
    /// audit visibility only and is never written to BC finished-goods item tracking.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (Payload Receipt) / 5.10 Phantom Lot Assignment
    procedure LogInboundReceipt(InboundEntry: Record "IP Filler Inbound Entry")
    begin
        LogInbound(InboundEntry, "IP Integration Event Type"::"Inbound Payload Received", "IP Integration Status"::Success, PayloadReceivedTxt, '');
    end;

    /// <summary>
    /// Logs one inbound processing step (validation, receipt, output, scrap and so on) for an
    /// inbound completion entry and returns the log Entry No.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
    procedure LogInbound(InboundEntry: Record "IP Filler Inbound Entry"; EventType: Enum "IP Integration Event Type"; Status: Enum "IP Integration Status"; Description: Text; ErrorText: Text): Integer
    var
        IntegrationLog: Record "IP Filler Integration Log";
    begin
        InitLog(IntegrationLog, IntegrationLog.Direction::Inbound, EventType, InboundEntry."Vendor No.", InboundEntry."Assembly Order No.", InboundEntry."Purchase Order No.", InboundEntry."Purchase Order Line No.");
        IntegrationLog."Inbound Entry No." := InboundEntry."Entry No.";
        IntegrationLog."Message ID" := InboundEntry."Message ID";
        IntegrationLog."Payload Timestamp" := InboundEntry."Payload Timestamp";
        IntegrationLog.Quantity := InboundEntry."Completed Quantity";
        IntegrationLog."Unit Price" := InboundEntry."Unit Price";
        IntegrationLog."Physical Lot No." := InboundEntry."Physical Lot No.";
        IntegrationLog."Retry Count" := InboundEntry."Retry Count";
        exit(InsertLog(IntegrationLog, Status, Description, ErrorText));
    end;

    /// <summary>
    /// Updates the Filler Status on the Assembly Order, if the AO still exists. A fully posted AO
    /// is deleted by standard posting, so its history stays in the Activity Log.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.1 Assembly Order Creation (Filler Status)
    procedure UpdateFillerStatus(AssemblyOrderNo: Code[20]; NewStatus: Enum "IP Filler Status")
    var
        AssemblyHeader: Record "Assembly Header";
    begin
        if AssemblyOrderNo = '' then
            exit;
        if not AssemblyHeader.Get(AssemblyHeader."Document Type"::Order, AssemblyOrderNo) then
            exit;
        if AssemblyHeader."IP Filler Status" = NewStatus then
            exit;
        AssemblyHeader."IP Filler Status" := NewStatus;
        AssemblyHeader.Modify();
    end;

    /// <summary>
    /// Fills in the common fields of a new log entry.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (5)
    local procedure InitLog(var IntegrationLog: Record "IP Filler Integration Log"; Direction: Enum "IP Integration Direction"; EventType: Enum "IP Integration Event Type"; VendorNo: Code[20]; AssemblyOrderNo: Code[20]; PurchaseOrderNo: Code[20]; PurchaseLineNo: Integer)
    begin
        IntegrationLog.Init();
        IntegrationLog."Entry No." := 0;
        IntegrationLog.Direction := Direction;
        IntegrationLog."Event Type" := EventType;
        IntegrationLog."Vendor No." := VendorNo;
        IntegrationLog."Assembly Order No." := AssemblyOrderNo;
        IntegrationLog."Purchase Order No." := PurchaseOrderNo;
        IntegrationLog."Purchase Order Line No." := PurchaseLineNo;
    end;

    /// <summary>
    /// Sets status, description and error text, then inserts the log entry.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (5)
    local procedure InsertLog(var IntegrationLog: Record "IP Filler Integration Log"; Status: Enum "IP Integration Status"; Description: Text; ErrorText: Text): Integer
    begin
        IntegrationLog.Status := Status;
        IntegrationLog.Description := CopyStr(Description, 1, MaxStrLen(IntegrationLog.Description));
        IntegrationLog."Error Message" := CopyStr(ErrorText, 1, MaxStrLen(IntegrationLog."Error Message"));
        IntegrationLog.Insert(true);
        exit(IntegrationLog."Entry No.");
    end;
}
