module dlsc_cpu1_alu #(
    parameter DEVICE="GENERIC"
) (
    // control
    input   wire    [3:0]       alu_op,
    input   wire                alu_signed,

    // input operands
    input   wire    [31:0]      in_a,           // from register
    input   wire    [31:0]      in_b,           // from register or constant

    // output
    output  wire    [31:0]      out_d,          // to register

    output  wire                out_flag,       // flag (used for comparisons)
    output  wire    [31:0]      out_add,        // output of adder only 
    output  wire                out_overflow    // adder overflowed (only valid when alu_add_signed asserted)
);

`include "dlsc_cpu1_params.vh"


// ** adder **

dlsc_cpu1_alu_add #(
    .DEVICE         ( DEVICE )
) dlsc_cpu1_alu_add (
    .alu_op         ( alu_op ),
    .alu_signed     ( alu_signed ),
    .in_a           ( in_a ),
    .in_b           ( in_b ),
    .out_flag       ( out_flag ),
    .out_add        ( out_add ),
    .out_overflow   ( out_overflow )
);

// ** shifter **

wire [31:0] out_shift;

dlsc_cpu1_alu_shift #(
    .DEVICE         ( DEVICE )
) dlsc_cpu1_alu_shift (
    .alu_op         ( alu_op ),
    .alu_signed     ( alu_signed ),
    .in_a           ( in_a ),
    .in_b           ( in_b ),
    .out_shift      ( out_shift )
);

assign out_d = alu_op[3] ? out_shift : out_add;


//wire signed [32:0] in_as = { in_a_sign, in_a };
//wire signed [32:0] in_bs = { in_b_sign, in_b };
//
//// ** logical **
//reg [31:0] out_logic;
//always @* begin
//    out_logic   = {32{1'bx}};
//    casez({alu_logic_bypass,alu_logic_op})
//        {1'b0,ALU_LOGIC_AND}: out_logic =  (in_a & in_b);
//        {1'b0,ALU_LOGIC_OR }: out_logic =  (in_a | in_b);
//        {1'b0,ALU_LOGIC_XOR}: out_logic =  (in_a ^ in_b);
//        {1'b0,ALU_LOGIC_NOR}: out_logic = ~(in_a | in_b);
//        {3'b1??            }: out_logic =   in_bypass;
//    endcase
//end
//
//
//// ** shifter **
//reg signed [32:0] out_shift;
//always @* begin
//    out_shift       = {33{1'bx}};
///* verilator lint_off WIDTH */
//    case(alu_shift_op)
//        ALU_SHIFT_LEFT:  out_shift = (in_as <<< in_b[4:0]);
//        ALU_SHIFT_RIGHT: out_shift = (in_as >>> in_b[4:0]);
//    endcase
///* verilator lint_on WIDTH */
//end
//
//
//// ** output mux **
//always @* begin
//    out_d       = {32{1'bx}};
//    case(alu_mode)
//        ALU_MODE_ADD:   out_d = out_add;
//        ALU_MODE_COMP:  out_d = { {31{1'b0}} , out_flag };
//        ALU_MODE_SHIFT: out_d = out_shift[31:0];
//        ALU_MODE_LOGIC: out_d = out_logic;
//    endcase
//end


endmodule

