`default_nettype none
module rx_udp #(
    parameter   OCT = 8
)(
    input   wire                rst,
    input   wire                func_en,
    input   wire    [OCT*2-1:0] port,
    output  reg     [OCT*2-1:0] rx_src_port,
    input   wire                rx_ipv4_irq,
    output  reg                 rx_udp_irq,

    input   wire                RX_CLK,
    input   wire                rx_ipv4_data_v,
    input   wire    [OCT-1:0]   rx_ipv4_data,

    output  reg                 rx_udp_data_v,
    output  reg     [OCT-1:0]   rx_udp_data
);

    parameter SRC_PORT = 3'b000;
    parameter DST_PORT = 3'b001;
    parameter DATA_LEN = 3'b011;
    parameter CHECKSUM = 3'b111;
    parameter UDP_DATA = 3'b110;

    reg [OCT*2-1:0] data_cnt;

    reg [2:0]   rx_state;

    reg [OCT*2-1:0] rx_dst_port;
    reg [OCT*2-1:0] rx_data_len;
    reg [OCT*2-1:0] rx_checksum;

    always @(posedge RX_CLK) begin
        if(rst) begin
            data_cnt    <= 16'h0000;
            rx_udp_data_v   <= 1'b0;
            rx_udp_irq  <= 1'b0;
        end else if (func_en) begin
            rx_udp_irq  <= rx_ipv4_irq;
            if(rx_ipv4_data_v) begin
                case(rx_state)
                    SRC_PORT : begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= DST_PORT;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= SRC_PORT;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_src_port <= {rx_src_port[OCT-1:0], rx_ipv4_data};
                    end
                    DST_PORT : begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= DATA_LEN;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= DST_PORT;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_dst_port <= {rx_dst_port[OCT-1:0], rx_ipv4_data};
                    end
                    DATA_LEN : begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= CHECKSUM;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_state    <= DATA_LEN;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_data_len <= {rx_data_len[OCT-1:0], rx_ipv4_data};
                    end
                    CHECKSUM : begin
                        if(data_cnt == 16'h0001) begin
                            rx_state    <= UDP_DATA;
                            data_cnt    <= 16'h0008;
                        end else begin
                            rx_state    <= CHECKSUM;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_checksum <= {rx_checksum[OCT-1:0], rx_ipv4_data};
                    end
                    UDP_DATA : begin
                        if(data_cnt == rx_data_len) begin
                            rx_udp_data_v   <= 1'b0;
                            data_cnt    <= 16'h0000;
                        end else begin
                            rx_udp_data_v   <= 1'b1;
                            data_cnt    <= data_cnt + 16'h0001;
                        end
                        rx_udp_data     <= rx_ipv4_data;
                    end
                endcase
            end else begin
                rx_state        <= SRC_PORT;
                rx_udp_data_v   <= 1'b0;
                data_cnt        <= 16'h0000;
            end
        end
    end
endmodule
`default_nettype wire
