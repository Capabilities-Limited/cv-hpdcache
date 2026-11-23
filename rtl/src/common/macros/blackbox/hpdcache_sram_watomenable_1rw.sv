/*
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Description   : Blackbox model of a 1RW SRAM with write atom enable
 */
(* black_box *) module hpdcache_sram_watomenable_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned ATOM_SIZE = DATA_SIZE >= 8 ? 8 : DATA_SIZE
)
(
    input  logic                                         clk,
    input  logic                                         rst_n,
    input  logic                                         cs,
    input  logic                                         we,
    input  logic [ADDR_SIZE-1:0]                         addr,
    input  logic [DATA_SIZE-1:0]                         wdata,
    input  logic [(DATA_SIZE+ATOM_SIZE-1)/ATOM_SIZE-1:0] watomenable,
    output logic [DATA_SIZE-1:0]                         rdata
);

endmodule
