
module dlsc_div32 #(
    parameter DEVICE="GENERIC"
) (
    // system
    input   wire                clk,

    // input
    input   wire    [31:0]      dividend,
    input   wire    [31:0]      divisor,

    // control
    input   wire                sign,
    input   wire                start,
    
    // status
    output  wire                done,

    // output
    output  wire    [31:0]      quotient,
    output  wire    [31:0]      remainder
);

// start:
//  ap  <= dividend;
//  b   <= divisor;
//  q   <= 0;
//  done<= 0;
// st0..31:
//  ap  <= (sel?ap:a);
//  a   <= (sel?ap:a) +- b
//  b   <= b >> 1
//  q   <= (q << 1) | ~sel;
// st32:
//  ap  <= (sel?ap:a)       // remainder
//  a   <= 0;
//  b   <= (q << 1) | ~sel;
// st33:
//  ap  <= ap;              // remainder
//  a   <= 0 - b;           // quotient
//  done<= 1;
//

// registers
reg         sign_r;     // operands are signed
reg         sign_eq;    // operands are of equal signs
reg         sel;        // subtraction underflow; use ap
reg  [32:0] a;
reg  [32:0] ap;
wire [62:0] b;
wire        bof;        // b overflow (has significant digits outside of 31:0)
reg         bof_r;      // previous bof
reg  [31:0] q;
reg         rem0;       // no remainder

// next-state
reg  [32:0] next_a;
reg  [62:0] next_b;
wire [31:0] next_q;

// state
reg  [4:0]  st;
reg         st0;
reg         st32;
reg         st33;
reg         active;

// output
assign      done        = !active;
assign      quotient    = a [31:0];
assign      remainder   = ap[31:0];

always @(posedge clk) begin
    if(start) begin
        sign_r      <= sign;
        st          <= 0;
        st0         <= 1'b1;
        st32        <= 1'b0;
        st33        <= 1'b0;
        active      <= 1'b1;
    end else if(active) begin
        st          <= st + 1;
        st0         <= 1'b0;
        st32        <= &st[4:0];
        st33        <= st32;
        if(st33) active <= 1'b0;
    end
end

always @(posedge clk) begin
    if(start) begin
        sign_eq     <= !sign || (dividend[31] == divisor[31]);
    end else if(st32) begin
        // only complement quotient if operand signs differed
        sign_eq     <= !sign_eq;
    end
end

assign      bof         = !( ({30{b[62]}} == b[61:32]) && (!b[62] || sign_r) );

always @(posedge clk) begin
    if(start) begin
        sel         <= 1'b1;
        bof_r       <= 1'b1;
    end else if(active) begin
        sel         <= ((next_a[32] != ap[32]) || bof) && !st32;
        bof_r       <= bof;
    end
end

wire        rst_ap      = rem0 && st33;
wire        ce_ap       = start || (active && !sel && !st33);

always @(posedge clk) begin
    if(rst_ap) begin
        ap          <= 0;
    end else if(ce_ap) begin
        if(start) begin
            ap[32]      <= dividend[31] && sign;
            ap[31:0]    <= dividend[31:0];
        end else begin
            ap[32:0]    <= a[32:0];
        end
    end
end

always @* begin
    case({sel,sign_eq})
        2'b00: next_a = a  + b[32:0];
        2'b01: next_a = a  - b[32:0];
        2'b10: next_a = ap + b[32:0];
        2'b11: next_a = ap - b[32:0];
    endcase
end

always @(posedge clk) begin
    if(st32) begin
        a           <= 0;
    end else if(active) begin
        a           <= next_a;
    end
end

wire        q_mask      = st0 || bof_r || rem0;
wire        a_zero      = (a == 33'h0);

always @(posedge clk) begin
    if(start) begin
        rem0        <= 1'b0;
    end else if(a_zero && !q_mask) begin
        rem0        <= 1'b1;
    end
end

wire        next_q0     = (!sel || a_zero) && !q_mask;
assign      next_q      = { q[30:0], next_q0 };

always @(posedge clk) begin
    if(start) begin
        q           <= 0;
    end else if(active) begin
        q           <= next_q;
    end
end

reg [62:31] bh;
reg [30:0]  bl;
assign      b           = {bh,bl};

always @* begin
    next_b[62]      = b[62] && sign_r;
    next_b[61:32]   = b[62:33];
    next_b[31:0]    = st32 ? next_q : b[32:1];
end

wire        ce_bh       = start || active;

always @(posedge clk) begin
    if(ce_bh) begin
        if(start) begin
            bh          <= divisor[31:0];
        end else begin
            bh          <= next_b[62:31];
        end
    end
end

always @(posedge clk) begin
    if(start) begin
        bl          <= 0;
    end else if(active) begin
        bl          <= next_b[30:0];
    end
end


endmodule

