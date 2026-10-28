/// <summary>
/// Business event recorded in the Filler Integration Activity Log. Covers the outbound trigger
/// points, inbound payload processing and each automated BC posting step.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points / 5.15 Inbound Payload Processing / Interface 3.1 PO/TO/ProdPO
enum 50103 "IP Integration Event Type"
{
    Extensible = true;
    Caption = 'Integration Event Type';

    value(0; "Create PO Link")
    {
        Caption = 'Create PO Link';
    }
    value(1; "Production Request")
    {
        Caption = 'Production Request';
    }
    value(2; "BOM Transmission")
    {
        Caption = 'BOM Transmission';
    }
    value(3; "BOM Resend")
    {
        Caption = 'BOM Resend';
    }
    value(4; "Payload Retry")
    {
        Caption = 'Payload Retry';
    }
    value(5; "Inbound Payload Received")
    {
        Caption = 'Inbound Payload Received';
    }
    value(6; "Inbound Validation")
    {
        Caption = 'Inbound Validation';
    }
    value(7; "Quantity Synchronization")
    {
        Caption = 'Quantity Synchronization';
    }
    value(8; "PO Receipt")
    {
        Caption = 'PO Receipt';
    }
    value(9; "Assembly Output")
    {
        Caption = 'Assembly Output';
    }
    value(10; "Phantom Lot Assignment")
    {
        Caption = 'Phantom Lot Assignment';
    }
    value(11; "Scrap Posting")
    {
        Caption = 'Scrap Posting';
    }
    value(12; "Inbound Processing")
    {
        Caption = 'Inbound Processing';
    }
    value(13; "PO Deleted")
    {
        Caption = 'PO Deleted';
    }
    value(14; "Purchase Order")
    {
        Caption = 'Purchase Order';
    }
    value(15; "Transfer Order")
    {
        Caption = 'Transfer Order';
    }
}
