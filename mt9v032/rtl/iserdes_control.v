
module iserdes_control #(
    parameter WIDTH     = 1
) (
    input   wire                    clk_div,
    input   wire                    rst,
    
    output  reg                     ready,
    
    input   wire    [WIDTH-1:0]     iod_busy,
    
    output  reg                     iod_rst,
    output  reg                     iod_mask,
    output  reg                     iod_cal,
    output  reg                     iod_cal_master
);

// register busy flags to cut long timing paths
reg [WIDTH-1:0] iod_busy_reg;
always @(posedge clk_div)
    iod_busy_reg <= iod_busy;

// IODELAY calibration state-machine
wire                    iod_any_busy = |iod_busy_reg;
wire                    iod_all_busy = &iod_busy_reg;

reg     [11:0]  iod_cnt;
reg             iod_cnt_rst;
wire            iod_cnt_max = iod_cnt[11];
reg     [2:0]   iod_state;

always @(posedge clk_div) begin
    if(iod_cnt_rst || iod_cnt_max) begin
        iod_cnt         <= 0;
    end else begin
        iod_cnt         <= iod_cnt + 1;
    end
end

always @(posedge clk_div) begin
    if(rst) begin
    
        iod_state       <= 0;
        iod_cnt_rst     <= 1'b1;

        // TODO: IODELAY2 simulation model doesn't like this extra reset; unclear
        // how real hardware behaves.. for now, try without initial reset.
        iod_rst         <= 1'b1;
        //iod_rst         <= 1'b0;

        iod_mask        <= 1'b1;
        iod_cal         <= 1'b0;
        iod_cal_master  <= 1'b0;
        ready           <= 1'b0;
        
    end else begin
    
        iod_cnt_rst     <= 1'b1;
        iod_rst         <= 1'b0;
        iod_mask        <= 1'b0;
        iod_cal         <= 1'b0;
        iod_cal_master  <= 1'b0;
                
        // wait until IODELAY is ready
        if(iod_state == 0) begin
            iod_cnt_rst     <= 1'b0;
            iod_mask        <= 1'b1;
            if(iod_cnt_max && !iod_any_busy) begin
                iod_state       <= 1;
            end
        end
        
        // initial calibration
        if(iod_state == 1) begin
            iod_mask        <= 1'b1;
            iod_cal         <= 1'b1;
            iod_cal_master  <= 1'b1;
            // wait for acceptance
            if(iod_all_busy) begin
                iod_state       <= 2;
                iod_cal         <= 1'b0;
                iod_cal_master  <= 1'b0;
            end
        end
        
        // wait for calibration completion, then reset
        if(iod_state == 2) begin
            iod_mask        <= 1'b1;
            if(!iod_any_busy) begin
                iod_state       <= 3;
                iod_rst         <= 1'b1;
            end
        end
        
        // wait for periodic calibration
        if(iod_state == 3) begin
            iod_cnt_rst     <= 1'b0;
            if(iod_cnt_max) begin
                iod_state       <= 4;
            end
        end
        
        // mask shortly before calibration
        if(iod_state == 4) begin
            iod_cnt_rst     <= iod_any_busy; // don't start timing if any are busy 
            iod_mask        <= 1'b1;
            if(iod_cnt[4]) begin
                iod_state       <= 5;
            end
        end
        
        // calibrate slave
        if(iod_state == 5) begin
            iod_mask        <= 1'b1;
            iod_cal         <= 1'b1;
            // wait for acceptance
            if(iod_all_busy) begin
                iod_state       <= 6;
                iod_cal         <= 1'b0;
            end
        end
        
        // wait for completion
        if(iod_state == 6) begin
            iod_mask        <= 1'b1;
            if(!iod_any_busy) begin
                iod_state       <= 7;
            end
        end
        
        // wait a bit before unmasking
        if(iod_state == 7) begin
            iod_cnt_rst     <= 1'b0;
            iod_mask        <= 1'b1;
            if(iod_cnt[4]) begin
                ready           <= 1'b1; // only ready once the first recalibration completes
                iod_state       <= 3;
            end
        end
        
    end
end

endmodule

