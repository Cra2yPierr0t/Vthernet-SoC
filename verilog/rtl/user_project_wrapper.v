// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user project.
 *
 * An example user project is provided in this wrapper.  The
 * example should be removed and replaced with the actual
 * user project.
 *
 *-------------------------------------------------------------
 */

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

    wire            rx_udp_data_vb;
    wire    [7:0]   rx_udp_data;
    wire    [7:0]   rx_mem_out;
    wire    [9:0]   rx_addr;
    wire            wmask0;
    wire            csb1;
    wire    [7:0]   dout0;

    Vthernet_MAC Vthernet_MAC(
    `ifdef USE_POWER_PINS
        .vccd1  (vccd1          ),
        .vssd1  (vssd1          ),
    `endif
        .rst        (wb_rst_i   ),
        // Wishbone interface
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
        // GMII interface
        .GTX_CLK    (io_out[0]  ),
        .TX_EN      (io_out[1]  ),
        .TXD        (io_out[9:2]),
        .TX_ER      (io_out[10] ),
        .RX_CLK     (io_in[11]  ),
        .RX_DV      (io_in[12]  ),
        .RXD        (io_in[20:13]),
        .RX_ER      (io_in[21]  ),
        .MDC        (io_in[22]  ),
        .MDIO       (io_in[23]  ),
        // PicoRV interface
        .rx_irq     (user_irq[0]),
        // Memory Interface
        .rx_udp_data_vb (rx_udp_data_vb ),
        .rx_udp_data    (rx_udp_data    ),
        .rx_mem_out (rx_mem_out ),
        .rx_addr    (rx_addr    ),
        .wmask0     (wmask0     ),
        .csb1       (csb1       ),
        .io_oeb     (io_oeb[23:0]),
        .dout0      (dout0      )
    );

    // write    : when web0 = 0, csb0 = 0
    // read     : when web0 = 1, csb0 = 0, maybe 3 clock delay...?
    // read     : when csb0 = 0, maybe 3 clock delay...?
    sky130_sram_1kbyte_1rw1r_8x1024_8 #(.NUM_WMASKS(2)) rx_mem(
    `ifdef USE_POWER_PINS
        .vccd1  (vccd1          ),
        .vssd1  (vssd1          ),
    `endif
        // RW
        .clk0   (RX_CLK         ), // clock
        .csb0   (rx_udp_data_vb ), // active low chip select
        .web0   (rx_udp_data_vb ), // active low write control
        .wmask0 ({wmask0, wmask0}), // write mask (1 bit)
        .addr0  (rx_addr        ), // addr (10 bit)
        .din0   (rx_udp_data    ), // data in (8 bit)
        .dout0  (dout0          ), // data out (8 bit)
        // R
        .clk1   (wb_clk_i       ), // clock
        .csb1   (csb1           ), // active low chip select
        .addr1  (wbs_adr_i[9:0] ), // addr (10 bit)
        .dout1  (rx_mem_out     )  // data out (8 bit)
    );

endmodule	// user_project_wrapper

`default_nettype wire
