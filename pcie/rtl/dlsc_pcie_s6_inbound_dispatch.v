
module dlsc_pcie_s6_inbound_dispatch #(
    parameter TOKN      = 4
) (
    // System
    input   wire                clk,
    input   wire                rst,
    
    // TLP header input
    output  wire                tlp_h_ready,
    input   wire                tlp_h_valid,
    input   wire                tlp_h_write,

    // TLP read headers
    input   wire                rd_h_ready,
    output  wire                rd_h_valid,
    output  reg     [TOKN-1:0]  rd_h_token,

    // TLP write headers
    input   wire                wr_h_ready,
    output  wire                wr_h_valid,
    output  reg     [TOKN-1:0]  wr_h_token,

    // Token feedback
    input   wire    [TOKN-1:0]  token_oldest
);

// generate transaction ordering tokens

wire            token_full      = (wr_h_token == (token_oldest ^ {1'b1,{(TOKN-1){1'b0}}}));

always @(posedge clk) begin
    if(rst) begin
        rd_h_token      <= 0;
        wr_h_token      <= 0;
    end else begin
        if(tlp_h_ready && tlp_h_valid && tlp_h_write) begin
            rd_h_token      <= wr_h_token;
            wr_h_token      <= wr_h_token + 1;
        end
    end
end

// handshake

assign          rd_h_valid      = tlp_h_valid && !tlp_h_write;
assign          wr_h_valid      = tlp_h_valid &&  tlp_h_write && !token_full;

assign          tlp_h_ready     = tlp_h_write ? ( wr_h_ready && !token_full ) : ( rd_h_ready );

endmodule

