
module dlsc_pcie_s6_outbound_read_cpl #(
    parameter TAG       = 5,
    parameter TIMEOUT   = 625000    // 10ms at 62.5 MHz
) (
    // system
    input   wire                clk,
    input   wire                rst,

    // TLP receive input (completions only)
    output  reg                 rx_ready,
    input   wire                rx_valid,
    input   wire    [31:0]      rx_data,
    input   wire                rx_last,
    input   wire                rx_err,

    // error output
    input   wire                err_ready,
    output  reg                 err_valid,
    output  reg                 err_unexpected,
    output  reg                 err_timeout,

    // completion data to buffer
    input   wire                cpl_ready,
    output  reg                 cpl_valid,
    output  reg                 cpl_last,
    output  reg     [31:0]      cpl_data,
    output  reg     [1:0]       cpl_resp,
    output  reg     [TAG-1:0]   cpl_tag,
    
    // writes from allocator
    input   wire                alloc_init,
    input   wire                alloc_valid,
    input   wire    [TAG:0]     alloc_tag,
    input   wire    [9:0]       alloc_len,
    input   wire    [6:2]       alloc_addr,

    // feedback to allocator
    input   wire                dealloc_tag,        // from read_buffer
    output  reg                 dealloc_cplh,       // freed a header credit
    output  reg                 dealloc_cpld,       // freed a data credit

    // PCIe config
    input   wire                rcb                 // read completion boundary; 64 or 128 bytes
);

`include "dlsc_synthesis.vh"
`include "dlsc_clog2.vh"

localparam  TOB                 = `dlsc_clog2(TIMEOUT);

localparam  TAGS                = (2**TAG);

localparam  TAG_PAD             = {(8-TAG){1'b0}};
localparam  TAG_MASK            = { TAG_PAD, {(TAG){1'b1}} };

localparam  AXI_RESP_OKAY       = 2'b00,
            AXI_RESP_SLVERR     = 2'b10,
            AXI_RESP_DECERR     = 2'b11;

localparam  PCIE_FMT_3DW        = 2'b00,
            PCIE_FMT_4DW        = 2'b01,
            PCIE_FMT_3DW_DATA   = 2'b10,
            PCIE_FMT_4DW_DATA   = 2'b11;

localparam  PCIE_TYPE_CPL       = 5'b01010;

localparam  PCIE_CPL_SC         = 3'b000,
            PCIE_CPL_UR         = 3'b001,
            PCIE_CPL_CA         = 3'b100;


// ** States **

localparam  ST_H0       = 3'd0,
            ST_H1       = 3'd1,
            ST_H2       = 3'd2,
            ST_DATA     = 3'd3,
            ST_ERROR    = 3'd4,
            ST_FLUSH    = 3'd5,
            ST_TIMEOUT  = 3'd6;

reg  [2:0]      st              = ST_H0;
reg  [2:0]      next_st;

reg             set_unexpected;
reg             set_timeout;


// ** Track timeouts **

// outstanding tags

reg  [TAG-1:0]  os_cnt          = 0;    // count of outstanding tags
reg             os_cnt_zero     = 1'b1; // (from our perspective)
reg  [TAG-1:0]  os_tag_base     = 0;    // oldest allocated tag

wire            os_inc          = alloc_valid && !alloc_init;
wire            os_dec          = cpl_ready && cpl_valid && cpl_last;

always @(posedge clk) begin
    if(rst) begin
        os_cnt          <= 0;
        os_cnt_zero     <= 1'b1;
        os_tag_base     <= 0;
    end else begin
        if( os_inc && !os_dec) begin
            os_cnt          <= os_cnt + 1;
            os_cnt_zero     <= 1'b0;
        end
        if(!os_inc &&  os_dec) begin
            os_cnt          <= os_cnt - 1;
            os_cnt_zero     <= (os_cnt == 1);
        end
        if(dealloc_tag) begin
            os_tag_base     <= os_tag_base + 1;
        end
    end
end

// timeout counter

reg  [TOB-1:0]  to_cnt      = TIMEOUT;
reg             timed_out   = 1'b0;

always @(posedge clk) begin
    if(rst || os_cnt_zero || os_dec) begin
        // can't timeout if no outstanding transactions, or if
        // transactions are actually being completed
        to_cnt          <= TIMEOUT;
        timed_out       <= 1'b0;
    end else if(!timed_out) begin
        to_cnt          <= to_cnt - 1;
        timed_out       <= (to_cnt == 1);
    end
end


// ** Capture TLP header fields **

// H0
reg             h_error         = 0;
reg  [9:0]      h_len           = 0;
// H1
reg  [2:0]      h_status        = 0;
reg             h_bcm           = 0;
reg  [11:0]     h_bytes         = 0;
// H2 - raw
wire [7:0]      h2_tag          = rx_data[15:8];
wire [6:0]      h2_addr         = rx_data[6:0];
// H2 - saved
reg  [7:0]      h_tag_r         = 0;
wire [7:0]      h_tag           = (st == ST_H2) ? h2_tag : h_tag_r;

always @(posedge clk) begin
    if(st == ST_H0) begin
        // default to oldest allocated tag
        h_tag_r     <= { {(8-TAG){1'b0}}, os_tag_base };
    end
    if(st == ST_TIMEOUT && !alloc_valid && !set_timeout) begin
        // search for actual oldest outstanding tag
        h_tag_r     <= h_tag_r + 1;
    end
    if(rx_ready && rx_valid) begin
        if(st == ST_H0) begin
            h_error     <= rx_data[14] || rx_err;
            h_len       <= rx_data[9:0];
        end
        if(st == ST_H1) begin
            h_status    <= rx_data[15:13];
            h_bcm       <= rx_data[12];
            h_bytes     <= rx_data[11:0];
        end
        if(st == ST_H2) begin
            h_tag_r     <= rx_data[15:8];
        end
    end
end

// Latch rx_last
reg             rx_last_r       = 0;

always @(posedge clk) begin
    if(st == ST_H0) begin
        rx_last_r   <= 1'b0;
    end
    if(rx_ready && rx_valid && rx_last) begin
        rx_last_r   <= 1'b1;
    end
    if(set_timeout) begin
        // for a timeout, we must pretend we've received an entire TLP
        // (otherwise we'll get stuck in ST_FLUSH)
        rx_last_r   <= 1'b1;
    end
end


// ** Tag memory **

`DLSC_LUTRAM reg [16:0] mem[TAGS-1:0];

