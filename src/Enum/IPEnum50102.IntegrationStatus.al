/// <summary>
/// Processing status of a Filler Integration Activity Log entry (success, failure/exception,
/// skipped, or still pending).
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 4.1 Operational Assumptions (5) Operational Visibility Is Centralized Within the Filler Integration Activity Log
enum 50102 "IP Integration Status"
{
    Extensible = true;
    Caption = 'Integration Status';

    value(0; Pending)
    {
        Caption = 'Pending';
    }
    value(1; Success)
    {
        Caption = 'Success';
    }
    value(2; Exception)
    {
        Caption = 'Exception';
    }
    value(3; Skipped)
    {
        Caption = 'Skipped';
    }
}
