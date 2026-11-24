/*
 *  Copyright 2026 Capabilities Limited
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Description   : Generic SECDED (single error correction, double error detection) extended
 *                  Hamming code of HAM_K data bits, for the behavioral ECC SRAM models. It is
 *                  used for data widths without a Hsiao code in prim_secded (e.g. the 1-bit user
 *                  bits or tags, or directory entries of arbitrary width).
 *
 *                  The including module defines the localparam HAM_K (number of data bits). This
 *                  file defines:
 *                  - HAM_R (Hamming check bits), HAM_N (= HAM_K + HAM_R), and HAM_CW_SIZE
 *                    (= HAM_N + 1, codeword width)
 *                  - the types ham_data_t and ham_cw_t
 *                  - ham_encode(d): codeword of the data d
 *                  - ham_correct(c, cor, unc): corrected codeword (cor: a single error was
 *                    corrected, unc: an uncorrectable error was detected)
 *                  - ham_extract(c): data bits of the codeword c
 *
 *                  Codeword layout (HAM_CW_SIZE bits):
 *                    bit 0         : overall parity
 *                    bits 1..HAM_N : Hamming code positions 1..HAM_N. Check bits are at the
 *                                    power-of-two positions; data bits fill the other
 *                                    positions, in order.
 *
 *                  This file is included in the body of each of these modules (no include
 *                  guard).
 */

    //      Number of Hamming check bits: smallest R such that 2**R >= HAM_K + R + 1
    function automatic int unsigned ham_get_check_bits(int unsigned k);
        int unsigned r;
        r = 1;
        while ((1 << r) < (k + r + 1)) r++;
        return r;
    endfunction

    localparam int unsigned HAM_R = ham_get_check_bits(HAM_K);
    localparam int unsigned HAM_N = HAM_K + HAM_R;
    localparam int unsigned HAM_CW_SIZE = HAM_N + 1;

    typedef logic [HAM_K-1:0]       ham_data_t;
    typedef logic [HAM_CW_SIZE-1:0] ham_cw_t;

    function automatic ham_cw_t ham_encode(ham_data_t d);
        ham_cw_t     c;
        int unsigned di;
        logic        par;

        c = '0;
        di = 0;
        for (int unsigned pos = 1; pos <= HAM_N; pos++) begin
            if ((pos & (pos - 1)) != 0) begin
                c[pos] = d[di];
                di++;
            end
        end
        for (int unsigned j = 0; j < HAM_R; j++) begin
            par = 1'b0;
            for (int unsigned pos = 1; pos <= HAM_N; pos++) begin
                if ((((pos >> j) & 1) != 0) && (pos != (1 << j))) begin
                    par ^= c[pos];
                end
            end
            c[1 << j] = par;
        end
        c[0] = ^c[HAM_N:1];
        return c;
    endfunction

    function automatic ham_data_t ham_extract(ham_cw_t c);
        ham_data_t   d;
        int unsigned di;

        d = '0;
        di = 0;
        for (int unsigned pos = 1; pos <= HAM_N; pos++) begin
            if ((pos & (pos - 1)) != 0) begin
                d[di] = c[pos];
                di++;
            end
        end
        return d;
    endfunction

    function automatic ham_cw_t ham_correct(ham_cw_t c, output logic cor, output logic unc);
        int unsigned synd;
        logic        b, par;
        ham_cw_t     ret;

        synd = 0;
        for (int unsigned j = 0; j < HAM_R; j++) begin
            b = 1'b0;
            for (int unsigned pos = 1; pos <= HAM_N; pos++) begin
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
            end else if (synd <= HAM_N) begin
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

// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
