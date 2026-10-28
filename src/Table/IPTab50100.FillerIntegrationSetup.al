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
        field(10; "Auth Type"; Enum "IP Filler Auth Type")
        {
            Caption = 'Authentication Type';
            InitValue = Basic;
        }
        field(11; "API User Name"; Text[100])
        {
            Caption = 'API User Name';
        }
        field(12; "ICR Company Code"; Code[10])
        {
            Caption = 'Company Code (bukrs)';
            InitValue = '1000';
        }
        field(13; "ICR Purch. Organization"; Code[10])
        {
            Caption = 'Purchasing Organization (ekorg)';
            InitValue = '1000';
        }
        field(14; "ICR Purch. Group"; Code[10])
        {
            Caption = 'Purchasing Group (ekgrp)';
            InitValue = '010';
        }
        field(15; "ICR Plant"; Code[10])
        {
            Caption = 'Plant (werks)';
            InitValue = '1000';
        }
        field(16; "Prod. PO Order Type"; Code[10])
        {
            Caption = 'Production PO Order Type (bsart)';
            InitValue = 'ZFER';
        }
        field(17; "Purch. Order Type"; Code[10])
        {
            Caption = 'Purchase Order Type (bsart)';
            InitValue = 'ZRFE';
        }
        field(18; "Transfer Order Type"; Code[10])
        {
            Caption = 'Transfer Order Type (bsart)';
            InitValue = 'ZRFE';
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
        APIPasswordStorageKeyTok: Label 'IPFillerAPIPwd-%1', Locked = true, Comment = '%1 = Setup SystemId';

    trigger OnDelete()
    begin
        DeleteAPIKey();
        SetAPIPassword('');
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
    /// Stores the Basic Auth password (PO user password) in isolated storage. Blank removes it.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Authentication: Basic Auth)
    [NonDebuggable]
    procedure SetAPIPassword(NewPassword: Text)
    begin
        if NewPassword = '' then begin
            if IsolatedStorage.Contains(GetAPIPasswordStorageKey(), DataScope::Company) then
                IsolatedStorage.Delete(GetAPIPasswordStorageKey(), DataScope::Company);
            exit;
        end;
        IsolatedStorage.Set(GetAPIPasswordStorageKey(), NewPassword, DataScope::Company);
    end;

    /// <summary>
    /// Returns the Basic Auth password from isolated storage.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Authentication: Basic Auth)
    [NonDebuggable]
    procedure GetAPIPassword(): Text
    var
        APIPassword: Text;
    begin
        if IsolatedStorage.Get(GetAPIPasswordStorageKey(), DataScope::Company, APIPassword) then
            exit(APIPassword);
        exit('');
    end;

    /// <summary>
    /// Returns true when a Basic Auth password has been stored for this filler.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Authentication: Basic Auth)
    procedure HasAPIPassword(): Boolean
    begin
        exit(IsolatedStorage.Contains(GetAPIPasswordStorageKey(), DataScope::Company));
    end;

    /// <summary>
    /// Builds the isolated storage key for the Basic Auth password.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Authentication: Basic Auth)
    local procedure GetAPIPasswordStorageKey(): Text
    begin
        exit(StrSubstNo(APIPasswordStorageKeyTok, Format(Rec.SystemId, 0, 4)));
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
