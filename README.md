# IP ICR-MRP Filler Integration (Business Central AL)

AL extension implementing the **Functional Design Document for ICR-MRP integration v3** (v3.1, phantom lot).
Every object and procedure carries a header comment of the form:

```al
/// <summary>
/// What the process does
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - <FDD section>
```

File naming: `IP<ObjectType><ObjectId>.<ObjectName>.al` (one object per file), e.g. `IPCod50100.CreatePOLink.al`.

## Object map

| FDD section | Objects |
|---|---|
| 5.1 Assembly Order Creation | `IPTabExt50100.AssemblyHeader`, `IPPagExt50100.AssemblyOrder`, `IPPagExt50101.AssemblyOrders`, `IPEnum50100.FillerStatus` |
| 5.2 Create PO Link Function | `IPCod50100.CreatePOLink`, `IPCod50106.AssemblyOrderEvents` (AO release blocked until Linked PO Released) |
| 5.3 Purchase Order Creation | `IPTabExt50102.PurchaseHeader`, `IPTabExt50103.PurchaseLine`, `IPTabExt50105.Item` (Fill Item), `IPPagExt50102.PurchaseOrder` |
| 5.4 PO Receipt Processing & Production Sync | `IPCod50109.InboundPosting`, `IPCod50108.InboundValidation` |
| 5.5 Filler Integration Setup | `IPTab50100.FillerIntegrationSetup`, `IPPag50100.FillerIntegrationSetup` |
| 5.6 Outbound Production Request | `IPCod50104.OutboundProdRequest`, `IPCod50107.PurchaseOrderEvents` |
| 5.7 Outbound BOM Transmission | `IPCod50105.OutboundBOMTransmission` (hash-based change detection, manual resend) |
| 5.8 Partial Completion | `IPCod50109.InboundPosting` (Quantity to Assemble = current inbound qty) |
| 5.9 Receipt Overage Handling | `IPCod50108.InboundValidation` (tolerance), `IPCod50114.QuantitySynchronization` (PO/AO qty update) |
| 5.10 Phantom Lot Assignment | `IPCod50112.PhantomLotMgt`, `IPTabExt50104.CompanyInformation`, `IPPagExt50103.CompanyInformation`, `IPPagExt50104.ItemCard` |
| 5.12 Pricing Validation | `IPCod50108.InboundValidation` |
| 5.13 Scrap Handling | `IPCod50113.ScrapPosting`, `IPTab50103.FillerInboundScrapLine` |
| 5.14 Outbound Trigger Points | `IPCod50103.FillerTransport` (send + manual resend), AO/PO event codeunits |
| 5.15 Inbound Payload Processing | `IPTab50102.FillerInboundEntry`, `IPPag50105.FillerCompletionAPI`, `IPPag50106.FillerScrapLineAPI`, `IPCod50110.InboundProcessing`, `IPCod50111.InboundJobQueue`, `IPPag50102/50103/50104` |
| Interface 3.1 PO/TO/ProdPO | `IPCod50115.ICROrderMessage` (builds/sends Create/Update/Delete), `IPCod50104.OutboundProdRequest` (ProdPO), `IPCod50107.PurchaseOrderEvents` (PO release/delete), `IPCod50116.TransferOrderEvents` (TO release/delete), `IPCod50103.FillerTransport` (Basic Auth), `IPTabExt50106.Location` (ICR supplier code for transfers), `IPEnum50105`, `IPEnum50106` |
| 4.x Activity Log | `IPTab50101.FillerIntegrationLog`, `IPPag50101.FillerIntegrationLog`, `IPCod50101.FillerIntegrationLogMgt` |

## Design decisions for open FDD review points

These choices fill gaps or contradictions raised in the FDD review comments. Confirm or adjust them with the business:

