
module dlsc_demosaic_vng6_rom #(
    parameter                   DATA    = 4,
    parameter [(DATA*12)-1:0]   ROM     = 0
) (
    input   wire                clk,

    input   wire    [3:0]       st,

    output  reg     [DATA-1:0]  out
);

always @(posedge clk) begin
    
    out <= {DATA{1'bx}};

    case(st)
         0: out <= ROM[ (DATA*11) +: DATA ];
         1: out <= ROM[ (DATA*10) +: DATA ];
         2: out <= ROM[ (DATA* 9) +: DATA ];
         3: out <= ROM[ (DATA* 8) +: DATA ];
         4: out <= ROM[ (DATA* 7) +: DATA ];
         5: out <= ROM[ (DATA* 6) +: DATA ];
         6: out <= ROM[ (DATA* 5) +: DATA ];
         7: out <= ROM[ (DATA* 4) +: DATA ];
         8: out <= ROM[ (DATA* 3) +: DATA ];
         9: out <= ROM[ (DATA* 2) +: DATA ];
        10: out <= ROM[ (DATA* 1) +: DATA ];
        11: out <= ROM[ (DATA* 0) +: DATA ];
    endcase

end

endmodule

