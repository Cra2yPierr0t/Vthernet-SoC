`default_nettype none
module rx_ipv4 #(
    parameter   OCT = 8,
    parameter   UDP = 8'h11
)(
    input   wire                rst,
    input   wire                func_en,
    input   wire    [OCT*4-1:0] ip_addr,
    output  reg     [OCT*4-1:0] rx_src_ip,
    output  reg     [3:0]       rx_version,
    output  reg     [3:0]       rx_header_len,
    output  reg     [OCT-1:0]   rx_tos,
    output  reg     [OCT*2-1:0] rx_total_len,
    output  reg     [OCT-1:0]   rx_id,
    output  reg     [OCT*2-1:0] rx_flag_frag,
    output  reg     [OCT-1:0]   rx_ttl,
    output  reg     [OCT-1:0]   rx_protocol,
    output  reg     [OCT-1:0]   rx_checksum,
    input   wire                rx_ethernet_irq,
    output  reg                 rx_ipv4_irq,

    input   wire                RX_CLK,
    input   wire                rx_ethernet_data_v,
    input   wire    [OCT-1:0]   rx_ethernet_data,

    output  reg                 rx_ipv4_data_v,
    output  reg     [OCT-1:0]   rx_ipv4_data
);

    parameter RX_IHL_VER    = 8'b00000000;
    parameter RX_TOS        = 8'b00000001;
    parameter RX_TOTAL_LEN  = 8'b00000011;
    parameter RX_ID         = 8'b00000111;
    parameter RX_FLAG_FRAG  = 8'b00001111;
    parameter RX_TTL        = 8'b00011110;
    parameter RX_PROTOCOL   = 8'b00111110;
    parameter RX_CHECKSUM   = 8'b00111100;
    parameter RX_SRC_IP     = 8'b00011100;
    parameter RX_DST_IP     = 8'b00001100;
    parameter RX_DATA       = 8'b00000100;

    reg [OCT-1:0]   rx_state;

    reg [OCT*4-1:0] rx_dst_ip;
    //reg [OCT*36-1:0] rx_option;
    
    reg [OCT-1:0]   data_cnt;

    always @(posedge RX_CLK) begin 
        if(rst) begin
            rx_state    <= RX_IHL_VER;
            data_cnt    <= 16'h0000;
            rx_ipv4_irq <= 1'b0;
        end else if(func_en) begin
            rx_ipv4_irq <= rx_ethernet_irq;
            if(rx_ethernet_data_v) begin
                case(rx_state)
                    RX_IHL_VER  : begin
                        rx_state    <= RX_TOS;
                        {rx_version, rx_header_len} <= rx_ethernet_data;
                    end
                    RX_TOS      : begin
                        rx_state    <= RX_TOTAL_LEN;
                        rx_tos      <= rx_ethernet_data;
                    end
                    RX_TOTAL_LEN: begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= RX_ID;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= RX_TOTAL_LEN;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_total_len <= {rx_total_len[OCT-1:0], rx_ethernet_data};
                    end
                    RX_ID       : begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= RX_FLAG_FRAG;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= RX_ID;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_id <= {rx_id[OCT-1:0], rx_ethernet_data};
                    end
                    RX_FLAG_FRAG: begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= RX_TTL;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= RX_FLAG_FRAG;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_flag_frag <= {rx_flag_frag[OCT-1:0], rx_ethernet_data};
                    end
                    RX_TTL      : begin
                        rx_state    <= RX_PROTOCOL;
                        rx_ttl      <= rx_ethernet_data;
                    end
                    RX_PROTOCOL : begin
                        rx_state    <= RX_CHECKSUM;
                        rx_protocol <= rx_ethernet_data;
                    end
                    RX_CHECKSUM : begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= RX_SRC_IP;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= RX_CHECKSUM;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_checksum <= {rx_checksum[OCT-1:0], rx_ethernet_data};
                    end
                    RX_SRC_IP   : begin
                        if(data_cnt == 16'h0003) begin
                            rx_state    <= RX_DST_IP;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= RX_SRC_IP;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_src_ip <= {rx_src_ip[OCT*3-1:0], rx_ethernet_data};
                    end
                    RX_DST_IP   : begin
                        if(data_cnt == 16'h0003) begin
                            rx_state    <= RX_DATA;
                            // for total len cnt
                            data_cnt    <= {10'b00_0000_0000, rx_header_len, 2'b00};
                        end else begin
                            rx_state    <= RX_DST_IP;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_dst_ip <= {rx_dst_ip[OCT*3-1:0], rx_ethernet_data};
                    end
                    RX_DATA     : begin
                        rx_ipv4_data <= rx_ethernet_data;
                        // count data lenght
                        case(rx_protocol)
                            UDP : begin
                                rx_ipv4_data_v <= 1'b1;
                            end
                            default : begin
                                rx_ipv4_data_v <= 1'b0;
                            end
                        endcase
                    end
                    default : begin
                        rx_ipv4_data_v <= 1'b0;
                    end
                endcase
            end else begin
                rx_ipv4_data_v <= 1'b0;
            end
        end
    end
endmodule
`default_nettype wire
