/*
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Description   : Blackbox model of a 1RW SRAM with write atom enable and ECC.
 *                  Each atom of ATOM_SIZE bits is protected independently (see the behavioral
 *                  model for the reference SECDED code). err_cor_o/err_unc_o report, per atom,
 *                  a corrected or an uncorrectable error on the data read in the previous access.
 */
(* black_box *) module hpdcache_sram_watomenable_ecc_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned ATOM_SIZE = DATA_SIZE >= 8 ? 8 : DATA_SIZE,
    localparam int unsigned NATOMS = (DATA_SIZE + ATOM_SIZE - 1)/ATOM_SIZE
)
(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         cs,
    input  logic                         we,
    input  logic [ADDR_SIZE-1:0]         addr,
    input  logic [DATA_SIZE-1:0]         wdata,
    input  logic [NATOMS-1:0]            watomenable,
    output logic [DATA_SIZE-1:0]         rdata,

    input  logic                         err_inj_i,
    input  logic [DATA_SIZE-1:0]         err_inj_msk_i,
    output logic [NATOMS-1:0]            err_cor_o,
    output logic [NATOMS-1:0]            err_unc_o
);

endmodule
