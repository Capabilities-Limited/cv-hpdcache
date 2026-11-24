/*
 *  Copyright 2023 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : December, 2025
 *  Description   : Behavioral model of a 1RW SRAM with write byte enable and ECC
 *  History       :
 */
`include "prim_secded_inc.svh"

module hpdcache_sram_wbyteenable_ecc_1rw
    import prim_secded_pkg::*;
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned ATOM_SIZE = DATA_SIZE >= 8 ? 8 : DATA_SIZE,
    parameter int unsigned NDATA = 1
)
(
    input  logic                                                    clk,
    input  logic                                                    rst_n,
    input  logic                                                    cs,
    input  logic                                                    we,
    input  logic [ADDR_SIZE-1:0]                                    addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]                         wdata,
    input  logic [NDATA-1:0][(DATA_SIZE+ATOM_SIZE-1)/ATOM_SIZE-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]                         rdata,

    input  logic                                                    err_inj_i,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]                         err_inj_msk_i,
    output logic [NDATA-1:0]                                        err_cor_o,
    output logic [NDATA-1:0]                                        err_unc_o
);

    //  Data words of a width supported by the SECDED codes (29/32/48/64) are protected by a
    //  single code. Wider words (multiple of 64 bits, e.g. 128-bit CHERI capabilities) are split
    //  in 64-bit chunks, each protected by its own (72,64) code: a single-bit error per chunk is
    //  corrected, and a double-bit error in a chunk is detected.
    //
    //  SRAM word layout: {chunk[NCHUNKS-1] check bits, ..., chunk[0] check bits, data}. With a
    //  single chunk, this is the layout of the (DATA_SIZE + SYND_WIDTH, DATA_SIZE) codeword.
    localparam bit          NATIVE_WIDTH = prim_secded_pkg::is_width_valid(
        prim_secded_pkg::SecdedHsiao, DATA_SIZE);
    localparam int unsigned CHUNK_SIZE = NATIVE_WIDTH ? DATA_SIZE : 64;
    localparam int unsigned NCHUNKS = DATA_SIZE / CHUNK_SIZE;
    localparam int unsigned SYND_WIDTH = prim_secded_pkg::get_synd_width(
        prim_secded_pkg::SecdedHsiao, CHUNK_SIZE);
    localparam int unsigned CHUNK_CW_WIDTH = CHUNK_SIZE + SYND_WIDTH;
    localparam int unsigned WORD_WIDTH = DATA_SIZE + NCHUNKS*SYND_WIDTH;
    localparam int unsigned WORD_BYTES = (WORD_WIDTH + 7)/8;

    //  Width of the encoded data is not necessarily a multiple of 8
    logic [NDATA-1:0][WORD_WIDTH-1:0] wdata_enc_ecc;

    //  Width of the SRAM's data is a multiple of 8 bits
    logic [NDATA-1:0][WORD_BYTES*8-1:0] wdata_sram;
    logic [NDATA-1:0][WORD_BYTES*8-1:0] rdata_sram;
    logic [NDATA-1:0][WORD_BYTES-1:0] wbyte_sram;

    logic [NDATA-1:0][NCHUNKS-1:0][SYND_WIDTH-1:0] syndr_ecc;
    logic [NDATA-1:0][NCHUNKS-1:0] err_cor, err_unc;

    hpdcache_sram_wbyteenable_1rw #(
        .ADDR_SIZE (ADDR_SIZE),
        .DATA_SIZE (WORD_BYTES*8),
        .DEPTH     (DEPTH),
        .ATOM_SIZE (ATOM_SIZE),
        .NDATA     (NDATA)
    ) i_sram(
        .clk,
        .rst_n,
        .cs,
        .we,
        .addr,
        .wdata       (wdata_sram),
        .wbyteenable (wbyte_sram),
        .rdata       (rdata_sram)
    );

    // XXX TODO ECC code has not been adapted to handle parameterisable ATOM_SIZE
    for (genvar i = 0; i < NDATA; i++) begin : gen_ecc_enc_dec
        for (genvar j = 0; j < WORD_BYTES; j++) begin : gen_ecc_wbyteenable
            if (j < DATA_SIZE/8) begin : gen_ecc_data_wbyteenable
                //  Data bits are written according to the byte-enable signal
                assign wbyte_sram[i][j] = wbyteenable[i][j];
            end else if (NCHUNKS == 1) begin : gen_ecc_check_wbyteenable
                //  Check bits byte are written if the last byte of the word is modified
                //  When using ECC, all the bytes of word need to be written to correctly compute
                //  the check bits. Hence, we can arbitrarily take a byte-enable for the check bits
                assign wbyte_sram[i][j] = wbyteenable[i][(DATA_SIZE/8) - 1];
            end else begin : gen_ecc_chunk_check_wbyteenable
                //  With 64-bit chunks, each check bits byte belongs to one chunk: it is written
                //  if the last byte of that chunk is modified
                assign wbyte_sram[i][j] =
                    wbyteenable[i][(j - DATA_SIZE/8 + 1)*(CHUNK_SIZE/8) - 1];
            end
        end

        for (genvar k = 0; k < NCHUNKS; k++) begin : gen_ecc_chunk
            logic [CHUNK_CW_WIDTH-1:0] chunk_enc, chunk_rd;

            `SECDED_INST_ENC(prim_secded_pkg::SecdedHsiao,
                CHUNK_SIZE,
                ecc_enc,
                wdata[i][k*CHUNK_SIZE +: CHUNK_SIZE],
                chunk_enc)

            assign wdata_enc_ecc[i][k*CHUNK_SIZE +: CHUNK_SIZE] = chunk_enc[CHUNK_SIZE-1:0];
            assign wdata_enc_ecc[i][DATA_SIZE + k*SYND_WIDTH +: SYND_WIDTH] =
                chunk_enc[CHUNK_CW_WIDTH-1:CHUNK_SIZE];

            assign chunk_rd = {rdata_sram[i][DATA_SIZE + k*SYND_WIDTH +: SYND_WIDTH],
                               rdata_sram[i][k*CHUNK_SIZE +: CHUNK_SIZE]};

            logic [1:0] chunk_err;

            `SECDED_INST_DEC(prim_secded_pkg::SecdedHsiao,
                CHUNK_SIZE,
                ecc_dec,
                chunk_rd,
                rdata[i][k*CHUNK_SIZE +: CHUNK_SIZE],
                syndr_ecc[i][k],
                chunk_err)

            assign err_cor[i][k] = chunk_err[0];
            assign err_unc[i][k] = chunk_err[1];
        end

        //  Complete MSbs with zeros if the data + checks bits is not a multiple of byte
        assign wdata_sram[i] = (WORD_BYTES*8)'(wdata_enc_ecc[i]);

        //  An uncorrectable error in any chunk makes the whole word uncorrectable
        assign err_unc_o[i] = |err_unc[i];
        assign err_cor_o[i] = |err_cor[i] & ~err_unc_o[i];

`ifndef HPDCACHE_ASSERT_OFF
        byteenable_all_set_assert: assert property (@(posedge clk) disable iff (rst_n !== 1'b1)
            ((cs & we) == 1'b1) |-> ((&wbyteenable[i] == 1'b1) || (|wbyteenable[i] == 1'b0))) else
            $warning("partial write (sparse byteenable) not supported when implementing ECC");
`endif
    end

    //  Assertions
    //  {{{
`ifndef HPDCACHE_ASSERT_OFF
    if (!NATIVE_WIDTH && ((DATA_SIZE % 64) != 0)) begin : gen_ecc_valid_width_assertion
        $fatal(1, $sformatf("Unsupported DATA_SIZE = %0d (29/32/48/64 or a multiple of 64)",
            DATA_SIZE));
    end

    if ((DATA_SIZE % 8) != 0) begin : gen_data_width_assertion
        $fatal(1, $sformatf("DATA_SIZE = %0d must be a multiple of 8", DATA_SIZE));
    end

    if (ATOM_SIZE != 8) begin : gen_atom_size_assertion
        $fatal(1, $sformatf("ATOM_SIZE = %0d must be 8", ATOM_SIZE));
    end
`endif
    // }}}

endmodule
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
