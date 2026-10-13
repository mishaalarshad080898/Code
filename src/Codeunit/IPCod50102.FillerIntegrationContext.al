/// <summary>
/// Session-level context flags for the filler integration. Inbound processing uses it to stop
/// outbound payloads while it re-releases documents internally. The quantity sync uses it
/// to allow its own controlled update of the Assembly Order quantity.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 Quantity & Document Control Assumptions (1) Quantity Ownership Transfers to Purchase Order
codeunit 50102 "IP Filler Integration Context"
{
    SingleInstance = true;

    var
        SuppressOutbound: Boolean;
        AllowAssemblyQtySync: Boolean;

    /// <summary>
    /// Turns suppression of outbound payloads (production request / BOM) on or off for this session.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points
    procedure SetSuppressOutbound(NewSuppressOutbound: Boolean)
    begin
        SuppressOutbound := NewSuppressOutbound;
    end;

    /// <summary>
    /// Returns true when outbound payloads must not be generated.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points
    procedure IsOutboundSuppressed(): Boolean
    begin
        exit(SuppressOutbound);
    end;

    /// <summary>
    /// Allows the next Assembly Order quantity validation to pass. Only the PO-to-AO quantity
    /// synchronization sets this.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 Quantity & Document Control Assumptions (1)
    procedure SetAllowAssemblyQtySync()
    begin
        AllowAssemblyQtySync := true;
    end;

    /// <summary>
    /// Reads and resets the one-time permission to change the Assembly Order quantity, so a
    /// failed transaction can never leave the restriction switched off.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.3 Quantity & Document Control Assumptions (1)
    procedure ConsumeAllowAssemblyQtySync(): Boolean
    var
        Allowed: Boolean;
    begin
        Allowed := AllowAssemblyQtySync;
        AllowAssemblyQtySync := false;
        exit(Allowed);
    end;

    /// <summary>
    /// Resets all context flags. Called after every inbound processing run.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (2) Payload Transmission Supports Retry and Reprocessing
    procedure ResetContext()
    begin
        SuppressOutbound := false;
        AllowAssemblyQtySync := false;
    end;
}
