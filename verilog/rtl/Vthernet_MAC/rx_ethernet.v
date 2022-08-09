`default_nettype none
module rx_ethernet #(
    parameter OCT   = 8,
    parameter PRE   = 8'b10101010,
    parameter SFD   = 8'b10101011,
    parameter IPV4  = 16'h0800
)(
    input   wire        rst,

    output  reg             rx_ethernet_irq, // if completed receive frame, take interrupt
    // CSRs
    input   wire [OCT*6-1:0] mac_addr,
    output  reg [OCT*6-1:0] rx_src_mac,
    output  reg [OCT*2-1:0] rx_len_type,

    // GMII Receive Interface
    input   wire            RX_CLK,
    input   wire            RX_DV,
    input   wire [OCT-1:0]  RXD,
    input   wire            RX_ER,

    // Interface for Next Layer Logic
    output  reg             rx_ethernet_data_v,
    output  reg [OCT-1:0]   rx_ethernet_data
);

    parameter RX_IDLE       = 3'b000;
    parameter RX_WAIT_SFD   = 3'b001;
    parameter RX_MAC_DST    = 3'b011;
    parameter RX_MAC_SRC    = 3'b111;
    parameter RX_LEN_TYPE   = 3'b110;
    parameter RX_READ_DATA  = 3'b100;
    parameter RX_IRQ        = 3'b101;

    reg [OCT*2-1:0]     data_cnt;
    reg [2:0]           rx_state;
    reg [OCT*6-1:0]     rx_mac_dst;

    reg [1:0] detect_posedge_rx_dv;

    always @(posedge RX_CLK) begin
        if(rst) begin
            rx_state    <= RX_IDLE;
            rx_ethernet_data_v <= 1'b0;
            rx_ethernet_irq <= 1'b0;
            detect_posedge_rx_dv <= 2'b00;
        end else begin
            detect_posedge_rx_dv <= {detect_posedge_rx_dv[0], RX_DV};
            case(rx_state)
                RX_IDLE : begin
                    rx_ethernet_data_v  <= 1'b0;
                    rx_ethernet_irq <= 1'b0;
                    if(detect_posedge_rx_dv == 2'b01) begin
                        rx_state    <= RX_WAIT_SFD;
                    end else begin
                        rx_state    <= RX_IDLE;
                    end
                end
                RX_WAIT_SFD : begin
                    if(RXD == SFD) begin
                        rx_state    <= RX_MAC_DST;
                    end else begin
                        rx_state    <= RX_WAIT_SFD;
                    end
                end
                RX_MAC_DST  : begin
                    if(data_cnt == 8'h05) begin
                        data_cnt    <= 16'h0000;
                        if({rx_mac_dst[OCT*5-1:0], RXD} == mac_addr) begin // check mac addr
                            rx_state    <= RX_MAC_SRC;
                        end else begin // if did not match, return to start
                            rx_state    <= RX_IDLE;
                        end
                    end else begin
                        rx_state    <= RX_MAC_DST;
                        data_cnt    <= data_cnt + 16'h0001;
                    end
                    rx_mac_dst  <= {rx_mac_dst[OCT*5-1:0], RXD};
                end
                RX_MAC_SRC  : begin
                    if(data_cnt == 8'h05) begin
                        rx_state    <= RX_LEN_TYPE;
                        data_cnt    <= 16'h0000;
                    end else begin
                        rx_state    <= RX_MAC_SRC;
                        data_cnt    <= data_cnt + 16'h0001;
                    end
                    rx_src_mac  <= {rx_src_mac[OCT*5-1:0], RXD};
                end
                RX_LEN_TYPE : begin
                    if(data_cnt == 8'h01) begin
                        rx_state    <= RX_READ_DATA;
                        data_cnt    <= 16'h0000;
                    end else begin
                        rx_state    <= RX_LEN_TYPE;
                        data_cnt    <= data_cnt + 16'h0001;
                    end
                    rx_len_type <= {rx_len_type[OCT-1:0], RXD};
                end
                RX_READ_DATA : begin
                    // READ FRAME HEADER
                    case(rx_len_type)
                        IPV4    : begin
                            rx_ethernet_data    <= RXD;
                            if(RX_DV) begin
                                rx_state        <= RX_READ_DATA;
                                rx_ethernet_data_v <= 1'b1;
                            end else begin
                                rx_state        <= RX_IRQ;
                                rx_ethernet_data_v <= 1'b0;
                            end
                        end
                        default : begin
                            rx_state    <= RX_IDLE;
                            if(rx_len_type <= 16'h05DC) begin   // RAW FRAME
                                rx_ethernet_data_v <= 1'b0;
                            end else begin                      // UNKNOWN TYPE
                                rx_ethernet_data_v <= 1'b0;
                            end
                        end
                    endcase
                end
                RX_IRQ : begin
                    rx_state    <= RX_IDLE;
                    rx_ethernet_irq <= 1'b1;
                end
                default : begin
                    rx_state    <= RX_IDLE;
                end
            endcase
        end
    end
endmodule
`default_nettype wire
