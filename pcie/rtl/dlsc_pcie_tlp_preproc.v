
module dlsc_pcie_tlp_preproc #(
    parameter USER_WIDTH = 7
) (
    input   wire            clk,
    input   wire            rst,

    output  reg             rx_ready,
    input   wire            rx_valid,
    input   wire            rx_last,
    input   wire    [31:0]  rx_data,
    input   wire    [USER_WIDTH-1:0] rx_user,

    input   wire            pp_ready,
    output  reg             pp_valid,
    output  reg             pp_last,

    output  reg     [31:0]  pp_data,
    output  reg     [USER_WIDTH-1:0] pp_user,

    output  reg             pp_header,
    output  reg             pp_header_last,

    output  reg             pp_payload,
    output  reg             pp_payload_last,

    output  reg             pp_digest,
    output  reg             pp_digest_last,

    output  reg     [9:0]   pp_cnt,
    output  reg             pp_underflow,
    output  reg             pp_overflow
);



endmodule

