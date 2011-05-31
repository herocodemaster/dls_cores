module dlsc_cpu1_alu (

    // control
    input   wire    [1:0]       alu_mode,
    input   wire    [1:0]       alu_add_op,
    input   wire                alu_add_signed, // only affects flag output
    input   wire    [1:0]       alu_logic_op,
    input   wire                alu_logic_bypass,   // enable pass-through of in_bypass
    input   wire                alu_shift_op,

    // input operands
    input   wire    [31:0]      in_a,           // from register
    input   wire                in_a_sign,
    input   wire    [31:0]      in_b,           // from register or constant
    input   wire                in_b_sign,
    input   wire    [31:0]      in_bypass,

    // output
    output  reg     [31:0]      out_d,          // to register

    output  reg                 out_flag,       // flag (used for comparisons)
    output  reg     [31:0]      out_add,        // output of adder only 
    output  reg                 out_overflow    // adder overflowed (only valid when alu_add_signed asserted)
);

localparam  ALU_MODE_ADD    = 2'b00,
            ALU_MODE_COMP   = 2'b01,
            ALU_MODE_SHIFT  = 2'b10,
            ALU_MODE_LOGIC  = 2'b11;

localparam  ALU_ADD_ADD     = 2'b00,
            ALU_ADD_SUB     = 2'b01,
            ALU_ADD_EQU     = 2'b10,
            ALU_ADD_NEQU    = 2'b11;

localparam  ALU_LOGIC_AND   = 2'b00,
            ALU_LOGIC_OR    = 2'b01,
            ALU_LOGIC_XOR   = 2'b10,
            ALU_LOGIC_NOR   = 2'b11;

localparam  ALU_SHIFT_LEFT  = 1'b0,
            ALU_SHIFT_RIGHT = 1'b1;


wire signed [32:0] in_as = { in_a_sign, in_a };
wire signed [32:0] in_bs = { in_b_sign, in_b };


// ** adder **
always @* begin
    out_flag    = 1'bx;
    out_add     = {32{1'bx}};
    case(alu_add_op)
        ALU_ADD_ADD:    {out_flag,out_add} = (in_as + in_bs);
        ALU_ADD_SUB:    {out_flag,out_add} = (in_as - in_bs);
        // use carry chain for fast equality comparison (TODO: may not infer correctly..)
        ALU_ADD_EQU:    out_flag           = (in_as == in_bs);
        ALU_ADD_NEQU:   out_flag           = (in_as != in_bs);
    endcase
end

always @* begin
    // sign bit mismatch (lost information)
    out_overflow = (out_flag != out_add[31]);
end


// ** logical **
reg [31:0] out_logic;
always @* begin
    out_logic   = {32{1'bx}};
    casez({alu_logic_bypass,alu_logic_op})
        {1'b0,ALU_LOGIC_AND}: out_logic =  (in_a & in_b);
        {1'b0,ALU_LOGIC_OR }: out_logic =  (in_a | in_b);
        {1'b0,ALU_LOGIC_XOR}: out_logic =  (in_a ^ in_b);
        {1'b0,ALU_LOGIC_NOR}: out_logic = ~(in_a | in_b);
        {3'b1??            }: out_logic =   in_bypass;
    endcase
end


// ** shifter **
reg signed [32:0] out_shift;
always @* begin
    out_shift       = {33{1'bx}};
/* verilator lint_off WIDTH */
    case(alu_shift_op)
        ALU_SHIFT_LEFT:  out_shift = (in_as <<< in_b[4:0]);
        ALU_SHIFT_RIGHT: out_shift = (in_as >>> in_b[4:0]);
    endcase
/* verilator lint_on WIDTH */
end


// ** output mux **
always @* begin
    out_d       = {32{1'bx}};
    case(alu_mode)
        ALU_MODE_ADD:   out_d = out_add;
        ALU_MODE_COMP:  out_d = { {31{1'b0}} , out_flag };
        ALU_MODE_SHIFT: out_d = out_shift[31:0];
        ALU_MODE_LOGIC: out_d = out_logic;
    endcase
end


endmodule

