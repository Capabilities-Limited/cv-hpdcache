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

    //  Definition of constants
    //  {{{
    //      Number of Hamming check bits: smallest R such that 2**R >= ATOM_SIZE + R + 1
    function automatic int unsigned get_hamming_bits(int unsigned k);
        int unsigned r;
        r = 1;
        while ((1 << r) < (k + r + 1)) r++;
        return r;
    endfunction

    localparam int unsigned K = ATOM_SIZE;
    localparam int unsigned R = get_hamming_bits(K);
    localparam int unsigned N = K + R;
    localparam int unsigned CW_SIZE = N + 1;
    localparam int unsigned PAD_SIZE = NATOMS*ATOM_SIZE;

    typedef logic [K-1:0]       atom_t;
    typedef logic [CW_SIZE-1:0] codeword_t;
    //  }}}

    //  SECDED encoder/decoder
    //  {{{
    function automatic codeword_t secded_encode(atom_t d);
        codeword_t c;
        int unsigned di;
        logic par;

        c = '0;
        di = 0;
        for (int unsigned pos = 1; pos <= N; pos++) begin
            if ((pos & (pos - 1)) != 0) begin
                c[pos] = d[di];
                di++;
            end
        end
        for (int unsigned j = 0; j < R; j++) begin
            par = 1'b0;
            for (int unsigned pos = 1; pos <= N; pos++) begin
                if ((((pos >> j) & 1) != 0) && (pos != (1 << j))) begin
                    par ^= c[pos];
                end
            end
            c[1 << j] = par;
        end
        c[0] = ^c[N:1];
        return c;
    endfunction

    function automatic atom_t secded_extract(codeword_t c);
        atom_t d;
        int unsigned di;

        d = '0;
        di = 0;
        for (int unsigned pos = 1; pos <= N; pos++) begin
            if ((pos & (pos - 1)) != 0) begin
                d[di] = c[pos];
                di++;
            end
        end
        return d;
    endfunction

    //  Returns the corrected codeword. cor is set when a single error was corrected, unc when
    //  an uncorrectable (double) error was detected.
    function automatic codeword_t secded_correct(codeword_t c, output logic cor,
                                                 output logic unc);
        int unsigned synd;
        logic b, par;
        codeword_t ret;

        synd = 0;
        for (int unsigned j = 0; j < R; j++) begin
            b = 1'b0;
            for (int unsigned pos = 1; pos <= N; pos++) begin
                if (((pos >> j) & 1) != 0) b ^= c[pos];
            end
            if (b) synd |= (1 << j);
        end
        par = ^c;

        ret = c;
        cor = 1'b0;
        unc = 1'b0;
        if (par) begin
            //  odd number of flipped bits: assume a single error
            if (synd == 0) begin
                //  error in the overall parity bit
                ret[0] = ~ret[0];
                cor = 1'b1;
            end else if (synd <= N) begin
                ret[synd] = ~ret[synd];
                cor = 1'b1;
            end else begin
                //  syndrome points outside of the codeword
                unc = 1'b1;
            end
        end else if (synd != 0) begin
            //  even number of flipped bits (and not zero): double error
            unc = 1'b1;
        end
        return ret;
    endfunction
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

        assign wdata_sram[i] = secded_encode(wdata_pad[i*ATOM_SIZE +: ATOM_SIZE]);

        always_comb
        begin : atom_decode_comb
            rcw_corrected = secded_correct(rdata_sram[i], cor, unc);
        end

        assign rdata_pad[i*ATOM_SIZE +: ATOM_SIZE] = secded_extract(rcw_corrected);
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
