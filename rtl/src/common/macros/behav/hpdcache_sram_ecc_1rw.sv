/*
 *  Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : December, 2025
 *  Description   : SRAM behavioral model with ECC. Data widths with a Hsiao code in
 *                  prim_secded (29, 32, 48, 64) use it; other widths use a generic extended
 *                  Hamming SECDED code (see hpdcache_secded_hamming.svh).
 *  History       :
 */
`include "prim_secded_inc.svh"

module hpdcache_sram_ecc_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            cs,
    input  logic                            we,
    input  logic [ADDR_SIZE-1:0]            addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] wdata,
    output logic [NDATA-1:0][DATA_SIZE-1:0] rdata,

    input  logic                            err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0] err_inj_msk_i,
    output logic [NDATA-1:0]                err_cor_o,
    output logic [NDATA-1:0]                err_unc_o
);
    localparam bit          NATIVE_WIDTH = prim_secded_pkg::is_width_valid(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE);

    //  Generic SECDED code, for widths without a Hsiao code
    localparam int unsigned HAM_K = DATA_SIZE;
`include "hpdcache_secded_hamming.svh"

    localparam int unsigned SYND_WIDTH = NATIVE_WIDTH ? prim_secded_pkg::get_synd_width(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE) : HAM_R + 1;
    localparam int unsigned WORD_WIDTH = NATIVE_WIDTH ? prim_secded_pkg::get_full_width(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE) : HAM_CW_SIZE;

    logic [NDATA-1:0][WORD_WIDTH-1:0] wdata_ecc, rdata_ecc;
    logic [NDATA-1:0][SYND_WIDTH-1:0] syndr_ecc;
    logic [NDATA-1:0][1:0] err;

    hpdcache_sram_1rw #(
        .ADDR_SIZE (ADDR_SIZE),
        .DATA_SIZE (WORD_WIDTH),
        .DEPTH     (DEPTH),
        .NDATA     (NDATA)
    ) i_sram(
        .clk,
        .rst_n,
        .cs,
        .we,
        .addr,
        .wdata (wdata_ecc),
        .rdata (rdata_ecc)
    );

    for (genvar i = 0; i < NDATA; i++) begin : gen_ecc_enc_dec
        if (NATIVE_WIDTH) begin : gen_hsiao
            `SECDED_INST_ENC(prim_secded_pkg::SecdedHsiao,
                DATA_SIZE,
                ecc_enc,
                wdata[i],
                wdata_ecc[i])

            `SECDED_INST_DEC(prim_secded_pkg::SecdedHsiao,
                DATA_SIZE,
                ecc_dec,
                rdata_ecc[i],
                rdata[i],
                syndr_ecc[i],
                err[i])
        end else begin : gen_hamming
            ham_cw_t rcw_corrected;
            logic    cor, unc;

            assign wdata_ecc[i] = ham_encode(wdata[i]);

            always_comb
            begin : ham_decode_comb
                rcw_corrected = ham_correct(rdata_ecc[i], cor, unc);
            end

            assign rdata[i] = ham_extract(rcw_corrected);
            assign syndr_ecc[i] = '0;
            assign err[i] = {unc, cor};
        end

        assign err_cor_o[i] = err[i][0];
        assign err_unc_o[i] = err[i][1];
    end

    //  Simulation-only fault injection (see hpdcache_sram_fault_inj.svh)
    //  {{{
`ifdef HPDCACHE_FAULT_INJ
    localparam int unsigned FI_ENTRY_BITS = NDATA*WORD_WIDTH;
    localparam int unsigned FI_NCW = NDATA;
    localparam int unsigned FI_CW_BITS = WORD_WIDTH;

    function automatic int unsigned fi_bit_pos(int unsigned cw, int unsigned c);
        return cw*WORD_WIDTH + c;
    endfunction

`include "hpdcache_sram_fault_inj.svh"
`endif
    //  }}}

endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
