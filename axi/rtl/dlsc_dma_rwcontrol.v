
module dlsc_dma_rwcontrol #(
    parameter DATA      = 32,
    parameter ADDR      = 32,
    parameter LEN       = 4,
    parameter LSB       = 2,    // >= 2
    parameter BUFA      = 9,    // size of buffer is 2**BUFA words
    parameter MOT       = 16,
    parameter TRIG      = 8     // 1-16
) (
    // System
    input   wire                    clk,
    input   wire                    rst,

    // Control/status
    input   wire                    halt,
    output  reg     [1:0]           error,
    output  wire                    busy,
    output  reg                     cmd_done,

    // Triggering
    input   wire    [TRIG-1:0]      trig_in,
    output  reg     [TRIG-1:0]      trig_ack,
    output  reg     [TRIG-1:0]      trig_out,
    
    // Command input
    output  wire                    cmd_almost_empty,
    input   wire                    cmd_push,
    input   wire    [31:0]          cmd_data,

    // Length checking
    output  wire                    cs_pop,
    output  wire    [LEN:0]         cs_len,
    input   wire                    cs_okay,

    // AXI command
    input   wire                    axi_c_ready,
    output  reg                     axi_c_valid,
    output  reg     [ADDR-1:0]      axi_c_addr,
    output  reg     [LEN-1:0]       axi_c_len,

    // AXI response
    output  wire                    axi_r_ready,
    input   wire                    axi_r_valid,
    input   wire                    axi_r_last,
    input   wire    [1:0]           axi_r_resp
);


// Command buffer

wire            fc_empty;
wire            fc_pop;
wire [31:0]     fc_data;

