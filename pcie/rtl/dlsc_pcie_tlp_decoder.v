
module dlsc_pcie_tlp_decoder #(
    parameter USER_WIDTH = 7
) (
    // ** pcie common interface
    input   wire            clk,        // user_clk_out
    input   wire            rst,        // user_reset_out

    // ** pcie receive interface
    output  wire            rx_ready,   // m_axis_rx_tready
    input   wire            rx_valid,   // m_axis_rx_tvalid
    input   wire            rx_last,    // m_axis_rx_tlast
    input   wire    [31:0]  rx_data,    // m_axis_rx_tdata[31:0]

    input   wire    [USER_WIDTH-1:0] rx_user, // captured on first word

    // ** decoded TLP
    input   wire            tlp_ready,
    output  reg             tlp_valid,
    output  reg             tlp_malformed,  // missing header data
    output  reg     [USER_WIDTH-1:0] tlp_user, // captured rx_user data

    output  reg     [1:0]   tlp_fmt,
    output  reg     [4:0]   tlp_type,
    output  reg     [2:0]   traffic_class,
    output  reg             digest_present,
    output  reg             poisoned,
    output  reg     [1:0]   attributes,
    output  reg     [9:0]   length,
                                            //  mem io  cfg msg cpl
    output  reg     [15:0]  src_id,         //  x   x   x   x   x
    output  reg     [7:0]   src_tag,        //  x   x   x   x

    output  reg     [3:0]   be_last,        //  x   x   x
    output  reg     [3:0]   be_first,       //  x   x   x
    
    output  reg     [63:2]  dest_addr,      //  x   x       ~
    output  reg     [15:0]  dest_id,        //          x   ~   x

    output  reg     [7:0]   msg_code,       //              x

    output  reg     [9:0]   cfg_reg,        //          x

    output  reg     [2:0]   cpl_status,     //                  x
    output  reg             cpl_bcm,        //                  x
    output  reg     [11:0]  cpl_bytes,      //                  x
    output  reg     [7:0]   cpl_tag,        //                  x
    output  reg     [6:0]   cpl_addr,       //                  x

    // ** payload
    input   wire            data_ready,
    output  reg             data_valid,
    output  reg             data_last,
    output  reg     [31:0]  data
    
);

