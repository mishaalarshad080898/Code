/// <summary>
/// How BC authenticates against the filler middleware/API endpoint: no authentication, an API key
/// header, or Basic Auth (user name and password).
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Authentication: Basic Auth or any other method suggested by ICR)
enum 50105 "IP Filler Auth Type"
{
    Extensible = true;
    Caption = 'Filler Authentication Type';

    value(0; None)
    {
        Caption = 'None';
    }
    value(1; "API Key")
    {
        Caption = 'API Key';
    }
    value(2; Basic)
    {
        Caption = 'Basic';
    }
}