dlsc_fifo #(
    .DATA           ( 32 ),
    .DEPTH          ( 32 ),
    .ALMOST_EMPTY   ( 16 )
) dlsc_fifo_cmd (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( cmd_push ),
    .wr_data        ( cmd_data ),
    .wr_full        (  ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( fc_pop ),
    .rd_data        ( fc_data ),
    .rd_empty       ( fc_empty ),
    .rd_almost_empty( cmd_almost_empty ),
    .rd_count       (  )
);


// Command parsing

localparam  ST_LEN      = 0,
            ST_ADDR32   = 1,
            ST_ADDR64   = 2,
            ST_TRIG     = 3;

reg  [1:0]      st;

wire            cp_ready;
reg             cp_valid;
reg  [31:LSB]   cp_len;
reg  [63:LSB]   cp_addr;

reg             cp_addr64;
reg             cp_trig;

reg  [TRIG-1:0] cp_trig_in;
reg  [TRIG-1:0] cp_trig_out;

assign          fc_pop          = !fc_empty && (st != ST_LEN || !cp_valid || cp_ready);

always @(posedge clk) begin
    if(rst) begin
        st          <= ST_LEN;
        cp_valid    <= 1'b0;
    end else begin
        if(cp_ready) begin
            cp_valid    <= 1'b0;
        end
        if(fc_pop) begin
            if(st == ST_LEN) begin
                st          <= ST_ADDR32;
            end
            if(st == ST_ADDR32) begin
                if(cp_addr64) begin
                    st          <= ST_ADDR64;
                end else begin
                    if(cp_trig) begin
                        st          <= ST_TRIG;
                    end else begin
                        st          <= ST_LEN;
                        cp_valid    <= 1'b1;
                    end
                end
            end
            if(st == ST_ADDR64) begin
                if(cp_trig) begin
                    st          <= ST_TRIG;
                end else begin
                    st          <= ST_LEN;
                    cp_valid    <= 1'b1;
                end
            end
            if(st == ST_TRIG) begin
                st          <= ST_LEN;
                cp_valid    <= 1'b1;
            end
        end
    end
end

always @(posedge clk) begin
    if(fc_pop) begin
        if(st == ST_LEN) begin
            cp_addr64       <= fc_data[0];
            cp_trig         <= fc_data[1];
            cp_len          <= fc_data[31:LSB];
            cp_trig_in      <= 0;
            cp_trig_out     <= 0;
        end
        if(st == ST_ADDR32) begin
            cp_addr         <= { 32'd0, fc_data[31:LSB] };
        end
        if(st == ST_ADDR64) begin
            cp_addr         <= { fc_data, cp_addr[31:LSB] };
        end
        if(st == ST_TRIG) begin
            cp_trig_in      <= fc_data[  0 +: TRIG ];
            cp_trig_out     <= fc_data[ 16 +: TRIG ];
        end
    end
end


// AXI command generation

wire                cs_valid;
wire                cs_ready;
wire [ADDR-1:LSB]   cs_addr;
wire                cs_last;

dlsc_dma_cmdsplit #(
    .ADDR           ( ADDR - LSB ),
    .ILEN           ( 32 - LSB ),
    .OLEN           ( LEN )
) dlsc_dma_cmdsplit_inst (
    .clk            ( clk ),
    .rst            ( rst ),
    .in_ready       ( cp_ready ),
    .in_valid       ( cp_valid ),
    .in_addr        ( cp_addr[ADDR-1:LSB] ),
    .in_len         ( cp_len ),
    .out_ready      ( cs_ready ),
    .out_valid      ( cs_valid ),
    .out_addr       ( cs_addr ),
    .out_len        ( cs_len ),
    .out_last       ( cs_last )
);


// Triggering

reg                 cs_triggered;
reg  [TRIG-1:0]     cs_trig_in;
reg  [TRIG-1:0]     cs_trig_out;

always @(posedge clk) begin
    if(cp_ready && cp_valid) begin
        cs_triggered    <= !cp_trig;
        cs_trig_in      <= cp_trig_in;
        cs_trig_out     <= cp_trig_out;
    end
    trig_ack        <= 0;
    if(cs_valid && !cs_triggered) begin
        // wait for all triggers
        if( (cs_trig_in & trig_in) == cs_trig_in ) begin
            // acknowledge triggers
            trig_ack        <= cs_trig_in;
            cs_triggered    <= 1'b1;
        end
    end
end


// Track command boundaries

wire                l_empty;
assign              busy        = !l_empty;
wire                l_full;
wire                l_push      = cs_ready && cs_valid;
wire                l_pop       = axi_r_ready && axi_r_valid && axi_r_last;
wire                l_last;

dlsc_fifo #(
    .DATA           ( 1 ),
    .DEPTH          ( MOT ),
    .FAST_FLAGS     ( 1 )
) dlsc_fifo_l (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( l_push ),
    .wr_data        ( cs_last ),
    .wr_full        ( l_full ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( l_pop ),
    .rd_data        ( l_last ),
    .rd_empty       ( l_empty ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);


// Completion triggers

wire                t_push      = l_push && cs_last;
wire                t_pop       = l_pop && l_last;
wire [TRIG-1:0]     t_trig_out;

dlsc_fifo #(
    .DATA           ( TRIG ),
    .DEPTH          ( MOT ),
    .FAST_FLAGS     ( 1 )
) dlsc_fifo_t (
    .clk            ( clk ),
    .rst            ( rst ),
    .wr_push        ( t_push ),
    .wr_data        ( cs_trig_out ),
    .wr_full        (  ),
    .wr_almost_full (  ),
    .wr_free        (  ),
    .rd_pop         ( t_pop ),
    .rd_data        ( t_trig_out ),
    .rd_empty       (  ),
    .rd_almost_empty(  ),
    .rd_count       (  )
);

always @(posedge clk) begin
    trig_out    <= 0;
    if(t_pop) begin
        trig_out    <= t_trig_out;
    end
end


// Handshake

assign              cs_ready    = (!axi_c_valid || axi_c_ready) && !l_full && !halt && (error == 2'b00) && cs_triggered && cs_okay;
assign              cs_pop      = (cs_ready && cs_valid);


// Issue command

always @(posedge clk) begin
    if(rst) begin
        axi_c_valid     <= 1'b0;
    end else begin
        if(axi_c_ready) begin
            axi_c_valid     <= 1'b0;
        end
        if(cs_ready && cs_valid) begin
            axi_c_valid     <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(cs_ready && cs_valid) begin
        axi_c_addr      <= { cs_addr, {LSB{1'b0}} };
        axi_c_len       <= cs_len[LEN-1:0] - 1;
    end
end


// Collect response

always @(posedge clk) begin
    if(rst) begin
        error       <= 2'b00;
    end else if(axi_r_ready && axi_r_valid && (axi_r_resp != 2'b00)) begin
        error       <= axi_r_resp;
    end
end

assign          axi_r_ready     = !l_empty;

always @(posedge clk) begin
    if(rst) begin
        cmd_done    <= 1'b0;
    end else begin
        cmd_done    <= (axi_r_ready && axi_r_valid && axi_r_last && l_last);
    end
end


endmodule

