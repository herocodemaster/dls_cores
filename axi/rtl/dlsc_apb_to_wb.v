// 
// Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

// Module Description:
// Interfaces an APB master to a Wishbone slave (Classic Wishbone cycles only).

module dlsc_apb_to_wb #(
    parameter REGISTER      = 1,    // enable registering on interfaces (otherwise module is purely combinational)
    parameter ADDR          = 32,
    parameter DATA          = 32,
    // derived; don't touch
    parameter STRB          = (DATA/8)
) (
    // system
    input   wire                    clk,
    input   wire                    rst,
    
    // ** APB **

    input   wire    [ADDR-1:0]      apb_addr,
    input   wire                    apb_sel,
    input   wire                    apb_enable,
    input   wire                    apb_write,
    input   wire    [DATA-1:0]      apb_wdata,
    input   wire    [STRB-1:0]      apb_strb,

    output  reg                     apb_ready,
    output  reg     [DATA-1:0]      apb_rdata,
    output  reg                     apb_slverr,
    
    // ** Wishbone **

    // cycle
    output  reg                     wb_cyc_o,

    // address
    output  reg                     wb_stb_o,
    output  reg                     wb_we_o,
    output  reg     [ADDR-1:0]      wb_adr_o,

    // data
    output  reg     [DATA-1:0]      wb_dat_o,
    output  reg     [STRB-1:0]      wb_sel_o,

    // response
    input   wire                    wb_ack_i,
    input   wire                    wb_err_i,
    input   wire    [DATA-1:0]      wb_dat_i
);

generate
if(!REGISTER) begin:GEN_NO_REG

    always @* begin
        wb_cyc_o    = apb_sel;

        wb_stb_o    = apb_sel && apb_enable;
        wb_we_o     = apb_write;
        wb_adr_o    = apb_addr;

        wb_dat_o    = apb_wdata;
        wb_sel_o    = apb_write ? apb_strb : {STRB{1'b1}};

        apb_ready   = wb_stb_o ? wb_ack_i : 1'b0;
        apb_rdata   = wb_stb_o ? wb_dat_i : {DATA{1'b0}};
        apb_slverr  = wb_stb_o ? wb_err_i : 1'b0;
    end

end else begin:GEN_REG

    wire    set_cyc = apb_sel && !apb_ready && !wb_cyc_o;
    wire    clr_cyc = wb_cyc_o && wb_ack_i;

    always @(posedge clk) begin
        if(rst) begin
        
            apb_ready   <= 1'b0;
            apb_rdata   <= {DATA{1'b0}};
            apb_slverr  <= 1'b0;

            wb_cyc_o    <= 1'b0;
            wb_stb_o    <= 1'b0;

        end else begin

            apb_ready   <= 1'b0;
            apb_rdata   <= {DATA{1'b0}};
            apb_slverr  <= 1'b0;

            if(set_cyc) begin
                wb_cyc_o    <= 1'b1;
                wb_stb_o    <= 1'b1;
            end

            if(clr_cyc) begin
                wb_cyc_o    <= 1'b0;
                wb_stb_o    <= 1'b0;
                apb_ready   <= 1'b1;
                apb_rdata   <= wb_dat_i;
                apb_slverr  <= wb_err_i;
            end

        end
    end

    always @(posedge clk) begin
        if(set_cyc) begin
            wb_we_o     <= apb_write;
            wb_adr_o    <= apb_addr;
            wb_dat_o    <= apb_wdata;
            wb_sel_o    <= apb_write ? apb_strb : {STRB{1'b1}};
        end
    end

end
endgenerate

endmodule

