/// <summary>
/// ADO 1507 Phantom Lot assignment. When Phantom Lot is enabled on Company Information and the
/// finished good is covered, the output item tracking for the current Quantity to Assemble is
/// created or replaced with the universal phantom lot (XXXX) before standard posting
/// validation. Physical filler lots are never written to FG item tracking. Component
/// consumption tracking is unchanged.
/// </summary>
/// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment / 4.3 Quantity & Document Control Assumptions (3)
codeunit 50112 "IP Phantom Lot Mgt"
{
    var
        LogMgt: Codeunit "IP Filler Integration Log Mgt";
        DefaultPhantomLotTok: Label 'XXXX', Locked = true;
        NotLotTrackedErr: Label 'Phantom Lot configuration: finished good %1 is covered by Phantom Lot processing but has no lot-specific item tracking code.', Comment = '%1 = Item No.';
        LotConflictErr: Label 'Phantom Lot conflict: Assembly Order %1 already has unposted finished-goods lot %2 for item %3. Remove it from Item Tracking Lines or turn on Replace Existing FG Lot on Company Information.', Comment = '%1 = AO No., %2 = Lot No., %3 = Item No.';
        ReservedLotConflictErr: Label 'Phantom Lot conflict: Assembly Order %1 output is reserved with physical lot %2. The reservation must be removed before phantom lot %3 can be assigned.', Comment = '%1 = AO No., %2 = Lot No., %3 = Phantom Lot No.';
        AssignedTxt: Label 'Phantom lot %1 assigned to %2 (current output quantity) on AO %3. Filler lot %4 kept for audit only.', Comment = '%1 = Phantom lot, %2 = Quantity, %3 = AO No., %4 = Filler lot';

    /// <summary>
    /// Returns true when phantom lot processing applies: enabled on Company Information and the
    /// item is marked Phantom Lot Covered.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment (covered finished good)
    procedure IsPhantomLotApplicable(ItemNo: Code[20]): Boolean
    var
        CompanyInformation: Record "Company Information";
        Item: Record Item;
    begin
        CompanyInformation.Get();
        if not CompanyInformation."IP Phantom Lot Enabled" then
            exit(false);
        if not Item.Get(ItemNo) then
            exit(false);
        exit(Item."IP Phantom Lot Covered");
    end;

    /// <summary>
    /// Returns the universal phantom lot no. from Company Information (default XXXX).
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment
    procedure GetPhantomLotNo(): Code[50]
    var
        CompanyInformation: Record "Company Information";
    begin
        CompanyInformation.Get();
        if CompanyInformation."IP Phantom Lot No." <> '' then
            exit(CompanyInformation."IP Phantom Lot No.");
        exit(DefaultPhantomLotTok);
    end;

    /// <summary>
    /// Validation: a covered FG must be lot-tracked, otherwise the phantom lot cannot be assigned.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.15 Inbound Payload Processing (ADO 1507 Phantom Lot configuration)
    procedure CheckConfiguration(ItemNo: Code[20])
    begin
        if not IsPhantomLotApplicable(ItemNo) then
            exit;
        if not IsLotTracked(ItemNo) then
            Error(NotLotTrackedErr, ItemNo);
    end;

    /// <summary>
    /// Creates the output item tracking with the phantom lot for the current Quantity to Assemble
    /// only. Any unposted FG lot is replaced (or posting stops with a conflict message, depending
    /// on Company Information), so previously posted output is never duplicated.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment / 5.8 Partial Completion Processing
    procedure AssignPhantomLot(AssemblyHeader: Record "Assembly Header"; InboundEntry: Record "IP Filler Inbound Entry")
    var
        CompanyInformation: Record "Company Information";
        ReservationEntry: Record "Reservation Entry";
        ForReservationEntry: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        PhantomLotNo: Code[50];
    begin
        if not IsPhantomLotApplicable(AssemblyHeader."Item No.") then
            exit;
        CompanyInformation.Get();
        PhantomLotNo := GetPhantomLotNo();

        ReservationEntry.SetRange("Source Type", Database::"Assembly Header");
        ReservationEntry.SetRange("Source Subtype", AssemblyHeader."Document Type".AsInteger());
        ReservationEntry.SetRange("Source ID", AssemblyHeader."No.");
        ReservationEntry.SetRange("Source Ref. No.", 0);
        ReservationEntry.SetFilter("Lot No.", '<>%1', '');
        if ReservationEntry.FindSet(true) then
            repeat
                if ReservationEntry."Reservation Status" = ReservationEntry."Reservation Status"::Reservation then begin
                    if ReservationEntry."Lot No." <> PhantomLotNo then
                        Error(ReservedLotConflictErr, AssemblyHeader."No.", ReservationEntry."Lot No.", PhantomLotNo);
                end else begin
                    if (ReservationEntry."Lot No." <> PhantomLotNo) and (not CompanyInformation."IP Replace Existing FG Lot") then
                        Error(LotConflictErr, AssemblyHeader."No.", ReservationEntry."Lot No.", AssemblyHeader."Item No.");
                    ReservationEntry.Delete();
                end;
            until ReservationEntry.Next() = 0;

        EnsureLotNoInformation(AssemblyHeader, PhantomLotNo);

        ForReservationEntry."Lot No." := PhantomLotNo;
        CreateReservEntry.CreateReservEntryFor(
            Database::"Assembly Header", AssemblyHeader."Document Type".AsInteger(), AssemblyHeader."No.", '', 0, 0,
            AssemblyHeader."Qty. per Unit of Measure", AssemblyHeader."Quantity to Assemble", AssemblyHeader."Quantity to Assemble (Base)",
            ForReservationEntry);
        CreateReservEntry.CreateEntry(
            AssemblyHeader."Item No.", AssemblyHeader."Variant Code", AssemblyHeader."Location Code", AssemblyHeader.Description,
            AssemblyHeader."Due Date", 0D, 0, "Reservation Status"::Surplus);

        LogMgt.LogInbound(InboundEntry, "IP Integration Event Type"::"Phantom Lot Assignment", "IP Integration Status"::Success,
            StrSubstNo(AssignedTxt, PhantomLotNo, AssemblyHeader."Quantity to Assemble", AssemblyHeader."No.", InboundEntry."Physical Lot No."), '');
    end;

    /// <summary>
    /// Returns true when the item has lot-specific item tracking.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment
    local procedure IsLotTracked(ItemNo: Code[20]): Boolean
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        if not Item.Get(ItemNo) then
            exit(false);
        if Item."Item Tracking Code" = '' then
            exit(false);
        if not ItemTrackingCode.Get(Item."Item Tracking Code") then
            exit(false);
        exit(ItemTrackingCode."Lot Specific Tracking");
    end;

    /// <summary>
    /// Creates the Lot No. Information card for the phantom lot if it does not exist, so items
    /// that require lot information on inbound posting still post.
    /// </summary>
    /// Comment - Functional Design Document for ICR-MRP integration v3 - 5.10 Phantom Lot Assignment
    local procedure EnsureLotNoInformation(AssemblyHeader: Record "Assembly Header"; PhantomLotNo: Code[50])
    var
        LotNoInformation: Record "Lot No. Information";
    begin
        if LotNoInformation.Get(AssemblyHeader."Item No.", AssemblyHeader."Variant Code", PhantomLotNo) then
            exit;
        LotNoInformation.Init();
        LotNoInformation."Item No." := AssemblyHeader."Item No.";
        LotNoInformation."Variant Code" := AssemblyHeader."Variant Code";
        LotNoInformation."Lot No." := PhantomLotNo;
        LotNoInformation.Insert(true);
    end;
}
