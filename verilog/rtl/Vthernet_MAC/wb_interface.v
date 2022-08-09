`default_nettype none
module wb_interface #(
    parameter OCT               = 8,
    parameter MY_MAC_ADDR_LOW   = 32'h3000_0000,
    parameter MY_MAC_ADDR_HIGH  = 32'h3000_0004,
    parameter MY_IP_ADDR        = 32'h3000_0008,
    parameter MY_PORT           = 32'h3000_000c,
    parameter SRC_MAC_ADDR_LOW  = 32'h3000_0010,
    parameter SRC_MAC_ADDR_HIGH = 32'h3000_0014,
    parameter SRC_IP_ADDR       = 32'h3000_001c,
    parameter SRC_PORT          = 32'h3000_0020,
    parameter OFFLOAD_CSR       = 32'h3000_0024,
    parameter RX_ETHERNET_LEN_TYPE = 32'h3000_002c,
    parameter RX_IPV4_VERSION   = 32'h3000_0030,
    parameter RX_IPV4_HEADER_LEN= 32'h3000_0034,
    parameter RX_IPV4_TOS       = 32'h3000_0038, 
    parameter RX_IPV4_TOTAL_LEN = 32'h3000_003c,
    parameter RX_IPV4_ID        = 32'h3000_0040,
    parameter RX_IPV4_FLAG_FRAG = 32'h3000_0044, 
    parameter RX_IPV4_TTL       = 32'h3000_0048,
    parameter RX_IPV4_PROTOCOL  = 32'h3000_004c, 
    parameter RX_IPV4_CHECKSUM  = 32'h3000_0050,
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
    input   wire [OCT*6-1:0] src_mac,
    input   wire [OCT*4-1:0] src_ip,
    input   wire [OCT*2-1:0] src_port,
    output  reg [OCT*4-1:0] offload_csr,
    input   wire [OCT*2-1:0] rx_ethernet_len_type,
    input   wire [3:0]       rx_ipv4_version,
    input   wire [3:0]       rx_ipv4_header_len,
    input   wire [OCT-1:0]   rx_ipv4_tos,
    input   wire [OCT*2-1:0] rx_ipv4_total_len,
    input   wire [OCT-1:0]   rx_ipv4_id,
    input   wire [OCT*2-1:0] rx_ipv4_flag_frag,
    input   wire [OCT-1:0]   rx_ipv4_ttl,
    input   wire [OCT-1:0]   rx_ipv4_protocol,
    input   wire [OCT-1:0]   rx_ipv4_checksum,

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
                        OFFLOAD_CSR : begin
                            offload_csr <= wb_w_data;
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
                            wbs_dat_o   <= {16'h0000, port};
                        end
                        SRC_MAC_ADDR_LOW    : begin
                            wbs_dat_o   <= src_mac[OCT*4-1:0];
                        end
                        SRC_MAC_ADDR_HIGH   : begin
                            wbs_dat_o   <= {16'h0000, src_mac[OCT*6-1:OCT*4]};
                        end
                        SRC_IP_ADDR : begin
                            wbs_dat_o   <= src_ip;
                        end
                        SRC_PORT            : wbs_dat_o <= {16'h0000, src_port};
                        RX_ETHERNET_LEN_TYPE: wbs_dat_o <= {16'h0000, rx_ethernet_len_type};
                        RX_IPV4_VERSION     : wbs_dat_o <= {28'h0000_000, rx_ipv4_version};
                        RX_IPV4_HEADER_LEN  : wbs_dat_o <= {28'h0000_000, rx_ipv4_header_len};
                        RX_IPV4_TOS         : wbs_dat_o <= {24'h0000_00, rx_ipv4_tos};
                        RX_IPV4_TOTAL_LEN   : wbs_dat_o <= {16'h0000, rx_ipv4_total_len};
                        RX_IPV4_ID          : wbs_dat_o <= {24'h0000_00, rx_ipv4_id};
                        RX_IPV4_FLAG_FRAG   : wbs_dat_o <= {16'h0000, rx_ipv4_flag_frag};
                        RX_IPV4_TTL         : wbs_dat_o <= {24'h0000_00, rx_ipv4_ttl};
                        RX_IPV4_PROTOCOL    : wbs_dat_o <= {24'h0000_00, rx_ipv4_protocol};
                        RX_IPV4_CHECKSUM    : wbs_dat_o <= {24'h0000_00, rx_ipv4_checksum};
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
