/// <summary>
/// Filler Integration Setup. One record per integrated filler (vendor). It controls whether
/// integration is enabled, which filler location is used (1:1 with the vendor), the
/// middleware/API profile, and the scrap journal batch used for ICR scrap posting.
/// New fillers are onboarded by adding a record here, so nothing is hard-coded.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
table 50100 "IP Filler Integration Setup"
{
    Caption = 'Filler Integration Setup';
    DataClassification = CustomerContent;
    LookupPageId = "IP Filler Integration Setup";
    DrillDownPageId = "IP Filler Integration Setup";

    fields
    {
        field(1; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
            NotBlank = true;
        }
        field(2; "Filler Location Code"; Code[10])
        {
            Caption = 'Filler Location Code';
            TableRelation = Location;

            trigger OnValidate()
            begin
                CheckLocationIsUnique();
            end;
        }
        field(3; "Integration Enabled"; Boolean)
        {
            Caption = 'Integration Enabled';
        }
        field(4; "API Profile Code"; Code[20])
        {
            Caption = 'Middleware/API Profile';
        }
        field(5; "API Endpoint URL"; Text[250])
        {
            Caption = 'API Endpoint URL';
            ExtendedDatatype = URL;
        }
        field(6; "API Auth Header Name"; Text[100])
        {
            Caption = 'API Auth Header Name';
            InitValue = 'x-api-key';
        }
        field(7; "Scrap Jnl. Template Name"; Code[10])
        {
            Caption = 'Scrap Journal Template Name';
            TableRelation = "Item Journal Template" where(Type = const(Item));
        }
        field(8; "Scrap Jnl. Batch Name"; Code[10])
        {
            Caption = 'Scrap Journal Batch Name';
            TableRelation = "Item Journal Batch".Name where("Journal Template Name" = field("Scrap Jnl. Template Name"));
            InitValue = 'ICR SCRAP';
        }
        field(9; "Auto Post Scrap"; Boolean)
        {
            Caption = 'Auto Post Scrap';
            InitValue = true;
        }
    }

    keys
    {
        key(PK; "Vendor No.")
        {
            Clustered = true;
        }
        key(Location; "Filler Location Code")
        {
        }
    }

    var
        LocationAlreadyUsedErr: Label 'Filler Location %1 is already assigned to vendor %2. Vendor and filler location must be a 1:1 relationship.', Comment = '%1 = Location Code, %2 = Vendor No.';
        APIKeyStorageKeyTok: Label 'IPFillerAPIKey-%1', Locked = true, Comment = '%1 = Setup SystemId';

    trigger OnDelete()
    begin
        DeleteAPIKey();
    end;

    /// <summary>
    /// Ensures a filler location is assigned to only one vendor (1:1 relationship).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    local procedure CheckLocationIsUnique()
    var
        FillerSetup: Record "IP Filler Integration Setup";
    begin
        if Rec."Filler Location Code" = '' then
            exit;
        FillerSetup.SetRange("Filler Location Code", Rec."Filler Location Code");
        FillerSetup.SetFilter("Vendor No.", '<>%1', Rec."Vendor No.");
        if FillerSetup.FindFirst() then
            Error(LocationAlreadyUsedErr, Rec."Filler Location Code", FillerSetup."Vendor No.");
    end;

    /// <summary>
    /// Finds the integration-enabled filler setup for a location. Used to decide whether an
    /// Assembly Order belongs to an integrated filler.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    procedure GetEnabledByLocation(LocationCode: Code[10]): Boolean
    begin
        if LocationCode = '' then
            exit(false);
        Rec.Reset();
        Rec.SetRange("Filler Location Code", LocationCode);
        Rec.SetRange("Integration Enabled", true);
        exit(Rec.FindFirst());
    end;

    /// <summary>
    /// Stores the middleware/API key in isolated storage so it is never kept in a table field.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    [NonDebuggable]
    procedure SetAPIKey(NewAPIKey: Text)
    begin
        if NewAPIKey = '' then begin
            DeleteAPIKey();
            exit;
        end;
        IsolatedStorage.Set(GetAPIKeyStorageKey(), NewAPIKey, DataScope::Company);
    end;

    /// <summary>
    /// Returns the middleware/API key from isolated storage.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    [NonDebuggable]
    procedure GetAPIKey(): Text
    var
        APIKey: Text;
    begin
        if IsolatedStorage.Get(GetAPIKeyStorageKey(), DataScope::Company, APIKey) then
            exit(APIKey);
        exit('');
    end;

    /// <summary>
    /// Returns true when an API key has been stored for this filler.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    procedure HasAPIKey(): Boolean
    begin
        exit(IsolatedStorage.Contains(GetAPIKeyStorageKey(), DataScope::Company));
    end;

    /// <summary>
    /// Removes the stored middleware/API key.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    local procedure DeleteAPIKey()
    begin
        if IsolatedStorage.Contains(GetAPIKeyStorageKey(), DataScope::Company) then
            IsolatedStorage.Delete(GetAPIKeyStorageKey(), DataScope::Company);
    end;

    /// <summary>
    /// Builds the isolated storage key for this setup record.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
    local procedure GetAPIKeyStorageKey(): Text
    begin
        exit(StrSubstNo(APIKeyStorageKeyTok, Format(Rec.SystemId, 0, 4)));
    end;
}