- **Fill Item**: an item with `Fill Item = Yes` on the Item Card. Exactly one such line per AO, with Quantity per = 1. It becomes the single PO line and is excluded from the BOM payload.
- **Create PO Link trigger**: a manual action on the Assembly Order. It creates the PO and releases it automatically. The PO release triggers the production request.
- **Re-link**: deleting the linked PO (allowed only while the AO is Open) clears the AO link, so Create PO Link can be run again.
- **AO quantity restriction**: enforced on validation of AO `Quantity`. Changing the PO Fill Item line quantity synchronizes the AO quantity, which requires the AO to be Open.
- **Re-release**: a PO re-release resends the production request only if the quantity changed. An AO re-release resends the BOM only if the BOM hash changed.
- **Overage**: 5.9 (over-receipt tolerance from the item's Over-Receipt Code) is implemented. 5.11 ("no tolerance") contradicts it and is not implemented.
- **Pricing**: exact match in the PO currency, rounded to the currency's Unit-Amount Rounding Precision.
- **Scrap**: posted as negative adjustments into the setup batch (default `ICR SCRAP`). `Auto Post Scrap` in setup switches between auto-posting and leaving lines for user review.
- **Duplicates**: rejected when an already processed entry has the same Message ID, or the same Vendor + PO + Payload Timestamp.
- **Partial failures**: posting steps are committed one at a time and flagged on the inbound entry. Retry is manual and resumes at the failed step without reposting earlier steps.
- **Phantom lot**: applies when Company Information `Phantom Lot Enabled` = Yes and the item has `Phantom Lot Covered` = Yes. `Replace Existing FG Lot` decides between replacing an unposted physical FG lot and stopping with a conflict error.

## Interface 3.1 PO/TO/ProdPO (order message to ICR)

| Document | Sent when | bsart (setup) | lifnr | matnr / menge / netpr |
|---|---|---|---|---|
| Production PO (filler PO linked to an AO) | PO release, PO delete | Prod. PO Order Type (default `ZFER`) | Buy-from Vendor No. | AO finished good / PO quantity / PO Direct Unit Cost |
| Purchase Order with item lines to the filler location | PO release, PO delete | Purch. Order Type (default `ZRFE`) | Buy-from Vendor No. | Line item / quantity / Direct Unit Cost (only lines at the filler location) |
| Transfer Order to the filler location | TO release, TO delete | Transfer Order Type (default `ZRFE`) | Transfer-from location's ICR Supplier Code (else location code) | Line item / quantity / item Unit Cost |

- **Create**: first successful message for the document. **Update**: a later release with changes; lines removed since the last message are resent with `loekz = "X"`; an unchanged document is not resent. **Delete**: user deletes a document that was sent; all lines resent with `loekz = "X"`. Not sent for fully received documents.
- `ebelp` = BC line no., `eindt` = expected receipt / receipt date as `YYYYMMDD`, `elikz = "X"` when the line is fully received. `bukrs`, `ekorg`, `ekgrp`, `werks` come from Filler Integration Setup (defaults 1000 / 1000 / 010 / 1000). `matkl`, `wepos`, `idlnf`, `banfn`, `bnfpo` are sent empty.
- Release failure: the PO / TO is reopened and the error is logged. Delete failure: the deletion is stopped with the error.
- Authentication: Filler Integration Setup → Authentication Type = Basic, API User Name, API Password (isolated storage).
- To confirm with ICR: order type per document (ZFER vs ZRFE, transfer order type), whether ProdPO lines should carry the finished good (current) or the fill item, and the price to send for transfers.

## Setup checklist

1. Assign permission set `IP FILLER INTEG`.
2. Create the filler in **Filler Integration Setup**: vendor, filler location, endpoint, authentication (Basic: user + password), ICR codes and order types, scrap template/batch.
3. Flag the filling service item as **Fill Item**, and covered finished goods as **Phantom Lot Covered**.
4. Set up the phantom lot on **Company Information**.
5. Schedule a Job Queue Entry for codeunit **50111 IP Inbound Job Queue**.
6. Point the middleware at `/api/interparfums/fillerIntegration/v1.0/companies({id})/fillerCompletions`.
