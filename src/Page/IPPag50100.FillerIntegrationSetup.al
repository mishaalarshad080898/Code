/// <summary>
/// Filler Integration Setup page. List page where integrated fillers are onboarded and set up:
/// vendor, filler location (1:1), integration enabled, middleware/API profile, endpoint and key,
/// and the ICR SCRAP journal batch.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.5 Filler Integration Setup / Interface 3.1 PO/TO/ProdPO
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
                field("Auth Type"; Rec."Auth Type")
                {
                    ToolTip = 'Specifies how BC authenticates against the filler endpoint: Basic (PO user and password), API Key, or None.';
                }
                field("API User Name"; Rec."API User Name")
                {
                    ToolTip = 'Specifies the PO user name for Basic authentication.';
                }
                field(APIPassword; APIPasswordText)
                {
                    Caption = 'API Password';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies the PO user password for Basic authentication. The password is kept in isolated storage, not in the database table.';

                    trigger OnValidate()
                    begin
                        Rec.SetAPIPassword(APIPasswordText);
                    end;
                }
                field("API Auth Header Name"; Rec."API Auth Header Name")
                {
                    ToolTip = 'Specifies the HTTP header name used to send the API key (Authentication Type = API Key).';
                }
                field(APIKey; APIKeyText)
                {
                    Caption = 'API Key';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies the API key (Authentication Type = API Key). The key is kept in isolated storage, not in the database table.';

                    trigger OnValidate()
                    begin
                        Rec.SetAPIKey(APIKeyText);
                    end;
                }
                field("ICR Company Code"; Rec."ICR Company Code")
                {
                    ToolTip = 'Specifies the company code sent as bukrs in the order message (default 1000).';
                }
                field("ICR Purch. Organization"; Rec."ICR Purch. Organization")
                {
                    ToolTip = 'Specifies the purchasing organization sent as ekorg in the order message (default 1000).';
                }
                field("ICR Purch. Group"; Rec."ICR Purch. Group")
                {
                    ToolTip = 'Specifies the purchasing group sent as ekgrp in the order message (default 010).';
                }
                field("ICR Plant"; Rec."ICR Plant")
                {
                    ToolTip = 'Specifies the plant sent as werks on each order line (default 1000).';
                }
                field("Prod. PO Order Type"; Rec."Prod. PO Order Type")
                {
                    ToolTip = 'Specifies the order type (bsart) sent for production POs linked to an Assembly Order.';
                }
                field("Purch. Order Type"; Rec."Purch. Order Type")
                {
                    ToolTip = 'Specifies the order type (bsart) sent for purchase orders delivered to the filler location.';
                }
                field("Transfer Order Type"; Rec."Transfer Order Type")
                {
                    ToolTip = 'Specifies the order type (bsart) sent for transfer orders to the filler location.';
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
        APIPasswordText: Text;
        MaskTok: Label '********', Locked = true;

    trigger OnAfterGetRecord()
    begin
        if Rec.HasAPIKey() then
            APIKeyText := MaskTok
        else
            APIKeyText := '';
        if Rec.HasAPIPassword() then
            APIPasswordText := MaskTok
        else
            APIPasswordText := '';
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        APIKeyText := '';
        APIPasswordText := '';
    end;
}