`include "dlsc_pcie_tlp_params.vh"


wire fmt_4dw        = tlp_fmt[0];
wire fmt_data       = tlp_fmt[1];


localparam  ST_WAIT     = 0,
            ST_DW0      = 1,
            ST_DW1      = 2,
            ST_DW2      = 3,
            ST_DW3      = 4,
            ST_PAYLOAD  = 5,
            ST_FLUSH    = 6;

reg [2:0] st;

wire    st_dw       = (st == ST_DW0 || st == ST_DW1 || st == ST_DW2 || st == ST_DW3);


assign  rx_ready    = ( st_dw || (st == ST_PAYLOAD && (!data_valid || data_ready)) || st == ST_FLUSH );

wire    rx_accept   = rx_ready && rx_valid;


reg expect_last;

always @* begin
    case(st)
        ST_DW0:  expect_last = 1'b0;
        ST_DW1:  expect_last = 1'b0;
        ST_DW2:  expect_last = !(digest_present || fmt_data || fmt_4dw);
        ST_DW3:  expect_last = !(digest_present || fmt_data);
        default: expect_last = 1'b0;
    endcase
end

wire    mismatch    = st_dw && (rx_last != expect_last);


wire    rst_tlp     = rst || (tlp_valid && tlp_ready);

always @(posedge clk) begin
    if(rst_tlp) begin
        tlp_valid       <= 1'b0;
        tlp_malformed   <= 1'b0;
        tlp_user        <= {USER_WIDTH{1'b0}};

        tlp_fmt         <= 2'b0;
        tlp_type        <= 5'b0;
        traffic_class   <= 3'b0;
        digest_present  <= 1'b0;
        poisoned        <= 1'b0;
        attributes      <= 2'b0;
        length          <= 10'b0;

        src_id          <= 16'b0;
        src_tag         <= 8'b0;

        be_last         <= 4'b0;
        be_first        <= 4'b0;

        dest_addr       <= {62{1'b0}};
        dest_id         <= 16'b0;

        msg_code        <= 8'b0;

        cfg_reg         <= 10'b0;

        cpl_status      <= 3'b0;
        cpl_bcm         <= 1'b0;
        cpl_bytes       <= 12'b0;
        cpl_tag         <= 8'b0;
        cpl_addr        <= 7'b0;
    end else if(rx_accept) begin
        if(st == ST_DW0) begin
            tlp_fmt         <= rx_data[30:29];
            tlp_type        <= rx_data[28:24];
            traffic_class   <= rx_data[22:20];
            digest_present  <= rx_data[15];
            poisoned        <= rx_data[14];
            attributes      <= rx_data[13:12];
            length          <= rx_data[9:0];
            tlp_user        <= rx_user;
        end

        if(st == ST_DW1) begin
            src_id          <= rx_data[31:16];
            src_tag         <= rx_data[15:8];
            be_last         <= rx_data[7:4];
            be_first        <= rx_data[3:0];
            msg_code        <= rx_data[7:0];
            cpl_status      <= rx_data[15:13];
            cpl_bcm         <= rx_data[12];
            cpl_bytes       <= rx_data[11:0];
        end

        if(st == ST_DW2) begin
            dest_id         <= rx_data[31:16];
            cfg_reg         <= rx_data[11:2];
            cpl_tag         <= rx_data[15:8];
            cpl_addr        <= rx_data[6:0];
        end

        if(st == ST_DW2 && fmt_4dw) begin
            dest_addr[63:32] <= rx_data[31:0];
        end

        if(st == ST_DW2 || st == ST_DW3) begin
            dest_addr[31:2] <= rx_data[31:2];
        end

        if( (st == ST_DW2 && !fmt_4dw) || (st == ST_DW3) || mismatch ) begin
            tlp_valid       <= 1'b1;
            tlp_malformed   <= mismatch;
        end
    end // rx_accept
end // clk


wire    rst_data    = rst || (st != ST_PAYLOAD && st != ST_WAIT) || (data_valid && data_ready && !rx_accept);

always @(posedge clk) begin
    if(rst_data) begin
        data_valid      <= 1'b0;
        data_last       <= 1'b0;
        data            <= 32'b0;
    end else if(rx_accept) begin
        data_valid      <= 1'b1;
        data_last       <= rx_last;
        data            <= rx_data;
    end
end


always @(posedge clk) begin
    if(rst) begin
        st              <= ST_WAIT;
    end else begin

        if(st == ST_WAIT) begin
            if( (!tlp_valid || tlp_ready) && (!data_valid || data_ready) ) begin
                st              <= ST_DW0;
            end
        end

        if(rx_accept) begin
            if(st == ST_DW0) begin
                st              <= ST_DW1;
            end

            if(st == ST_DW1) begin
                st              <= ST_DW2;
            end

            if(st == ST_DW2) begin
                if(fmt_4dw) begin
                    st              <= ST_DW3;
                end else if(fmt_data || digest_present) begin
                    st              <= ST_PAYLOAD;
                end else begin
                    st              <= ST_WAIT;
                end
            end

            if(st == ST_DW3) begin
                if(fmt_data || digest_present) begin
                    st              <= ST_PAYLOAD;
                end else begin
                    st              <= ST_WAIT;
                end
            end

            if(st == ST_PAYLOAD || st == ST_FLUSH) begin
                if(rx_last) begin
                    st              <= ST_WAIT;
                end
            end

            if(mismatch) begin
                if(rx_last) begin
                    st                  <= ST_WAIT;
                end else begin
                    st                  <= ST_FLUSH;
                end
            end
        end // rx_accept

    end // rst
end // clk

endmodule

