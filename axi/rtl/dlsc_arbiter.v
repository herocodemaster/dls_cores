
module dlsc_arbiter #(
    parameter CLIENTS = 2
) (
    input   wire                    clk,
    input   wire                    rst,

    input   wire                    update,

    input   wire    [CLIENTS-1:0]   in,
    output  wire    [CLIENTS-1:0]   out
);

generate
if(CLIENTS>1) begin:GEN_ARB

    // one-hot select for highest priority
    reg [CLIENTS-1:0] pri;

    always @(posedge clk) begin
        if(rst) begin
            pri     <= 1;
        end else if(update) begin
            pri     <= { pri[CLIENTS-2:0], pri[CLIENTS-1] };
        end
    end

    // duplicate the inputs for wrap-around
    localparam DUP = 2*CLIENTS;
    wire [DUP-1:0]  ind             = {2{in}};

    // find highest priority request
    wire [DUP-1:0]  outd            = ind & ~(ind - {{CLIENTS{1'b0}},pri});

    // consolidate duplicate outputs
    assign          out             = outd[ 0 +: CLIENTS] | outd[ CLIENTS +: CLIENTS ];

end else begin:GEN_PASSTHROUGH

    // just 1 client; arbitration not required
    assign          out             = in;

end
endgenerate

endmodule

