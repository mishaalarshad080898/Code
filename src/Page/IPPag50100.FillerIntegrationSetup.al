/// <summary>
/// Filler Integration Setup page. List page where integrated fillers are onboarded and set up:
/// vendor, filler location (1:1), integration enabled, middleware/API profile, endpoint and key,
/// and the ICR SCRAP journal batch.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup
page 50100 "IP Filler Integration Setup"
{
    Caption = 'Filler Integration Setup';
    PageType = List;
    SourceTable = "IP Filler Integration Setup";
    UsageCategory = Administration;
    ApplicationArea = All;

    layout
    {
        area(Content)
        {
            repeater(Fillers)
            {
                field("Vendor No."; Rec."Vendor No.")
                {
                    ToolTip = 'Specifies the vendor that represents the integrated filler.';
                }
                field("Filler Location Code"; Rec."Filler Location Code")
                {
                    ToolTip = 'Specifies the location where the filler holds IP inventory. One location per filler.';
                }
                field("Integration Enabled"; Rec."Integration Enabled")
                {
                    ToolTip = 'Specifies whether the filler integration is active for this vendor.';
                }
                field("API Profile Code"; Rec."API Profile Code")
                {
                    ToolTip = 'Specifies the middleware/API profile used for this filler.';
                }
                field("API Endpoint URL"; Rec."API Endpoint URL")
                {
                    ToolTip = 'Specifies the middleware endpoint that outbound payloads are posted to.';
                }
                field("API Auth Header Name"; Rec."API Auth Header Name")
                {
                    ToolTip = 'Specifies the HTTP header name used to send the API key.';
                }
                field(APIKey; APIKeyText)
                {
                    Caption = 'API Key';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies the API key. The key is kept in isolated storage, not in the database table.';

                    trigger OnValidate()
                    begin
                        Rec.SetAPIKey(APIKeyText);
                    end;
                }
                field("Scrap Jnl. Template Name"; Rec."Scrap Jnl. Template Name")
                {
                    ToolTip = 'Specifies the item journal template used for filler scrap.';
                }
                field("Scrap Jnl. Batch Name"; Rec."Scrap Jnl. Batch Name")
                {
                    ToolTip = 'Specifies the predefined item journal batch (ICR SCRAP) that scrap is loaded into.';
                }
                field("Auto Post Scrap"; Rec."Auto Post Scrap")
                {
                    ToolTip = 'Specifies whether scrap lines are posted automatically or left in the batch for user review.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(ActivityLog)
            {
                Caption = 'Filler Integration Activity Log';
                Image = Log;
                RunObject = page "IP Filler Integration Log";
                RunPageLink = "Vendor No." = field("Vendor No.");
                ToolTip = 'Open the Activity Log for this filler.';
            }
            action(InboundEntries)
            {
                Caption = 'Inbound Completions';
                Image = Import;
                RunObject = page "IP Filler Inbound Entries";
                RunPageLink = "Vendor No." = field("Vendor No.");
                ToolTip = 'Open the inbound completion payloads received from this filler.';
            }
        }
    }

    var
        APIKeyText: Text;
        MaskTok: Label '********', Locked = true;

    trigger OnAfterGetRecord()
    begin
        if Rec.HasAPIKey() then
            APIKeyText := MaskTok
        else
            APIKeyText := '';
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        APIKeyText := '';
    end;
}
