module dlsc_cpu1_icache #(
    parameter ADDR      = 30,       // width of address bus
    parameter DATA      = 32,       // width of data bus
    parameter LINE      = 4,        // cache line size is 2**LINE
    parameter SIZE      = 9,        // way size is 2**WAY_SIZE
    parameter WAYS      = 2,        // number of ways (1 or 2)
    parameter USE_WRAP  = 1,        // use AXI WRAP bursts (otherwise INCR)
    parameter PREFETCH  = 1         // enable prefetcher
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // program counter input
    input   wire    [ADDR-1:0]      in_pc,

    // instruction data output
    output  wire                    out_miss,
    output  wire    [DATA-1:0]      out_data,

    // prefetch hint
    // (e.g. from decoded branch instruction)
    // (temporarily overrides internal prefetcher)
    input   wire                    prefetch_valid,
    input   wire    [ADDR-1:0]      prefetch_addr,

    // error status output
    input   wire                    err_ack,        // clear error
    output  reg                     err_flag,       // asserted when an error occurs
    output  reg     [1:0]           err_resp,       // error response captured on AXI bus
    output  reg     [ADDR-1:0]      err_addr,       // address of error
    output  reg                     err_prefetch,   // error was caused by a prefetch

    // AXI halt control
    // (if just resetting CPU, and not entire bus fabric, must
    // halt to ensure AXI port is inactive prior to reset)
    input   wire                    halt_req,
    output  reg                     halt_ack,

    // AXI read command
    input   wire                    axi_ar_ready,
    output  reg                     axi_ar_valid,
    output  reg     [ADDR-1:0]      axi_ar_addr,
    output  wire    [LINE-1:0]      axi_ar_len,
    output  wire    [1:0]           axi_ar_burst,
    output  reg                     axi_ar_prefetch, // indicates command is for a prefetch

    // AXI read data
    output  reg                     axi_r_ready,
    input   wire                    axi_r_valid,
    input   wire                    axi_r_last,
    input   wire    [DATA-1:0]      axi_r_data,
    input   wire    [1:0]           axi_r_resp
);

