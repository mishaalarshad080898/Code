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
        LastSendError: Text;

    /// <summary>
    /// Sends a payload to the filler and logs the result. Returns true when the endpoint accepted it.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points
    procedure SendAndLog(FillerSetup: Record "IP Filler Integration Setup"; EventType: Enum "IP Integration Event Type"; AssemblyOrderNo: Code[20]; PurchaseOrderNo: Code[20]; PurchaseLineNo: Integer; MessageID: Text; PayloadText: Text; PayloadHash: Text; ParentEntryNo: Integer; Description: Text): Boolean
    var
        LogEntryNo: Integer;
    begin
        exit(SendAndLog(FillerSetup, EventType, AssemblyOrderNo, PurchaseOrderNo, PurchaseLineNo, MessageID, PayloadText, PayloadHash, ParentEntryNo, Description, LogEntryNo));
    end;

    /// <summary>
    /// Same as SendAndLog, but also returns the Activity Log Entry No. of the send, so the caller can
    /// enrich the entry or store the reference on the document it already holds.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points
    procedure SendAndLog(FillerSetup: Record "IP Filler Integration Setup"; EventType: Enum "IP Integration Event Type"; AssemblyOrderNo: Code[20]; PurchaseOrderNo: Code[20]; PurchaseLineNo: Integer; MessageID: Text; PayloadText: Text; PayloadHash: Text; ParentEntryNo: Integer; Description: Text; var LogEntryNo: Integer): Boolean
    var
        HttpStatusCode: Integer;
        ErrorText: Text;
        Sent: Boolean;
    begin
        Sent := SendPayload(FillerSetup, PayloadText, HttpStatusCode, ErrorText);
        LastSendError := ErrorText;
        if Sent then
            LogEntryNo := LogMgt.LogOutboundPayload(EventType, "IP Integration Status"::Success, FillerSetup."Vendor No.", AssemblyOrderNo, PurchaseOrderNo, PurchaseLineNo, MessageID, PayloadText, PayloadHash, HttpStatusCode, ParentEntryNo, Description, '')
        else
            LogEntryNo := LogMgt.LogOutboundPayload(EventType, "IP Integration Status"::Exception, FillerSetup."Vendor No.", AssemblyOrderNo, PurchaseOrderNo, PurchaseLineNo, MessageID, PayloadText, PayloadHash, HttpStatusCode, ParentEntryNo, Description, ErrorText);
        exit(Sent);
    end;

    /// <summary>
    /// Returns the error text of the last failed send (blank after a successful send).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 4.2 Integration Assumptions (2) Payload failures can occur
    procedure GetLastSendError(): Text
    begin
        exit(LastSendError);
    end;

    /// <summary>
    /// Manual retry ("Retry Request - Resend Payload"). Resends the stored payload of an outbound
    /// log entry, creates a new linked log entry and increases the retry count on the original.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.14 Outbound Trigger Points (Retry Request)
    procedure RetryLogEntry(var IntegrationLog: Record "IP Filler Integration Log"): Boolean
    var
        FillerSetup: Record "IP Filler Integration Setup";
        RetryLog: Record "IP Filler Integration Log";
        PayloadText: Text;
        Sent: Boolean;
        NewLogEntryNo: Integer;
    begin
        if IntegrationLog.Direction <> IntegrationLog.Direction::Outbound then
            Error(RetryOnlyOutboundErr);
        PayloadText := IntegrationLog.GetPayload();
        if PayloadText = '' then
            Error(RetryNoPayloadErr, IntegrationLog."Entry No.");
        FillerSetup.Get(IntegrationLog."Vendor No.");

        Sent := SendAndLog(FillerSetup, "IP Integration Event Type"::"Payload Retry", IntegrationLog."Assembly Order No.", IntegrationLog."Purchase Order No.", IntegrationLog."Purchase Order Line No.", IntegrationLog."Message ID", PayloadText, IntegrationLog."Payload Hash", IntegrationLog."Entry No.", StrSubstNo(RetryDescTxt, IntegrationLog."Entry No."), NewLogEntryNo);

        // Keep the document reference, so a successful retry counts as the last message sent for the document.
        if RetryLog.Get(NewLogEntryNo) then begin
            RetryLog."Document Type" := IntegrationLog."Document Type";
            RetryLog."Document No." := IntegrationLog."Document No.";
            RetryLog.Modify();
        end;

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
        Request.GetHeaders(RequestHeaders);
        AddAuthentication(FillerSetup, RequestHeaders);

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

    /// <summary>
    /// Adds the authentication header set up for the filler: an API key header, or Basic Auth
    /// ("Authorization: Basic base64(user:password)") with the PO user and password.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - Interface 3.1 PO/TO/ProdPO (Authentication: Basic Auth (PO User and Password))
    [NonDebuggable]
    local procedure AddAuthentication(FillerSetup: Record "IP Filler Integration Setup"; var RequestHeaders: HttpHeaders)
    var
        Base64Convert: Codeunit "Base64 Convert";
    begin
        case FillerSetup."Auth Type" of
            FillerSetup."Auth Type"::"API Key":
                if (FillerSetup."API Auth Header Name" <> '') and FillerSetup.HasAPIKey() then
                    RequestHeaders.Add(FillerSetup."API Auth Header Name", FillerSetup.GetAPIKey());
            FillerSetup."Auth Type"::Basic:
                if FillerSetup."API User Name" <> '' then
                    RequestHeaders.Add('Authorization', 'Basic ' + Base64Convert.ToBase64(FillerSetup."API User Name" + ':' + FillerSetup.GetAPIPassword()));
        end;
    end;
}
