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

---

# ICR Inventory Orchestration (FDD v1.2)

Implements the **Functional Design Document for ICR - Inventory Orchestration** in the same extension (ID range 50403–50449), reusing Filler Integration Setup, the ICR order message, the transport and the Filler Integration Activity Log.
Comments use `/// Comment - Functional Design Document for ICR - Inventory Orchestration - <FDD section>`.

## Flow

**Raw material distribution**
1. PO release → validate vendor, filler setup and PO lines → send PO payload (ZRFE) → log. Validation failure: no payload, PO reopened for correction, logged.
2. TO shipment posted to a filler location → validate → send TO payload → log. Inventory is in transit. A failure never undoes the shipment; it is logged and can be resent.
3. ICR posts a **030 Goods Receipt** movement → BC finds the PO or inbound TO from `PO_NUMBER` → validates lines (`PO_ITEM`), items, UoM and quantities → posts the PO receipt (receive only) or the TO receipt → log.

**Finished goods distribution**
1. ICR posts a **311 Transfer to 3PL** movement.
2. BC looks for an open TO from the filler location with the same items and quantities. If none, it creates one (filler location → 3PL location from setup).
3. BC assigns lot `XXXX` to covered finished goods (Phantom Lot enabled, item Phantom Lot Covered) after checking stock under `XXXX`. The physical lot from the payload is kept for audit only.
4. BC posts the Transfer Shipment. The existing Difarco integration receives it (unchanged).
5. Every step is in the Activity Log.

## Object map

| FDD section | Objects |
|---|---|
| 6.1 Purchase Order Release | `IPCod50415.OutboundOrchValidation`, hook in `IPCod50107.PurchaseOrderEvents` |
| 6.2 Transfer Order Shipment to Integrated Filler | `IPCod50416.TransferOrchEvents`, `IPEnum50410.TOOutboundTrigger`, setup field *TO Outbound Trigger*, hook in `IPCod50116.TransferOrderEvents` |
| 6.3 Outbound Integration Trigger Points | `IPCod50415`, `IPCod50416`, existing `IPCod50115.ICROrderMessage` (payload, duplicate prevention) |
| 6.4 Inbound Raw Material Receipt Processing | `IPTab50405.ICRInboundEntryHeader`, `IPTab50406.ICRInboundEntryLines`, `IPPag50410.ICRInboundEntryAPI`, `IPPag50411.ICRInboundEntryLineAPI`, `IPCod50417.ICRMovementProcessing`, `IPCod50418.ICRMovementPosting`, `IPCod50419.ICRMovementValidation`, `IPCod50420.RawMaterialReceipt`, `IPCod50424.ICRMovementJobQueue`, `IPEnum50408.ICRMovementType`, `IPEnum50409.MovementSourceDocType` |
| 6.5 Finished Goods Shipment Processing | `IPCod50421.FGShipmentProcessing`, `IPCod50422.TransferPhantomLotMgt`, `IPTabExt50405–50408` (Transfer Header/Line, Transfer Shipment Header/Line), `IPPagExt50403.TransferOrder`, `IPPagExt50404.PostedTransferShipment`, setup fields *FG 3PL Location Code*, *FG In-Transit Code* |
| Positive & negative adjustments (100 / 101) | `IPCod50425.ICRAdjustmentPosting`, `IPCod50419.ICRMovementValidation` (setup + LGORT checks), setup fields *Adj. Jnl. Template Name*, *Adj. Jnl. Batch Name*, *Auto Post Adjustments* |
| 3.5 Operational Visibility | `IPCod50423.ICRMovementLogMgt`, `IPPag50412.ICRInboundEntries`, `IPPag50413.ICRInboundEntry`, `IPPag50414.ICRInboundEntrySubform`, Activity Log field *ICR Inbound Entry No.* |

## Design decisions to confirm

- **One inbound table for both FDDs**: `IP ICR Inbound Entry Header` / `IP ICR Inbound Entry Lines` receive every ICR movement (030, 087, 100, 101, 122, 311). On insert, a 030 / 087 for a production PO gets its *Assembly Order No.*. Inventory Orchestration processes 030 without Assembly Order, 311, 100 and 101; everything else is left for the ICR-MRP inbound process.

- **One app**: added to the existing extension so PO/TO payloads are not sent twice and the Activity Log stays in one place.
- **TO trigger**: setup *TO Outbound Trigger* = Shipment (default, per this FDD) or Release (earlier ICR-MRP behavior).
- **030 routing**: `PO_NUMBER` is looked up as a Purchase Order first, then a Transfer Order. Production POs linked to an AO are rejected here (they go through the ICR-MRP filler completion API).
- **TO matching (311)**: same transfer-from location, same set of items, and the same open (unshipped) quantity per item in base UoM. Direct transfers are skipped.
- **Filler for 311**: movement *Vendor No.*, else line `LIFNR`, else the only enabled filler.
- **Duplicates**: same Message ID, or same `MVT_TYPE` + `PO_NUMBER` + `HDTEXT`, already processed.
- **No double posting**: the movement is set to Processed in the same transaction as the BC posting.
- **Physical lot**: optional line field `physicalLotNo`. Used for lot-tracked raw materials; ignored (audit only) for phantom-lot finished goods. A payload lot of `XXXX` while Phantom Lot is off is an error.
- **Adjustments (100 / 101)**: one Item Journal line per `posd` line (Positive / Negative Adjmt.) in the adjustment batch from setup, location = `LGORT`, no reason code. Lot-tracked items always get the phantom lot (XXXX); other items no lot. Positive adjustments use `NETPR / PEINH` as unit cost; negative adjustments take the cost of the inventory removed.
- **Out of scope here**: movements 087 and 122 are stored and rejected as not in scope. Warehouse receive/ship documents and bins are not handled.

## Setup checklist (Inventory Orchestration)

1. Filler Integration Setup: *TO Outbound Trigger*, *FG 3PL Location Code*, *FG In-Transit Code* (or a transfer route), *Adj. Jnl. Template Name*, *Adj. Jnl. Batch Name*, *Auto Post Adjustments*.
2. Schedule a Job Queue Entry for codeunit **50424 IP ICR Movement Job Queue**.
3. Point the middleware at `/api/interparfums/fillerIntegration/v1.0/companies({id})/icrInboundEntries` (deep insert with `posd`).
