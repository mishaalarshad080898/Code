/// <summary>
/// Permission set for users of the filler integration and the Filler Integration Activity Log.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.1 Operational Assumptions (5) / 5.5 Filler Integration Setup
permissionset 50100 "IP FILLER INTEG"
{
    Caption = 'IP Filler Integration';
    Assignable = true;

    Permissions =
        tabledata "IP Filler Integration Setup" = RIMD,
        tabledata "IP Filler Integration Log" = RIMD,
        tabledata "IP Filler Inbound Entry" = RIMD,
        tabledata "IP Filler Inbound Scrap Line" = RIMD,
        table "IP Filler Integration Setup" = X,
        table "IP Filler Integration Log" = X,
        table "IP Filler Inbound Entry" = X,
        table "IP Filler Inbound Scrap Line" = X,
        page "IP Filler Integration Setup" = X,
        page "IP Filler Integration Log" = X,
        page "IP Filler Inbound Entries" = X,
        page "IP Filler Inbound Entry" = X,
        page "IP Filler Inbound Scrap Sub." = X,
        page "IP Filler Completion API" = X,
        page "IP Filler Scrap Line API" = X,
        codeunit "IP Create PO Link" = X,
        codeunit "IP Filler Integration Log Mgt" = X,
        codeunit "IP Filler Integration Context" = X,
        codeunit "IP Filler Transport" = X,
        codeunit "IP Outbound Prod. Request" = X,
        codeunit "IP Outbound BOM Transmission" = X,
        codeunit "IP Assembly Order Events" = X,
        codeunit "IP Purchase Order Events" = X,
        codeunit "IP Inbound Validation" = X,
        codeunit "IP Inbound Posting" = X,
        codeunit "IP Inbound Processing" = X,
        codeunit "IP Inbound Job Queue" = X,
        codeunit "IP Phantom Lot Mgt" = X,
        codeunit "IP Scrap Posting" = X,
        codeunit "IP Quantity Synchronization" = X;
}
