`default_nettype none
module wb_interface #(
    parameter OCT               = 8,
    parameter MY_MAC_ADDR_LOW   = 32'h3000_0000,
    parameter MY_MAC_ADDR_HIGH  = 32'h3000_0004,
    parameter MY_IP_ADDR        = 32'h3000_0008,
    parameter MY_PORT           = 32'h3000_000c,
    parameter RX_MEM_BASE       = 32'h4000_0000
)(
    // Wishbone interface
    input   wire        wb_clk_i,
    input   wire        wb_rst_i,
    input   wire        wbs_stb_i,
    input   wire        wbs_cyc_i,
    input   wire        wbs_we_i,
    input   wire  [3:0] wbs_sel_i,
    input   wire [31:0] wbs_dat_i,
    input   wire [31:0] wbs_adr_i,
    output  reg         wbs_ack_o,
    output  reg  [31:0] wbs_dat_o,
    // CSRs
    output  reg [OCT*6-1:0] mac_addr = 48'h01005e0000fb,
    output  reg [OCT*4-1:0] ip_addr  = 32'he00000fb,
    output  reg [OCT*2-1:0] port,
    // RX Memory
    input   wire            RX_CLK,
    input   wire            rx_udp_data_v,
    input   wire [OCT-1:0]  rx_udp_data,
    input   wire [OCT-1:0]  rx_mem_out
);

    // wishbone signal
    parameter WB_IDLE   = 2'b00;
    parameter WB_WRITE  = 2'b01;
    parameter WB_READ   = 2'b11;

    reg [1:0]   wb_state;
    reg [31:0]  wb_addr;
    reg [31:0]  wb_w_data;

    always @(posedge wb_clk_i) begin
        if(wb_rst_i) begin
            wb_state    <= WB_IDLE;
            wbs_ack_o   <= 1'b0;
        end else begin
            case(wb_state)
                WB_IDLE : begin
                    if(wbs_stb_i && wbs_cyc_i) begin
                        if(wbs_we_i) begin
                            wb_state    <= WB_WRITE;
                            wb_w_data   <= wbs_dat_i;
                        end else begin
                            wb_state <= WB_READ;
                        end
                        wb_addr <= wbs_adr_i;
                    end
                    wbs_ack_o   <= 1'b0;
                end
                WB_WRITE: begin
                    case(wb_addr)
                        MY_MAC_ADDR_LOW : begin
                            mac_addr[OCT*4-1:0] <= wb_w_data;
                        end
                        MY_MAC_ADDR_HIGH: begin
                            mac_addr[OCT*6-1:OCT*4] <= wb_w_data;
                        end
                        MY_IP_ADDR  : begin
                            ip_addr     <= wb_w_data;
                        end
                        MY_PORT     : begin
                            port        <= wb_w_data;
                        end
                        default     : begin
                        end
                    endcase
                    wbs_ack_o   <= 1'b1;
                    if(wbs_stb_i && wbs_cyc_i) begin
                        if(wbs_we_i) begin
                            wb_state    <= WB_WRITE;
                            wb_w_data   <= wbs_dat_i;
                        end else begin
                            wb_state <= WB_READ;
                        end
                        wb_addr <= wbs_adr_i;
                    end else begin
                        wb_state <= WB_IDLE;
                    end
                end
                WB_READ : begin
                    case(wb_addr)
                        MY_MAC_ADDR_LOW : begin
                            wbs_dat_o   <= mac_addr[OCT*4-1:0];
                        end
                        MY_MAC_ADDR_HIGH: begin
                            wbs_dat_o   <= {16'h0000, mac_addr[OCT*6-1:OCT*4]};
                        end
                        MY_IP_ADDR  : begin
                            wbs_dat_o   <= ip_addr;
                        end
                        MY_PORT     : begin
                            wbs_dat_o   <= ip_addr;
                        end
                        default     : begin
                            if(wb_addr[31:12] == 20'h4000_0) begin
                                wbs_dat_o <= rx_mem_out;
                            end
                        end
                    endcase
                    wbs_ack_o   <= 1'b1;
                    if(wbs_stb_i && wbs_cyc_i) begin
                        if(wbs_we_i) begin
                            wb_state    <= WB_WRITE;
                            wb_w_data   <= wbs_dat_i;
                        end else begin
                            wb_state <= WB_READ;
                        end
                        wb_addr <= wbs_adr_i;
                    end else begin
                        wb_state <= WB_IDLE;
                    end
                end
            endcase
        end
    end
endmodule
`default_nettype wire
