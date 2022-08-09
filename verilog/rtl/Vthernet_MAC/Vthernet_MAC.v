//
//  ethernet --- IP ---- UDP
//            |       |
//            -- ARP  -- TCP
//

`default_nettype none
module Vthernet_MAC(
`ifdef USE_POWER_PINS
    inout   vccd1,
    inout   vssd1,
`endif
    input   wire        rst,
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

    // GMII interface
    output  reg         GTX_CLK,
    output  reg         TX_EN,
    output  reg [7:0]   TXD,
    output  reg         TX_ER,

    input   wire        RX_CLK,
    input   wire        RX_DV,
    input   wire [7:0]  RXD,
    input   wire        RX_ER,

    output  reg         MDC,
    inout   reg         MDIO,

    // PicoRV interface
    output  wire        rx_irq,

    // Memory interface
    output  wire        rx_data_vb,
    output  wire [7:0]  rx_data,
    input   wire [7:0]  rx_mem_out,
    output  reg [10:0]  rx_addr,
    // write    : when web0 = 0, csb0 = 0
    // read     : when web0 = 1, csb0 = 0, maybe 3 clock delay...?
    // read     : when csb0 = 0, maybe 3 clock delay...?
    output  wire        wmask0,
    output  wire        csb1,
    input   wire [7:0]  dout0,
    // Caravel interfce
    output  wire [23:0] io_oeb
);
    parameter OCT   = 8;
    parameter PRE   = 8'b10101010;
    parameter SFD   = 8'b10101011;
    parameter IPV4  = 16'h0800;

    // Top Level Signal
    wire        rx_data_v;
    assign rx_data_vb = ~rx_data_v;
    assign wmask0   = 1'b1;
    assign csb1     = ~wbs_stb_i;
    assign io_oeb[10:0]  = 11'b000_0000_0000;
    assign io_oeb[23:11] = 13'b1_1111_1111_1111;

    // Vthernet CSR
    wire [OCT*4-1:0] offload_csr;
    
    wire [OCT*6-1:0] mac_addr;
    wire [OCT*4-1:0] ip_addr;
    wire [OCT*2-1:0] port;

    wire [OCT*6-1:0] rx_src_mac;
    wire [OCT*4-1:0] rx_src_ip;
    wire [OCT*2-1:0] rx_src_port;

    wire [OCT*2-1:0] rx_ethernet_len_type;

    wire [3:0]       rx_ipv4_version;
    wire [3:0]       rx_ipv4_header_len;
    wire [OCT-1:0]   rx_ipv4_tos;
    wire [OCT*2-1:0] rx_ipv4_total_len;
    wire [OCT-1:0]   rx_ipv4_id;
    wire [OCT*2-1:0] rx_ipv4_flag_frag;
    wire [OCT-1:0]   rx_ipv4_ttl;
    wire [OCT-1:0]   rx_ipv4_protocol;
    wire [OCT-1:0]   rx_ipv4_checksum;

    // RX Memory logic

    always @(posedge RX_CLK) begin
        if(rst) begin
            rx_addr <= 10'h000;
        end else begin
            if(rx_udp_data_v) begin
                rx_addr <= rx_addr + 10'h001;
            end else begin
                rx_addr <= 10'h000;
            end
        end
    end

    // Wishbone logic
    wb_interface #(
        // CSRs addr
        .MY_MAC_ADDR_LOW    (32'h3000_0000),
        .MY_MAC_ADDR_HIGH   (32'h3000_0004),
        .MY_IP_ADDR         (32'h3000_0008),
        .MY_PORT            (32'h3000_000c),
        .SRC_MAC_ADDR_LOW   (32'h3000_0010),
        .SRC_MAC_ADDR_HIGH  (32'h3000_0014),
        .SRC_IP_ADDR        (32'h3000_001c),
        .SRC_PORT           (32'h3000_0020),
        .OFFLOAD_CSR        (32'h3000_0024),
        .RX_ETHERNET_LEN_TYPE (32'h3000_002c),
        .RX_IPV4_VERSION    (32'h3000_0030),
        .RX_IPV4_HEADER_LEN (32'h3000_0034),
        .RX_IPV4_TOS        (32'h3000_0038),
        .RX_IPV4_TOTAL_LEN  (32'h3000_003c),
        .RX_IPV4_ID         (32'h3000_0040),
        .RX_IPV4_FLAG_FRAG  (32'h3000_0044),
        .RX_IPV4_TTL        (32'h3000_0048),
        .RX_IPV4_PROTOCOL   (32'h3000_004c),
        .RX_IPV4_CHECKSUM   (32'h3000_0050),
        .RX_MEM_BASE        (32'h4000_0000)
    ) wb_interface_inst(
        .wb_clk_i   (wb_clk_i   ),
        .wb_rst_i   (wb_rst_i   ),
        .wbs_stb_i  (wbs_stb_i  ),
        .wbs_cyc_i  (wbs_cyc_i  ),
        .wbs_we_i   (wbs_we_i   ),
        .wbs_sel_i  (wbs_sel_i  ),
        .wbs_dat_i  (wbs_dat_i  ),
        .wbs_adr_i  (wbs_adr_i  ),
        .wbs_ack_o  (wbs_ack_o  ),
        .wbs_dat_o  (wbs_dat_o  ),
        // CSRs
        // Write Only
        .mac_addr   (mac_addr   ),
        .ip_addr    (ip_addr    ),
        .port       (port       ),
        .offload_csr(offload_csr),
        // Read Only
        // Ethernet
        .src_mac    (rx_src_mac ),
        .rx_ethernet_len_type    (rx_ethernet_len_type   ),
        // IPv4
        .src_ip     (rx_src_ip  ),
        .rx_ipv4_version    (rx_ipv4_version    ),
        .rx_ipv4_header_len (rx_ipv4_header_len ),
        .rx_ipv4_tos        (rx_ipv4_tos        ),
        .rx_ipv4_total_len  (rx_ipv4_total_len  ),
        .rx_ipv4_id         (rx_ipv4_id         ),
        .rx_ipv4_flag_frag  (rx_ipv4_flag_frag  ),
        .rx_ipv4_ttl        (rx_ipv4_ttl        ),
        .rx_ipv4_protocol   (rx_ipv4_protocol   ),
        .rx_ipv4_checksum   (rx_ipv4_checksum   ),
        // UDP
        .src_port   (rx_src_port),
        // RX Memory
        .RX_CLK     (RX_CLK     ),
        .rx_udp_data_v  (rx_udp_data_v  ),
        .rx_udp_data    (rx_udp_data    ),
        .rx_mem_out (rx_mem_out )
    );

    // SMI logic
    // transmit logic
    // receive logic
    wire                rx_ethernet_data_v;
    wire    [OCT-1:0]   rx_ethernet_data;
    wire                rx_ipv4_data_v;
    wire    [OCT-1:0]   rx_ipv4_data;
    wire                rx_udp_data_v;
    wire    [OCT-1:0]   rx_udp_data;

    // receive irq signal
    wire                rx_ethernet_irq;
    wire                rx_ipv4_irq;
    wire                rx_udp_irq;
    assign rx_irq = (&offload_csr[1:0]) ? rx_udp_irq : 
                      offload_csr[0]    ? rx_ipv4_irq 
                                        : rx_ethernet_irq;
    assign rx_data_v = (&offload_csr[1:0]) ? rx_udp_data_v :
                         offload_csr[0]    ? rx_ipv4_data_v
                                           : rx_ethernet_data_v;
    assign rx_data  = (&offload_csr[1:0]) ? rx_udp_data :
                         offload_csr[0]   ? rx_ipv4_data
                                          : rx_ethernet_data;

    rx_ethernet #(
        .OCT    (OCT    ),
        .PRE    (PRE    ),
        .SFD    (SFD    ),
        .IPV4   (IPV4   )
    ) rx_ethernet_inst(
        .rst            (rst        ),
        .mac_addr       (mac_addr   ),
        .rx_ethernet_irq(rx_ethernet_irq   ),
        .rx_src_mac     (rx_src_mac ),
        .rx_len_type    (rx_ethernet_len_type   ),
        .RX_CLK         (RX_CLK     ),
        .RX_DV          (RX_DV      ),
        .RXD            (RXD        ),
        .RX_ER          (RX_ER      ),
        .rx_ethernet_data_v (rx_ethernet_data_v ),
        .rx_ethernet_data   (rx_ethernet_data   )
    );

    // IPv4
    rx_ipv4     rx_ipv4_inst(
        .rst            (rst            ),
        .func_en        (offload_csr[0] ),
        .ip_addr        (ip_addr        ),
        .rx_src_ip      (rx_src_ip      ),
        .rx_version     (rx_ipv4_version    ),
        .rx_header_len  (rx_ipv4_header_len ),
        .rx_tos         (rx_ipv4_tos        ),
        .rx_total_len   (rx_ipv4_total_len  ),
        .rx_id          (rx_ipv4_id         ),
        .rx_flag_frag   (rx_ipv4_flag_frag  ),
        .rx_ttl         (rx_ipv4_ttl        ),
        .rx_protocol    (rx_ipv4_protocol   ),
        .rx_checksum    (rx_ipv4_checksum   ),
        .rx_ethernet_irq(rx_ethernet_irq),
        .rx_ipv4_irq    (rx_ipv4_irq    ),
        .RX_CLK         (RX_CLK         ),
        .rx_ethernet_data_v (rx_ethernet_data_v ),
        .rx_ethernet_data   (rx_ethernet_data   ),
        .rx_ipv4_data_v (rx_ipv4_data_v ),
        .rx_ipv4_data   (rx_ipv4_data   )
    );

    // UDP
    rx_udp      rx_udp_inst(
        .rst            (rst            ),
        .func_en        (&offload_csr[1:0]),
        .port           (port           ),
        .rx_src_port    (rx_src_port    ),
        .rx_ipv4_irq    (rx_ipv4_irq    ),
        .rx_udp_irq     (rx_udp_irq     ),
        .RX_CLK         (RX_CLK         ),
        .rx_ipv4_data_v (rx_ipv4_data_v ),
        .rx_ipv4_data   (rx_ipv4_data   ),
        .rx_udp_data_v  (rx_udp_data_v  ),
        .rx_udp_data    (rx_udp_data    )
    );

endmodule
`default_nettype wire
