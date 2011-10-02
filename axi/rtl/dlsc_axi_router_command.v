
module dlsc_axi_router_command #(
    parameter ADDR              = 32,
    parameter LEN               = 4,
    parameter FAST_COMMAND      = 0,
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
    input   wire    [ INPUTS       -1:0]    cmd_full_input,
    input   wire    [ OUTPUTS      -1:0]    cmd_full_output,
    output  reg                             cmd_push,
    output  reg     [ INPUTS       -1:0]    cmd_input_onehot,
    output  reg     [ OUTPUTS      -1:0]    cmd_output_onehot,
    output  reg     [ INPUTSB      -1:0]    cmd_input,
    output  reg     [ OUTPUTSB     -1:0]    cmd_output
);

integer                 i;
genvar                  j;


// input buffering

wire    [INPUTS-1:0]    in_buf_ready;
wire    [INPUTS-1:0]    in_buf_valid;
wire    [ADDR-1:0]      in_buf_addr     [INPUTS-1:0];
wire    [LEN-1:0]       in_buf_len      [INPUTS-1:0];

generate
for(j=0;j<INPUTS;j=j+1) begin:GEN_INPUTS

    reg                 valid;
    reg     [ADDR-1:0]  addr;
    reg     [LEN -1:0]  len;

    always @(posedge clk) begin
        if(rst) begin
            valid   <= 1'b0;
        end else begin
            if(in_buf_ready[j]) begin
                valid   <= 1'b0;
            end
            if(in_ready[j] && in_valid[j]) begin
                valid   <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        if(in_ready[j] && in_valid[j]) begin
            addr    <= in_addr[(j*ADDR)+:ADDR];
            len     <= in_len [(j*LEN )+:LEN ];
        end
    end

    assign in_ready[j]      = !valid || (FAST_COMMAND && in_buf_ready[j]);

    assign in_buf_valid[j]  = valid || in_valid[j];
    assign in_buf_addr[j]   = addr;
    assign in_buf_len[j]    = len;

end
endgenerate


// arbiter

reg                     arb_out_valid;
reg     [INPUTS-1:0]    arb_out_onehot;
reg     [INPUTSB-1:0]   arb_out;

wire    [INPUTS-1:0]    arb_out_onehot_pre;

generate
if(INPUTS>1) begin:GEN_ARBITER
    dlsc_arbiter #(
        .CLIENTS    ( INPUTS )
    ) dlsc_arbiter_inst (
        .clk        ( clk ),
        .rst        ( rst ),
        .update     ( |in_buf_valid ),
        .in         ( in_buf_valid ),
        .out        ( arb_out_onehot_pre )
    );
end else begin:GEN_NO_ARBITER
    assign arb_out_onehot_pre = in_buf_valid;
end
endgenerate

always @(posedge clk) begin
    if(rst) begin
        arb_out_valid   <= 1'b0;
    end else begin
        arb_out_valid   <= |in_buf_valid;
    end
end

always @(posedge clk) begin
    arb_out_onehot  <= arb_out_onehot_pre;
    arb_out         <= {INPUTSB{1'bx}};
    for(i=0;i<INPUTS;i=i+1) begin
        if(arb_out_onehot_pre[i]) begin
/* verilator lint_off WIDTH */
            arb_out         <= i;
/* verilator lint_on WIDTH */
        end
    end
end

wire    [ADDR-1:0]      arb_addr        = in_buf_addr[arb_out];
wire    [LEN-1:0]       arb_len         = in_buf_len [arb_out];


// decoder

wire    [OUTPUTS-1:0]   dec_out_onehot;
wire    [OUTPUTSB-1:0]  dec_out;

generate
if(OUTPUTS>1) begin:GEN_DECODER
    dlsc_address_decoder #(
        .ADDR           ( ADDR ),
        .RANGES         ( OUTPUTS ),
        .RANGESB        ( OUTPUTSB ),
        .MASKS          ( MASKS ),
        .BASES          ( BASES )
    ) dlsc_address_decoder_inst (
        .addr           ( arb_addr ),
        .match_valid    (  ),
        .match_onehot   ( dec_out_onehot ),
        .match          ( dec_out )
    );
end else begin:GEN_NO_DECODER
    assign dec_out_onehot   = 1'b1;
    assign dec_out          = 1'b0;
end
endgenerate


// command

wire    [OUTPUTS-1:0]   out_buf_ready;

wire                    cmd_full        = |( cmd_full_input & arb_out_onehot ) || |( cmd_full_output & dec_out_onehot );

wire                    cmd_ready       = |( dec_out_onehot & out_buf_ready ) && !cmd_full;

wire                    cmd_push_pre    = arb_out_valid && cmd_ready;

assign                  in_buf_ready    = arb_out_onehot & {INPUTS{cmd_ready}};

always @(posedge clk) begin
    if(rst) begin
        cmd_push    <= 1'b0;
    end else begin
        cmd_push    <= cmd_push_pre;
    end
end

always @(posedge clk) begin
    cmd_input_onehot    <= arb_out_onehot;
    cmd_output_onehot   <= dec_out_onehot;
    cmd_input           <= arb_out;
    cmd_output          <= dec_out;
end


// output buffering

generate
for(j=0;j<OUTPUTS;j=j+1) begin:GEN_OUTPUT_BUFFERS

    reg             valid;
    reg [ADDR-1:0]  addr;
    reg [LEN-1:0]   len;

    assign          out_buf_ready[j]                = !valid || (FAST_COMMAND && out_ready[j]);
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
            if(cmd_push_pre && dec_out_onehot[j]) begin
                valid   <= 1'b1;
            end
        end
    end

    always @(posedge clk) begin
        // optimistically update (cut timing path through cmd_push_pre)
        if(out_buf_ready[j] && dec_out_onehot[j]) begin
            addr    <= arb_addr & MASKS[ (j*ADDR) +: ADDR ];
            len     <= arb_len;
        end
    end

end
endgenerate


endmodule

