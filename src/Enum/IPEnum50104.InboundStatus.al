/// <summary>
/// Processing status of an inbound filler completion payload.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing
enum 50104 "IP Inbound Status"
{
    Extensible = true;
    Caption = 'Inbound Status';

    value(0; Received)
    {
        Caption = 'Received';
    }
    value(1; Processed)
    {
        Caption = 'Processed';
    }
    value(2; Exception)
    {
        Caption = 'Exception';
    }
    value(3; Duplicate)
    {
        Caption = 'Duplicate';
    }
}
