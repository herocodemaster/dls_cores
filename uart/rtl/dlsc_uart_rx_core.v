
module dlsc_uart_rx_core #(
    parameter START         = 1,
    parameter STOP          = 1,
    parameter DATA          = 8,
    parameter PARITY        = 0,    // 0 = NONE, 1 = ODD, 2 = EVEN
    parameter OVERSAMPLE    = 16
) (
    // system
    input   wire                clk,
    input   wire                clk_en,         // should enable at BAUD*OVERSAMPLE
    input   wire                rst,

    // uart pins
    input   wire                rx,
    input   wire                rx_mask,        // disable reception when asserted

    // received data
    output  reg                 valid,          // qualifier; asserts for just 1 cycle
    output  reg     [DATA-1:0]  data,           // received data
    output  reg                 frame_error,    // start/stop bits incorrect
    output  reg                 parity_error    // parity check failed
);

`include "dlsc_clog2.vh"

localparam PARITY_BITS  = (PARITY>0)?1:0;
localparam BITS         = (START+STOP+DATA+PARITY_BITS);


// ** input filter

wire rxf;

dlsc_glitchfilter #(
    .DEPTH      ( OVERSAMPLE/4 ),
    .RESET      ( 1'b1 )
) dlsc_glitchfilter_inst_rx (
    .clk        ( clk ),
    .clk_en     ( clk_en ),
    .rst        ( rst ),
    .in         ( rx || rx_mask ),
    .out        ( rxf )
);

reg rxf_prev = 1'b1;

always @(posedge clk) begin
    if(rst) begin
        rxf_prev    <= 1'b1;
    end else if(clk_en) begin
        rxf_prev    <= rxf;
    end
end


// ** control

reg                 sample_en   = 1'b0;
reg                 sr_last     = 1'b0;

// detect start
reg                 started     = 1'b0;
wire                start       = (!started && rxf_prev && !rxf);

always @(posedge clk) begin
    if(rst || sr_last) begin
        started     <= 1'b0;
    end else if(start) begin
        started     <= 1'b1;
    end
end

// sample data
reg  [BITS-1:0]     sr;

always @(posedge clk) begin
    if(!started) begin
        { sr, sr_last }     <= {1'b1,{BITS{1'b0}}};
    end else if(sample_en) begin
        { sr, sr_last }     <= { rxf, sr };
    end
end

// drive output once everything is shifted in
wire [START-1:0]    start_bits  = sr[  0                       +: START ];
wire [DATA -1:0]    data_bits   = sr[  START                   +: DATA ];
wire                parity_bit  = sr[ (START+DATA)             +: 1 ];
wire [STOP -1:0]    stop_bits   = sr[ (START+DATA+PARITY_BITS) +: STOP ];

wire                parity      = ^data_bits ^ ((PARITY == 1) ? 1'b1 : 1'b0);

always @(posedge clk) begin
    if(sr_last) begin
        data            <= data_bits;
        frame_error     <= (start_bits != {START{1'b0}}) || (stop_bits != {STOP{1'b1}});
        parity_error    <= (PARITY != 0) && (parity_bit != parity);
    end
end

// drive valid for 1 cycle
always @(posedge clk) begin
    if(rst || valid) begin
        valid           <= 1'b0;
    end else if(sr_last) begin
        valid           <= 1'b1;
    end
end

// generate sample_en
localparam OSBITS   = `dlsc_clog2(OVERSAMPLE);
reg [OSBITS-1:0] oscnt;

/* verilator lint_off WIDTH */
always @(posedge clk) begin
    if(!started) begin
        sample_en   <= 1'b0;
        oscnt       <= (OVERSAMPLE/2);
    end else begin
        sample_en   <= 1'b0;
        if(clk_en) begin
            oscnt       <= oscnt + 1;
            if(oscnt == (OVERSAMPLE-1)) begin
                oscnt       <= 0;
                sample_en   <= 1'b1;
            end
        end
    end
end
/* verilator lint_on WIDTH */

endmodule

