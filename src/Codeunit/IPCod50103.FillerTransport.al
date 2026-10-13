/// <summary>
/// Sends outbound JSON payloads to the filler middleware/API endpoint set up in Filler
/// Integration Setup. Every send, including manual retries, is written to the Activity Log.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points / 4.2 Integration Assumptions (2) Payload Transmission Supports Retry and Reprocessing
codeunit 50103 "IP Filler Transport"
{
    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        NoEndpointErr: Label 'No API Endpoint URL is set up for filler %1 in Filler Integration Setup.', Comment = '%1 = Vendor No.';
        HttpFailedErr: Label 'The filler endpoint returned HTTP %1: %2', Comment = '%1 = HTTP status code, %2 = response body';
        RetryOnlyOutboundErr: Label 'Only outbound payloads can be resent.';
        RetryNoPayloadErr: Label 'Log entry %1 has no stored payload to resend.', Comment = '%1 = Entry No.';
        RetryDescTxt: Label 'Resend of log entry %1.', Comment = '%1 = Entry No.';

    /// <summary>
    /// Sends a payload to the filler and logs the result. Returns true when the endpoint accepted it.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points
    procedure SendAndLog(FillerSetup: Record "IP Filler Integration Setup"; EventType: Enum "IP Integration Event Type"; AssemblyOrderNo: Code[20]; PurchaseOrderNo: Code[20]; PurchaseLineNo: Integer; MessageID: Text; PayloadText: Text; PayloadHash: Text; ParentEntryNo: Integer; Description: Text): Boolean
    var
        HttpStatusCode: Integer;
        ErrorText: Text;
        Sent: Boolean;
    begin
        Sent := SendPayload(FillerSetup, PayloadText, HttpStatusCode, ErrorText);
        if Sent then
            LogMgt.LogOutboundPayload(EventType, "IP Integration Status"::Success, FillerSetup."Vendor No.", AssemblyOrderNo, PurchaseOrderNo, PurchaseLineNo, MessageID, PayloadText, PayloadHash, HttpStatusCode, ParentEntryNo, Description, '')
        else
            LogMgt.LogOutboundPayload(EventType, "IP Integration Status"::Exception, FillerSetup."Vendor No.", AssemblyOrderNo, PurchaseOrderNo, PurchaseLineNo, MessageID, PayloadText, PayloadHash, HttpStatusCode, ParentEntryNo, Description, ErrorText);
        exit(Sent);
    end;

    /// <summary>
    /// Manual retry ("Retry Request - Resend Payload"). Resends the stored payload of an outbound
    /// log entry, creates a new linked log entry and increases the retry count on the original.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points (Retry Request)
    procedure RetryLogEntry(var IntegrationLog: Record "IP Filler Integration Log"): Boolean
    var
        FillerSetup: Record "IP Filler Integration Setup";
        PayloadText: Text;
        Sent: Boolean;
    begin
        if IntegrationLog.Direction <> IntegrationLog.Direction::Outbound then
            Error(RetryOnlyOutboundErr);
        PayloadText := IntegrationLog.GetPayload();
        if PayloadText = '' then
            Error(RetryNoPayloadErr, IntegrationLog."Entry No.");
        FillerSetup.Get(IntegrationLog."Vendor No.");

        Sent := SendAndLog(FillerSetup, "IP Integration Event Type"::"Payload Retry", IntegrationLog."Assembly Order No.", IntegrationLog."Purchase Order No.", IntegrationLog."Purchase Order Line No.", IntegrationLog."Message ID", PayloadText, IntegrationLog."Payload Hash", IntegrationLog."Entry No.", StrSubstNo(RetryDescTxt, IntegrationLog."Entry No."));

        IntegrationLog."Retry Count" += 1;
        IntegrationLog.Modify();
        exit(Sent);
    end;

    /// <summary>
    /// Posts the JSON payload to the filler endpoint over HTTP. Never throws: a failure is returned
    /// as false plus error text, so the caller's business transaction is not rolled back.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (2) Payload failures can occur
    [NonDebuggable]
    local procedure SendPayload(FillerSetup: Record "IP Filler Integration Setup"; PayloadText: Text; var HttpStatusCode: Integer; var ErrorText: Text): Boolean
    var
        Client: HttpClient;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        RequestHeaders: HttpHeaders;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ResponseText: Text;
    begin
        HttpStatusCode := 0;
        ErrorText := '';
        if FillerSetup."API Endpoint URL" = '' then begin
            ErrorText := StrSubstNo(NoEndpointErr, FillerSetup."Vendor No.");
            exit(false);
        end;

        Content.WriteFrom(PayloadText);
        Content.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        Request.Method := 'POST';
        Request.SetRequestUri(FillerSetup."API Endpoint URL");
        Request.Content := Content;
        if (FillerSetup."API Auth Header Name" <> '') and FillerSetup.HasAPIKey() then begin
            Request.GetHeaders(RequestHeaders);
            RequestHeaders.Add(FillerSetup."API Auth Header Name", FillerSetup.GetAPIKey());
        end;

        if not Client.Send(Request, Response) then begin
            ErrorText := GetLastErrorText();
            exit(false);
        end;

        HttpStatusCode := Response.HttpStatusCode();
        if not Response.IsSuccessStatusCode() then begin
            Response.Content().ReadAs(ResponseText);
            ErrorText := StrSubstNo(HttpFailedErr, HttpStatusCode, ResponseText);
            exit(false);
        end;
        exit(true);
    end;
}
