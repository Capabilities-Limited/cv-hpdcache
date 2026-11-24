/*
 *  Copyright 2026 Capabilities Limited
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 */
/*
 *  Description   : Simulation-only random fault injection into the memory array of the
 *                  behavioral ECC SRAM models. It is only compiled when HPDCACHE_FAULT_INJ is
 *                  defined, and it is disabled unless enabled at run time with plusargs:
 *
 *                  +hpdcache_fi_rate=N    on average, inject one fault every N clock cycles in
 *                                         each ECC SRAM (0, the default, disables injection)
 *                  +hpdcache_fi_double=1  flip two bits of the same codeword (detected,
 *                                         uncorrectable error) instead of one (corrected error)
 *                  +hpdcache_fi_report    print, for each SRAM, the number of faults injected and
 *                                         the number of reads that returned a corrected or an
 *                                         uncorrectable error (cumulative counts, printed when a
 *                                         reset is asserted if they changed, and at the end of
 *                                         the simulation)
 *
 *                  Faults are only injected in cycles where the SRAM is not accessed.
 *
 *                  The including module provides:
 *                  - FI_ENTRY_BITS    : width of an entry of the memory array
 *                  - FI_NCW           : number of codewords per entry
 *                  - FI_CW_BITS       : number of bits per codeword
 *                  - fi_bit_pos(cw, c): position in the entry of bit c of codeword cw
 *                  - the err_cor_o/err_unc_o outputs, valid the cycle after a read
 *                  - a child instance i_sram with the memory array mem[DEPTH]
 *
 *                  This file is included in the body of each of these modules (no include
 *                  guard).
 */

    int unsigned fi_rate = 0;
    int unsigned fi_double = 0;
    int unsigned fi_count = 0;
    int unsigned fi_rd_cor = 0;
    int unsigned fi_rd_unc = 0;
    logic        fi_rd_q = 1'b0;
    logic        fi_rst_q = 1'b0;
    int unsigned fi_reported = 0;
    bit          fi_report = 1'b0;

    initial begin : fi_plusargs
        void'($value$plusargs("hpdcache_fi_rate=%d", fi_rate));
        void'($value$plusargs("hpdcache_fi_double=%d", fi_double));
        fi_report = $test$plusargs("hpdcache_fi_report");
    end

    always @(posedge clk) begin : fi_inject
        int unsigned              fi_idx, fi_cw, fi_c1, fi_c2;
        logic [FI_ENTRY_BITS-1:0] fi_mask;

        if ((rst_n === 1'b1) && !cs && (fi_rate != 0) && (($urandom % fi_rate) == 0)) begin
            fi_idx  = $urandom % DEPTH;
            fi_cw   = $urandom % FI_NCW;
            fi_c1   = $urandom % FI_CW_BITS;
            fi_mask = '0;
            fi_mask[fi_bit_pos(fi_cw, fi_c1)] = 1'b1;
            if (fi_double != 0) begin
                fi_c2 = (fi_c1 + 1 + ($urandom % (FI_CW_BITS - 1))) % FI_CW_BITS;
                fi_mask[fi_bit_pos(fi_cw, fi_c2)] = 1'b1;
            end
            i_sram.mem[fi_idx] <= i_sram.mem[fi_idx] ^ fi_mask;
            fi_count++;
        end
    end

    //  count the reads that returned an error (error outputs are valid the cycle after a read)
    always @(posedge clk) begin : fi_count_errors
        if (fi_rd_q) begin
            if (|err_unc_o) fi_rd_unc++;
            else if (|err_cor_o) fi_rd_cor++;
        end
        fi_rd_q <= (rst_n === 1'b1) && cs && !we;
    end

    //  report the counts when a reset is asserted (e.g. between tests), if they changed
    always @(posedge clk) begin : fi_report_on_reset
        fi_rst_q <= (rst_n === 1'b1);
        if (fi_report && fi_rst_q && (rst_n !== 1'b1) &&
            (fi_reported != (fi_count + fi_rd_cor + fi_rd_unc)))
        begin
            $display("%m: %0d fault(s) injected, %0d corrected read(s), %0d uncorrectable read(s)",
                     fi_count, fi_rd_cor, fi_rd_unc);
            fi_reported = fi_count + fi_rd_cor + fi_rd_unc;
        end
    end

    final begin
        if (fi_report && ((fi_count != 0) || (fi_rd_cor != 0) || (fi_rd_unc != 0))) begin
            $display("%m: %0d fault(s) injected, %0d corrected read(s), %0d uncorrectable read(s)",
                     fi_count, fi_rd_cor, fi_rd_unc);
        end
    end

// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
