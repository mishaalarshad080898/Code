/// <summary>
/// Type of BC document an outbound order message (Create / Update / Delete) was sent for. Used on
/// the Activity Log to find the last message sent for a document.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO
enum 50106 "IP Integration Doc. Type"
{
    Extensible = true;
    Caption = 'Integration Document Type';

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; "Production PO")
    {
        Caption = 'Production PO';
    }
    value(2; "Purchase Order")
    {
        Caption = 'Purchase Order';
    }
    value(3; "Transfer Order")
    {
        Caption = 'Transfer Order';
    }
}