wire [TAG-1:0]  mem_addr;
wire            mem_wr_en;
wire [16:0]     mem_wr_data;
wire [16:0]     mem_rd_data     = mem[mem_addr];

always @(posedge clk) begin
    if(mem_wr_en) begin
        mem[mem_addr]   <= mem_wr_data;
    end
end


// ** Tag update **

wire            tag_valid       = mem_rd_data[16];
wire            tag_last        = mem_rd_data[15];
wire [6:2]      tag_addr        = mem_rd_data[14:10];
wire [9:0]      tag_len         = mem_rd_data[9:0];

wire            next_tag_valid  = tag_valid && !tag_last;
wire            next_tag_last   = (tag_len == 10'd2);
wire [6:2]      next_tag_addr   = tag_addr[6:2] + 5'd1;
wire [9:0]      next_tag_len    = tag_len - 10'd1;

wire            alloc_len_one   = (alloc_len == 10'd1);

assign          mem_addr        = alloc_valid ?
                                    alloc_tag[TAG-1:0] :
                                    h_tag[TAG-1:0] ;

assign          mem_wr_en       = alloc_valid ?
                                    1'b1 :
                                    (cpl_ready && cpl_valid);

assign          mem_wr_data     = alloc_valid ?
                                    { !alloc_init, alloc_len_one, alloc_addr, alloc_len } :
                                    { next_tag_valid, next_tag_last, next_tag_addr, next_tag_len };

// tag_hit is only valid in ST_H2
wire            tag_hit_tag     = tag_valid && ( (h2_tag & ~TAG_MASK) == 0 );
wire            tag_hit_addr    = (h2_addr[1:0] == 2'b00) && (h2_addr[6:2] == tag_addr[6:2]);
wire            tag_hit_bytes   = (h_bytes[1:0] == 2'b00) && (h_bcm || h_bytes[11:2] == tag_len);
wire            h2_tag_hit      = tag_hit_tag && tag_hit_addr && tag_hit_bytes;


// ** State machine **

// TODO: currently poisoned TLPs are treated as unsuccessful completions; if the
// poisoned completion wasn't the last one, then this will result in unexpected
// completions being reported when any remaining ones arrive.

always @* begin
    next_st         = st;
    rx_ready        = 1'b0;
    cpl_valid       = 1'b0;
    cpl_last        = tag_last;
    cpl_tag         = h_tag_r[TAG-1:0];
    set_unexpected  = 1'b0;
    set_timeout     = 1'b0;

    if(st == ST_DATA) begin
        cpl_data        = rx_data;
        cpl_resp        = AXI_RESP_OKAY;
    end else begin
        cpl_data        = 0;
        cpl_resp        = AXI_RESP_SLVERR;
    end

    if(st == ST_H0) begin
        rx_ready        = 1'b1;
        if(rx_valid) begin
            next_st         = ST_H1;
        end else if(timed_out) begin
            // timed out.. flush oldest tag
            next_st         = ST_TIMEOUT;
        end
    end

    if(st == ST_H1) begin
        rx_ready        = 1'b1;
        if(rx_valid) begin
            next_st         = ST_H2;
        end
    end

    if(!alloc_valid) begin
        if(st == ST_H2) begin
            rx_ready        = 1'b1;
            if(rx_valid) begin
                if(h2_tag_hit) begin
                    if(h_status == PCIE_CPL_SC && !h_error) begin
                        next_st         = ST_DATA;
                    end else begin
                        next_st         = ST_ERROR;
                    end
                end else begin
                    next_st         = ST_FLUSH;
                    set_unexpected  = 1'b1;
                end
            end
        end
        if(st == ST_DATA) begin
            rx_ready        = cpl_ready;
            cpl_valid       = rx_valid;
            if(cpl_ready && rx_valid) begin
                // word transferred
                if(rx_last) begin
                    // last word..
                    next_st         = ST_H0;
                end else if(tag_last) begin
                    // should have been last, but wasn't!
                    set_unexpected  = 1'b1;
                    next_st         = ST_FLUSH;
                end
            end
        end
        if(st == ST_ERROR) begin
            rx_ready        = !rx_last_r;
            cpl_valid       = 1'b1;
            if(cpl_ready && tag_last) begin
                // finished flushing this tag; flush remaining input (if any)
                next_st         = ST_FLUSH;
            end
        end
        if(st == ST_TIMEOUT) begin
            // searching for first (oldest) valid outstanding tag..
            if(tag_valid) begin
                set_timeout     = 1;
                next_st         = ST_ERROR;
            end
        end
    end

    if(st == ST_FLUSH) begin
        rx_ready        = !rx_last_r;
        if(rx_last_r && !err_valid) begin
            // can't leave until we've flushed all input and any errors
            // have been acknowledged
            next_st         = ST_H0;
        end
    end

end

// update state
always @(posedge clk) begin
    if(rst) begin
        st              <= ST_H0;
    end else begin
        st              <= next_st;
    end
end


// ** Drive errors **

always @(posedge clk) begin
    if(rst) begin
        err_valid       <= 1'b0;
        err_unexpected  <= 1'b0;
        err_timeout     <= 1'b0;
    end else begin
        if(err_ready) begin
            err_valid       <= 1'b0;
            err_unexpected  <= 1'b0;
            err_timeout     <= 1'b0;
        end
        if(set_unexpected) begin
            err_valid       <= 1'b1;
            err_unexpected  <= 1'b1;
        end
        if(set_timeout) begin
            err_valid       <= 1'b1;
            err_timeout     <= 1'b1;
        end
    end
end


// ** Generate dealloc signals **

always @(posedge clk) begin

    // only assert for a single cycle
    dealloc_cplh        <= 1'b0;
    dealloc_cpld        <= 1'b0;

    if(cpl_ready && cpl_valid) begin
        // deallocate header credit every 64 or 128 bytes
        if(!rcb) begin
            dealloc_cplh        <= cpl_last || (&tag_addr[5:2]);    // 64
        end else begin
            dealloc_cplh        <= cpl_last || (&tag_addr[6:2]);    // 128
        end

        // deallocate data credit every 16 bytes
        dealloc_cpld        <= cpl_last || (&tag_addr[3:2]);
    end

end

endmodule

