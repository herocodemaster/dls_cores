
module dlsc_axi_router_command #(
    parameter ADDR              = 32,
    parameter LEN               = 4,
    parameter BUFFER            = 0,
    parameter INPUTS            = 1,
    parameter INPUTSB           = 1,
    parameter OUTPUTS           = 1,
    parameter OUTPUTSB          = 1,
    parameter [(OUTPUTS*ADDR)-1:0] MASKS = {(OUTPUTS*ADDR){1'b0}},
    parameter [(OUTPUTS*ADDR)-1:0] BASES = {(OUTPUTS*ADDR){1'b0}}
) (
    // System
    input   wire                            clk,
    input   wire                            rst,

    // Command input
    output  wire    [  INPUTS      -1:0]    in_ready,
    input   wire    [  INPUTS      -1:0]    in_valid,
    input   wire    [( INPUTS*ADDR)-1:0]    in_addr,
    input   wire    [( INPUTS*LEN )-1:0]    in_len,
    
    // Command output
    input   wire    [ OUTPUTS      -1:0]    out_ready,
    output  wire    [ OUTPUTS      -1:0]    out_valid,
    output  wire    [(OUTPUTS*ADDR)-1:0]    out_addr,
    output  wire    [(OUTPUTS*LEN )-1:0]    out_len,

    // Command to channels
    input   wire                            cmd_full,
    output  wire                            cmd_push,
    output  wire    [ INPUTSB      -1:0]    cmd_input,
    output  wire    [ OUTPUTSB     -1:0]    cmd_output
);

integer                 i;
genvar                  j;


// input buffering

wire    [INPUTS-1:0]    in_buf_ready;
wire    [INPUTS-1:0]    in_buf_valid;
wire    [ADDR-1:0]      in_buf_addr     [INPUTS-1:0];
wire    [LEN-1:0]       in_buf_len      [INPUTS-1:0];

generate
if(BUFFER>0) begin:GEN_BUFFER
    for(j=0;j<INPUTS;j=j+1) begin:GEN_INPUTS
        dlsc_fifo_rvh #(
            .DEPTH          ( 4 ),
            .DATA           ( ADDR+LEN ),
            .REGISTER       ( 0 )
        ) dlsc_fifo_rvh_inbuf (
            .clk            ( clk ),
            .rst            ( rst ),
            .wr_ready       ( in_ready[j] ),
            .wr_valid       ( in_valid[j] ),
            .wr_data        ( { in_addr[ (j*ADDR) +: ADDR ] , in_len[ (j*LEN) +: LEN ] } ),
            .wr_almost_full (  ),
            .rd_ready       ( in_buf_ready[j] ),
            .rd_valid       ( in_buf_valid[j] ),
            .rd_data        ( { in_buf_addr[j], in_buf_len[j] } ),
            .rd_almost_empty(  )
        );
    end
end else begin:GEN_NO_BUFFER
    for(j=0;j<INPUTS;j=j+1) begin:GEN_INPUTS
        assign in_ready[j]      = in_buf_ready[j];
        assign in_buf_valid[j]  = in_valid[j];
        assign in_buf_addr[j]   = in_addr[(j*ADDR)+:ADDR];
        assign in_buf_len[j]    = in_len [(j*LEN )+:LEN ];
    end
end
endgenerate


// arbiter

wire    [INPUTS-1:0]    arb_out_onehot;

dlsc_arbiter #(
    .CLIENTS    ( INPUTS )
) dlsc_arbiter_inst (
    .clk        ( clk ),
    .rst        ( rst ),
    .update     ( |in_buf_valid ),
    .in         ( in_buf_valid ),
    .out        ( arb_out_onehot )
);

reg     [INPUTSB-1:0]   arb_out;

always @* begin
    arb_out = {INPUTSB{1'bx}};
    for(i=0;i<INPUTS;i=i+1) begin
        if(arb_out_onehot[i]) begin
/* verilator lint_off WIDTH */
            arb_out = i;
/* verilator lint_on WIDTH */
        end
    end
end

wire    [ADDR-1:0]      arb_addr        = in_buf_addr[arb_out];
wire    [LEN-1:0]       arb_len         = in_buf_len [arb_out];


// decoder

wire    [OUTPUTS-1:0]   dec_out_onehot;

dlsc_address_decoder #(
    .ADDR       ( ADDR ),
    .RANGES     ( OUTPUTS ),
    .MASKS      ( MASKS ),
    .BASES      ( BASES )
) dlsc_address_decoder_inst (
    .addr       ( arb_addr ),
    .match      ( dec_out_onehot )
);

reg     [OUTPUTSB-1:0]  dec_out;

always @* begin
    dec_out = {OUTPUTSB{1'bx}};
    for(i=0;i<OUTPUTS;i=i+1) begin
        if(dec_out_onehot[i]) begin
/* verilator lint_off WIDTH */
            dec_out = i;
/* verilator lint_on WIDTH */
        end
    end
end


// output buffering

wire    [OUTPUTS-1:0]   out_buf_ready;

generate
for(j=0;j<OUTPUTS;j=j+1) begin:GEN_OUTPUT_BUFFERS

    wire            out_buf_valid                   = cmd_push && dec_out_onehot[j];

    reg             valid;
    reg [ADDR-1:0]  addr;
    reg [LEN-1:0]   len;

    assign          out_buf_ready[j]                = !valid || out_ready[j];
    assign          out_valid[j]                    = valid;
    assign          out_addr[ (j*ADDR) +: ADDR ]    = addr;
    assign          out_len [ (j*LEN ) +: LEN  ]    = len;

    always @(posedge clk) begin
        if(rst) begin
            valid   <= 1'b0;
        end else begin
            if(out_ready[j]) begin
                valid   <= 1'b0;
            end
            if(out_buf_valid) begin
                valid   <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if(out_buf_valid) begin
            addr    <= arb_addr & MASKS[ (j*ADDR) +: ADDR ];
            len     <= arb_len;
        end
    end

end
endgenerate


// command

wire                    cmd_ready       = |( dec_out_onehot & out_buf_ready ) && !cmd_full;

assign                  cmd_push        = |in_buf_valid && cmd_ready;
assign                  cmd_input       = arb_out;
assign                  cmd_output      = dec_out;

assign                  in_buf_ready    = arb_out_onehot & {INPUTS{cmd_ready}};


endmodule