assign axi_ar_len   = {LINE{1'b1}};             // burst length of a whole cache line
assign axi_ar_burst = USE_WRAP ? 2'b10 : 2'b01; // WRAP or INCR

// states for write controller
localparam  ST_INIT     = 0,
            ST_IDLE     = 1,
            ST_PRE      = 2,
            ST_DATA     = 3,
            ST_DONE     = 4,
            ST_ERROR    = 5;

reg  [2:0]      st          = ST_INIT;

reg             rst_trig    = 1'b1; // internal reset trigger (used to recover from bus errors)

wire            rd_miss;            // instruction read missed
wire            pf_miss;            // prefetch read missed
wire [WAYS-1:0] rd_waylru;          // least-recently-used way for instruction read
wire [WAYS-1:0] pf_waylru;          // least-recently-used way for prefetch read
reg  [WAYS-1:0] wr_waylru   = 1;    // way to fetch into
reg  [ADDR-1:0] wr_addr     = 0;    // address to fetch into
reg             wr_pf       = 1'b0; // fetch is a prefetch
reg             wr_pend     = 1'b0; // flag indicating to the write controller that it must prepare to act on an issued AXI command

reg  [WAYS-1:0] axi_waylru  = 1;    // saved wr/pf_waylru for issued command
reg             axi_pf      = 1'b0; // (potentially) issue a prefetch address
reg             pf_ack      = 1'b1; // AXI read command was issued for prefetch address

reg             rst_done    = 1'b0; // reset is done once reset is removed and cache has initialized itself
assign          out_miss    = rd_miss || !rst_done; // must miss when reset is in progress

wire            wr_init     = (st == ST_INIT);
wire            wr_en       = (st == ST_DATA && axi_r_valid && axi_r_resp == 0 );
wire            wr_en_tag   = (st == ST_PRE || wr_en);
wire            wr_last     = axi_r_ready && axi_r_valid && axi_r_last;

// save PC for next cycle (so we know what PC triggered a rd_miss)
reg  [ADDR-1:0] c1_pc       = 0;
always @(posedge clk) begin
    c1_pc       <= in_pc;
end

reg  [ADDR-1:LINE] c0_pf_addr = 0;  // address used for prefetch reads
reg  [ADDR-1:LINE] c1_pf_addr = 0;  // saved address (so we know what pf_addr triggered a pf_miss)

generate if(PREFETCH>0) begin:GEN_PF_ADDR

    reg [ADDR-1:LINE] pf_latch          = 0;
    reg               pf_latch_valid    = 1'b0;
    reg               c1_pf_latch_valid = 1'b0;

    always @(posedge clk) begin
        // prefetch from 1 LINE beyond PC
        c0_pf_addr          <= pf_latch_valid ? pf_latch : (c1_pc[ADDR-1:LINE] + 1);
        c1_pf_addr          <= c0_pf_addr;
        c1_pf_latch_valid   <= pf_latch_valid;

        if( c1_pf_latch_valid && (!pf_miss||pf_ack) ) begin
            // checked prefetch hint and didn't miss, or fetch was issued for hint
            // ..no need to track hint any further
            pf_latch_valid      <= 1'b0;
            c1_pf_latch_valid   <= 1'b0;
        end

        if(prefetch_valid) begin
            // latch external prefetch hint
            // (we will hold onto the hint until it actually hits in the cache)
            pf_latch            <= prefetch_addr[ADDR-1:LINE];
            pf_latch_valid      <= 1'b1;
        end
    end

end endgenerate

wire rst_int = rst || rst_trig;     // can be reset externally, or via internal trigger

always @(posedge clk) begin
    if(rst_int) begin

        rst_trig        <= 1'b0;

        st              <= ST_INIT;
        rst_done        <= 1'b0;

        wr_waylru       <= 1;
        wr_addr         <= 0;
        wr_pf           <= 1'b0;
        wr_pend         <= 1'b0;

        halt_ack        <= 1'b0;

        axi_waylru      <= 1;
        axi_pf          <= 1'b0;
        pf_ack          <= 1'b1;

        axi_ar_valid    <= 1'b0;
        axi_ar_addr     <= 0;
        axi_ar_prefetch <= 1'b0;
        axi_r_ready     <= 1'b0;

    end else begin

        rst_done        <= 1'b1;    // reset complete (unless held by ST_INIT below)

        pf_ack          <= 1'b0;


        // ** AXI command **

        // if there's no pending transaction, we can update the command
        if(!wr_pend && !axi_ar_valid) begin

            // update address
            // (doesn't depend on _miss signals, so-as to avoid a potentially long timing path)
            if(PREFETCH==0 || !axi_pf) begin
                // mask lower bits if not wrapping
                axi_ar_addr     <= USE_WRAP ? c1_pc : { c1_pc[ADDR-1:LINE], {LINE{1'b0}} };
                axi_ar_prefetch <= 1'b0;
                axi_waylru      <= rd_waylru;                       // least-recently-used way will be destination
            end else begin
                // set prefetch address
                axi_ar_addr     <= { c1_pf_addr, {LINE{1'b0}} };    // prefetch is always aligned
                axi_ar_prefetch <= 1'b1;
                axi_waylru      <= pf_waylru;                       // least-recently-used way will be destination
            end

            // can issue another transaction
            if(!halt_req && !halt_ack && rst_done) begin
                axi_pf          <= 1'b0;
                if(PREFETCH==0 || !axi_pf) begin
                    if(rd_miss && (c1_pc[ADDR-1:LINE] != wr_addr[ADDR-1:LINE] || st == ST_IDLE)) begin
                        // address will have been setup above; launch command
                        axi_ar_valid    <= 1'b1;
                    end else if(PREFETCH>0 && (pf_miss||prefetch_valid)) begin
                        // need an extra cycle to setup prefetch address
                        axi_pf          <= 1'b1;
                    end
                end else if(pf_miss && (c1_pf_addr[ADDR-1:LINE] != wr_addr[ADDR-1:LINE] || st == ST_IDLE)) begin
                    // prefetch address will have been setup above; launch command
                    axi_ar_valid    <= 1'b1;
                    pf_ack          <= 1'b1;
                end
            end

        end

        // command accepted; send to write controller
        if(axi_ar_valid && axi_ar_ready) begin
            axi_ar_valid    <= 1'b0;
            wr_pend         <= 1'b1;
        end


        // ** AXI data **

        if(st == ST_INIT) begin
            // allow halting during init (guaranteed to have no AXI activity)
            halt_ack        <= halt_req;
            rst_done        <= 1'b0;
            // invalidate cache
            // go through all tags
            wr_addr[SIZE-1:LINE] <= wr_addr[SIZE-1:LINE] + 1;
            // go through all lines
            wr_addr[LINE-1:0] <= wr_addr[LINE-1:0] + 1;
            if(wr_addr[SIZE-1:0] == {SIZE{1'b1}}) begin
                // done once we've gone through all tags and lines
                st              <= ST_DONE;
            end                
        end

        if(st == ST_IDLE) begin
            // can only halt when idle
            halt_ack        <= halt_req && !axi_ar_valid && !wr_pend;

            if(wr_pend) begin
                wr_pend         <= 1'b0;
                wr_addr         <= axi_ar_addr;
                wr_pf           <= axi_ar_prefetch;
                wr_waylru       <= axi_waylru;
                st              <= ST_PRE;
            end
        end

        if(st == ST_PRE) begin
            // tag cleared; prepare for data
            axi_r_ready     <= 1'b1;
            st              <= ST_DATA;
        end

        if(st == ST_DATA && axi_r_valid) begin
            // increment address
            // (small incrementer, since access is aligned)
            wr_addr[LINE-1:0] <= wr_addr[LINE-1:0] + 1;

            if(axi_r_last) begin
                // go through a dummy 'done' state to allow rd_miss to resolve
                axi_r_ready     <= 1'b0;
                st              <= ST_DONE;
            end
        end

        if(st == ST_DONE) begin
            // dummy state to allow writes to become valid in memories
            st              <= ST_IDLE;
        end

        if(st == ST_ERROR || (axi_r_ready && axi_r_valid && axi_r_resp != 0)) begin
            // error!
            // invalidate cache
            rst_done        <= 1'b0;
            axi_r_ready     <= 1'b1;
            st              <= ST_ERROR;

            // absorb remaining read data
            if(axi_r_valid && axi_r_last) begin
                if(wr_pend) begin
                    // need to absorb a second transaction
                    wr_pend         <= 1'b0;
                end else if(!axi_ar_valid) begin
                    // idle now; trigger internal reset to invalidate/re-initialize cache
                    axi_r_ready     <= 1'b0;
                    rst_trig        <= 1'b1;
                end
            end
        end

    end
end

// error flag control
// (only reset externally, since we want error flag to persist until it can be read!)
always @(posedge clk) begin
    if(rst) begin
        err_flag        <= 1'b0;
        err_resp        <= 0;
        err_addr        <= 0;
        err_prefetch    <= 1'b0;
    end else begin
        if(err_ack) begin
            // clear error flag once acknowledged
            err_flag        <= 1'b0;
        end
        if(axi_r_ready && axi_r_valid && axi_r_resp != 0 && (!err_flag || err_ack)) begin
            // save first error
            err_flag        <= 1'b1;
            err_resp        <= axi_r_resp;
            err_addr        <= wr_addr;
            err_prefetch    <= wr_pf;
        end
    end
end


// the cache
dlsc_cpu1_icache_ways #(
    .ADDR       ( ADDR ),
    .DATA       ( DATA ),
    .LINE       ( LINE ),
    .SIZE       ( SIZE ),
    .WAYS       ( WAYS ),
    .PREFETCH   ( PREFETCH )
) dlsc_cpu1_icache_ways_inst (
    .clk        ( clk ),
    .rd_addr    ( in_pc ),
    .rd_data    ( out_data ),
    .rd_miss    ( rd_miss ),
    .rd_waylru  ( rd_waylru ),
    .pf_addr    ( {c0_pf_addr,{LINE{1'b0}}} ),
    .pf_miss    ( pf_miss ),
    .pf_waylru  ( pf_waylru ),
    .wr_init    ( wr_init ),
    .wr_addr    ( wr_addr ),
    .wr_way     ( wr_waylru ),
    .wr_en      ( wr_en ),
    .wr_data    ( axi_r_data ),
    .wr_en_tag  ( wr_en_tag ),
    .wr_last    ( wr_last )
);


`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

integer pend_cnt = 0;
integer beat_cnt = 0;

always @(posedge clk) begin

    if(axi_ar_ready && axi_ar_valid) begin
        pend_cnt = pend_cnt + 1;
    end
    if(axi_r_ready && axi_r_valid && axi_r_last) begin
        pend_cnt = pend_cnt - 1;
    end

    if( !rst_int && (st == ST_DATA || st == ST_ERROR) != axi_r_ready ) begin
        `dlsc_error("axi_r_ready must always/only be asserted in ST_DATA or ST_ERROR states");
    end

    if(axi_ar_valid || axi_r_ready || wr_pend || pend_cnt > 0) begin
        // not idle; make sure we're not in a state where idle is required
        if(rst_int) begin
            pend_cnt    = 0;
            `dlsc_warn("reset asserted with pending AXI transactions");
        end
        if(halt_ack) begin
            `dlsc_error("must be idle when halted");
        end
        if(st == ST_INIT) begin
            `dlsc_error("must be idle in ST_INIT");
        end
    end

    if(err_flag && !err_ack && axi_r_ready && axi_r_valid && axi_r_resp != 0) begin
        `dlsc_warn("err_flag not acknowledged when another error occurred");
    end
    if(!err_flag && err_ack) begin
        `dlsc_warn("err_ack asserted when err_flag deasserted");
    end

    if(PREFETCH==0 && prefetch_valid) begin
        `dlsc_warn("prefetch_valid asserted when PREFETCH is disabled");
    end

    if(rst_int) begin
        beat_cnt    = 0;
    end else if(axi_r_ready && axi_r_valid) begin
        if(axi_r_last != (beat_cnt == (2**LINE)-1)) begin
            `dlsc_error("axi_r_last must assert every 2**LINE (%0d) beats",(2**LINE));
        end
        beat_cnt    = (beat_cnt + 1) % 16;
    end

end

`include "dlsc_sim_bot.vh"
`endif

endmodule

