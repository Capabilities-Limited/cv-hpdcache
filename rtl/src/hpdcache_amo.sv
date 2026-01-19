/*
 *  Copyright 2023 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Inria, Universite Grenoble-Alpes, TIMA
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : May, 2021
 *  Description   : HPDcache AMO computing unit
 *  History       :
 */
module hpdcache_amo
import hpdcache_pkg::*;
//  Ports
//  {{{
(
    input  logic [128:0]          ld_data_i,
    input  logic [128:0]          st_data_i,
    input  hpdcache_uc_op_t       op_i,
    output logic [128:0]          result_o
);
//  }}}

    logic signed [63:0] ld_data_signed;
    logic signed [63:0] st_data_signed;
    logic signed [63:0] sum;
    logic        [63:0] ld_data_unsigned;
    logic        [63:0] st_data_unsigned;
    logic        [63:0] result;
    logic        [64:0] result_hi;
    logic               ugt, sgt;

    assign ld_data_signed = ld_data_i[63:0],
           st_data_signed = st_data_i[63:0],
           ld_data_unsigned = ld_data_i[63:0],
           st_data_unsigned = st_data_i[63:0];

    assign ugt = (ld_data_unsigned > st_data_unsigned),
           sgt = (ld_data_signed   > st_data_signed),
           sum =  ld_data_signed   + st_data_signed;

    always_comb
    begin : amo_compute_comb
        unique case (1'b1)
            op_i.is_amo_lr   : result = ld_data_unsigned;
            op_i.is_amo_sc   : result = st_data_unsigned;
            op_i.is_amo_swap : result = st_data_unsigned;
            op_i.is_amo_add  : result = sum;
            op_i.is_amo_and  : result = ld_data_unsigned & st_data_unsigned;
            op_i.is_amo_or   : result = ld_data_unsigned | st_data_unsigned;
            op_i.is_amo_xor  : result = ld_data_unsigned ^ st_data_unsigned;
            op_i.is_amo_max  : result = sgt ? ld_data_unsigned : st_data_unsigned;
            op_i.is_amo_maxu : result = ugt ? ld_data_unsigned : st_data_unsigned;
            op_i.is_amo_min  : result = sgt ? st_data_unsigned : ld_data_unsigned;
            op_i.is_amo_minu : result = ugt ? st_data_unsigned : ld_data_unsigned;
            default          : result = '0;
        endcase
        unique case (1'b1)
            op_i.is_amo_lr   : result_hi = ld_data_i[128:64];
            op_i.is_amo_sc   : result_hi = st_data_i[128:64];
            op_i.is_amo_swap : result_hi = st_data_i[128:64];
            default          : result_hi = '0;
        endcase
        result_o = {result_hi, result};
    end
endmodule
