
module dlsc_axid_slave_dummy #(
    parameter WIDTH = 32
) (
    input   wire                clk,
    input   wire                rst,

    output  reg                 axid_ar_ready,
    input   wire                axid_ar_valid,
    input   wire    [31:0]      axid_ar_addr,
    input   wire    [3:0]       axid_ar_len,

    input   wire                axid_r_ready,
    output  reg                 axid_r_valid,
    output  reg                 axid_r_last,
    output  reg     [WIDTH-1:0] axid_r_data,
    output  reg     [1:0]       axid_r_resp,
    
    output  reg                 axid_aw_ready,
    input   wire                axid_aw_valid,
    input   wire    [31:0]      axid_aw_addr,
    input   wire    [3:0]       axid_aw_len,

    output  reg                 axid_w_ready,
    input   wire                axid_w_valid,
    input   wire                axid_w_last,
    input   wire    [WIDTH-1:0] axid_w_data,
    input   wire    [(WIDTH/8)-1:0] axid_w_strb,

    input   wire                axid_b_ready,
    output  reg                 axid_b_valid,
    output  reg     [1:0]       axid_b_resp
);

reg [4:0] axid_r_cnt = 0;

always @(posedge clk) begin
    if(rst) begin
        axid_ar_ready    <= 1'b0;
        axid_r_cnt       <= 0;
        axid_r_valid     <= 1'b0;
        axid_r_last      <= 1'b0;
        axid_r_data      <= 0;
        axid_r_resp      <= 2'b00;
    end else begin
        if(axid_ar_ready && axid_ar_valid) begin
            $display("%t: AR: addr = %x, len= %x", $time, axid_ar_addr, axid_ar_len);
            axid_ar_ready    <= 1'b0;
            axid_r_cnt       <= {1'b0,axid_ar_len} + 1;
        end
        if(axid_r_valid && axid_r_ready) begin
            $display("%t: R: data = %x, last = %x", $time, axid_r_data, axid_r_last);
            axid_r_valid     <= 1'b0;
            axid_r_last      <= 1'b0;
            axid_r_data      <= 0;
            axid_r_resp      <= 2'b00;
        end
        if(axid_r_cnt != 0) begin
            if(!axid_r_valid || axid_r_ready) begin
                axid_r_valid     <= 1'b1;
                axid_r_last      <= axid_r_cnt == 1;
                axid_r_data      <= $random;
                axid_r_cnt       <= axid_r_cnt - 1;
                axid_r_resp      <= 2'b00;
            end
        end else if(!axid_ar_ready) begin
            axid_ar_ready    <= 1'b1;
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        axid_aw_ready    <= 1'b0;
    end else begin
        axid_aw_ready    <= 1'b1;
        if(axid_aw_ready && axid_aw_valid) begin
            $display("%t: AW: addr = %x, len= %x", $time, axid_aw_addr, axid_aw_len);
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        axid_w_ready     <= 1'b0;
        axid_b_valid     <= 1'b0;
        axid_b_resp      <= 2'b00;
    end else begin
        if(axid_b_ready && axid_b_valid) begin
            $display("%t: B: resp = %x", $time, axid_b_resp);
            axid_b_valid     <= 1'b0;
            axid_b_resp      <= 2'b00;
        end

        axid_w_ready    <= 1'b1;
        if(axid_w_ready && axid_w_valid) begin
            $display("%t: W: data = %x, strb = %x, last = %x", $time, axid_w_data, axid_w_strb, axid_w_last);

            if(axid_w_last) begin
                axid_b_valid     <= 1'b1;
                axid_b_resp      <= 2'b00;
            end
        end
    end
end

endmodule

