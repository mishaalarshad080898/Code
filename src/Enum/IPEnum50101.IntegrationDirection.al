/// <summary>
/// Direction of an entry in the Filler Integration Activity Log: outbound payloads sent to the
/// filler, inbound payloads received from the filler, or internal automated BC processing.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (5) Operational Integration Visibility Is Centralized
enum 50101 "IP Integration Direction"
{
    Extensible = true;
    Caption = 'Integration Direction';

    value(0; Outbound)
    {
        Caption = 'Outbound';
    }
    value(1; Inbound)
    {
        Caption = 'Inbound';
    }
    value(2; Internal)
    {
        Caption = 'Internal';
    }
}
