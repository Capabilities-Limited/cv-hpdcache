/*
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Description   : Behavioral model of a 1RW SRAM with write atom enable and ECC.
 *
 *                  Each atom (ATOM_SIZE bits) is protected by its own SECDED (single error
 *                  correction, double error detection) extended Hamming code. Atoms are always
 *                  written as a whole (data and check bits), so partial writes at atom
 *                  granularity do not need a read-modify-write.
 *
 *                  This is intended for small atoms (e.g. the per-word user bits / CHERI tags),
 *                  for which the Hsiao codes of prim_secded are not available. For a 1-bit atom
 *                  the code uses 3 check bits.
 *
 *                  Codeword layout of an atom (CW_SIZE bits):
 *                    bit 0         : overall parity
 *                    bits 1..N     : Hamming code positions 1..N. Check bits are at the
 *                                    power-of-two positions; data bits fill the other
 *                                    positions, in order.
 */
module hpdcache_sram_watomenable_ecc_1rw
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

    //  SECDED code of each atom (see hpdcache_secded_hamming.svh)
    //  {{{
    localparam int unsigned HAM_K = ATOM_SIZE;
`include "hpdcache_secded_hamming.svh"

    localparam int unsigned CW_SIZE = HAM_CW_SIZE;
    localparam int unsigned PAD_SIZE = NATOMS*ATOM_SIZE;

    typedef ham_cw_t codeword_t;
    //  }}}

    //  Memory array
    //  {{{
    logic [PAD_SIZE-1:0]               wdata_pad, rdata_pad;
    logic [NATOMS-1:0][CW_SIZE-1:0]    wdata_sram, rdata_sram;

    hpdcache_sram_watomenable_1rw #(
        .ADDR_SIZE (ADDR_SIZE),
        .DATA_SIZE (NATOMS*CW_SIZE),
        .DEPTH     (DEPTH),
        .ATOM_SIZE (CW_SIZE)
    ) i_sram(
        .clk,
        .rst_n,
        .cs,
        .we,
        .addr,
        .wdata       (wdata_sram),
        .watomenable (watomenable),
        .rdata       (rdata_sram)
    );
    //  }}}

    //  Encoding/decoding of each atom
    //  {{{
    assign wdata_pad = PAD_SIZE'(wdata);

    for (genvar i = 0; i < NATOMS; i++) begin : gen_atom_ecc
        codeword_t rcw_corrected;
        logic      cor, unc;

        assign wdata_sram[i] = ham_encode(wdata_pad[i*ATOM_SIZE +: ATOM_SIZE]);

        always_comb
        begin : atom_decode_comb
            rcw_corrected = ham_correct(rdata_sram[i], cor, unc);
        end

        assign rdata_pad[i*ATOM_SIZE +: ATOM_SIZE] = ham_extract(rcw_corrected);
        assign err_cor_o[i] = cor;
        assign err_unc_o[i] = unc;
    end

    assign rdata = rdata_pad[DATA_SIZE-1:0];

    //  The error injection interface is not used by this model (faults are injected by the
    //  testbench directly in the memory array)
    logic _unused_err_inj;
    assign _unused_err_inj = 1'b0 && (err_inj_i & |err_inj_msk_i);
    //  }}}

    //  Simulation-only fault injection (see hpdcache_sram_fault_inj.svh)
    //  {{{
`ifdef HPDCACHE_FAULT_INJ
    localparam int unsigned FI_ENTRY_BITS = NATOMS*CW_SIZE;
    localparam int unsigned FI_NCW = NATOMS;
    localparam int unsigned FI_CW_BITS = CW_SIZE;

    function automatic int unsigned fi_bit_pos(int unsigned cw, int unsigned c);
        return cw*CW_SIZE + c;
    endfunction

`include "hpdcache_sram_fault_inj.svh"
`endif
    //  }}}

endmodule : hpdcache_sram_watomenable_ecc_1rw
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
