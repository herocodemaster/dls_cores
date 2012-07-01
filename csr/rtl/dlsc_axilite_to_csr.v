// 
// Copyright (c) 2012, Daniel Strother < http://danstrother.com/ >
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
// Interfaces an AXI-Lite master to a CSR slave.
    
module dlsc_axilite_to_csr #(
    parameter DATA          = 32,
    parameter ADDR          = 32,
    // derived; don't touch
    parameter STRB          = (DATA/8)
) (
    // system
    input   wire                    clk,
    input   wire                    rst,

    // ** AXI **

    // read command
    output  reg                     axi_ar_ready,
    input   wire                    axi_ar_valid,
    input   wire    [ADDR-1:0]      axi_ar_addr,

    // read data/response
    input   wire                    axi_r_ready,
    output  reg                     axi_r_valid,
    output  reg                     axi_r_last,
    output  reg     [DATA-1:0]      axi_r_data,
    output  reg     [1:0]           axi_r_resp,

    // write command
    output  reg                     axi_aw_ready,
    input   wire                    axi_aw_valid,
    input   wire    [ADDR-1:0]      axi_aw_addr,

    // write data
    output  reg                     axi_w_ready,
    input   wire                    axi_w_valid,
    input   wire    [DATA-1:0]      axi_w_data,
    input   wire    [STRB-1:0]      axi_w_strb,

    // write response
    input   wire                    axi_b_ready,
    output  reg                     axi_b_valid,
    output  reg     [1:0]           axi_b_resp,
    
    // ** CSR **
    
    // command
    output  reg                     csr_cmd_valid,
    output  reg                     csr_cmd_write,
    output  reg     [ADDR-1:0]      csr_cmd_addr,
    output  reg     [DATA-1:0]      csr_cmd_data,

    // response
    input   wire                    csr_rsp_valid,
    input   wire                    csr_rsp_error,
    input   wire    [DATA-1:0]      csr_rsp_data
);

`include "dlsc_clog2.vh"

localparam  LSB             = `dlsc_clog2(STRB);

localparam  AXI_RESP_OKAY   = 2'b00,
            AXI_RESP_SLVERR = 2'b10;

localparam  ST_CMD          = 2'b00,
            ST_WAIT         = 2'b01,
            ST_RSP          = 2'b10,
            ST_DUMMY        = 2'b11;

reg  [1:0]      st;


// ** select command **

reg             arb_valid;
wire            arb_write   = axi_ar_valid ? 1'b0 : 1'b1;
wire [ADDR-1:0] arb_addr    = axi_ar_valid ? axi_ar_addr : axi_aw_addr;
wire [DATA-1:0] arb_data    = axi_w_data;
wire [STRB-1:0] arb_strb    = axi_w_strb;

always @* begin
    arb_valid       = 1'b0;
    axi_ar_ready    = 1'b0;
    axi_aw_ready    = 1'b0;
    axi_w_ready     = 1'b0;
    if(st == ST_CMD) begin
        if(axi_ar_valid) begin
            arb_valid       = 1'b1;
            axi_ar_ready    = 1'b1;
        end else if(axi_aw_valid && axi_w_valid) begin
            arb_valid       = 1'b1;
            axi_aw_ready    = 1'b1;
            axi_w_ready     = 1'b1;
        end
    end
end


// ** drive command **

wire    rsp_okay    = ((axi_b_ready || !axi_b_valid) && (axi_r_ready || !axi_r_valid));
wire    rsp_dummy   = (st == ST_DUMMY && rsp_okay);

always @(posedge clk) begin
    if(rst) begin
        csr_cmd_valid   <= 1'b0;
        st              <= ST_CMD;
    end else begin
        csr_cmd_valid   <= 1'b0;
        if(st == ST_CMD && arb_valid) begin
            if(arb_write && arb_strb == {STRB{1'b0}}) begin
                // no strobes enabled; create dummy response
                st              <= ST_DUMMY;
            end else if(rsp_okay) begin
                // drive command
                csr_cmd_valid   <= 1'b1;
                st              <= ST_RSP;
            end else begin
                // must wait for master to accept previous response
                st              <= ST_WAIT;
            end
        end
        if(st == ST_WAIT && rsp_okay) begin
            // drive deferred command
            csr_cmd_valid   <= 1'b1;
            st              <= ST_RSP;
        end
        if(st == ST_RSP && csr_rsp_valid) begin
            st              <= ST_CMD;
        end
        if(st == ST_DUMMY && rsp_dummy) begin
            st              <= ST_CMD;
        end
    end
end

always @(posedge clk) begin
    if(arb_valid) begin
        csr_cmd_write   <= arb_write;
        csr_cmd_addr    <= { arb_addr[ADDR-1:LSB], {LSB{1'b0}} };
    end
    if(arb_valid && arb_write) begin
        csr_cmd_data    <= arb_data;
    end
end


// ** drive response **

always @(posedge clk) begin
    if(rst) begin
        axi_r_valid     <= 1'b0;
        axi_r_last      <= 1'b1;
        axi_b_valid     <= 1'b0;
    end else begin
        if(axi_r_ready) axi_r_valid <= 1'b0;
        if(axi_b_ready) axi_b_valid <= 1'b0;
        if(csr_rsp_valid) begin
            if(!csr_cmd_write) axi_r_valid <= 1'b1;
            if( csr_cmd_write) axi_b_valid <= 1'b1;
        end
        if(rsp_dummy) axi_b_valid <= 1'b1;
    end
end

always @(posedge clk) begin
    if(csr_rsp_valid && !csr_cmd_write) begin
        axi_r_resp  <= csr_rsp_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
        axi_r_data  <= csr_rsp_data;
    end
end

always @(posedge clk) begin
    if(csr_rsp_valid && csr_cmd_write) begin
        axi_b_resp  <= csr_rsp_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
    end
    if(rsp_dummy) begin
        axi_b_resp  <= AXI_RESP_OKAY;
    end
end


// ** simulation checks **

`ifdef DLSC_SIMULATION
`include "dlsc_sim_top.vh"

always @(posedge clk) if(!rst) begin
    if(axi_ar_ready && axi_ar_valid) begin
        if(axi_ar_addr[LSB-1:0] != {LSB{1'b0}}) begin
            `dlsc_warn("unaligned accesses not supported");
        end
    end
    if(axi_aw_ready && axi_aw_valid) begin
        if(axi_aw_addr[LSB-1:0] != {LSB{1'b0}}) begin
            `dlsc_warn("unaligned accesses not supported");
        end
    end
    if(axi_w_ready && axi_w_valid) begin
        if( axi_w_strb != {STRB{1'b0}} && axi_w_strb != {STRB{1'b1}} ) begin
            `dlsc_warn("sparse write strobes are not supported");
        end
    end
    if(st != ST_CMD && ((axi_ar_ready && axi_ar_valid) || (axi_aw_ready && axi_aw_valid) || (axi_w_ready && axi_w_valid))) begin
        `dlsc_error("lost command");
    end
    if(st != ST_RSP && csr_rsp_valid) begin
        `dlsc_error("lost response");
    end
    if(csr_rsp_valid && ((axi_r_valid && !axi_r_ready) || (axi_b_valid && !axi_b_ready))) begin
        `dlsc_error("response overflow");
    end
end

`include "dlsc_sim_bot.vh"
`endif


endmodule


