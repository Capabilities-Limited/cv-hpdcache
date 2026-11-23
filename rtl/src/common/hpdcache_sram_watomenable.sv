/*
 *  Creation Date : December, 2025
 *  Description   : Wrapper for 1RW SRAM macros implementing a write atom enable
 */
module hpdcache_sram_watomenable
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned ATOM_SIZE = DATA_SIZE >= 8 ? 8 : DATA_SIZE,
    //  When set, each atom is protected by its own SECDED code
    parameter bit          ECC_EN = 1'b0,
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

    if (ECC_EN) begin : gen_sram_ecc
        hpdcache_sram_watomenable_ecc_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .ATOM_SIZE(ATOM_SIZE)
        ) ram_i (
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .watomenable,
            .rdata,

            .err_inj_i,
            .err_inj_msk_i,
            .err_cor_o,
            .err_unc_o
        );
    end else begin : gen_sram
        logic _unused_err_inj;

        hpdcache_sram_watomenable_1rw #(
            .ADDR_SIZE(ADDR_SIZE),
            .DATA_SIZE(DATA_SIZE),
            .DEPTH(DEPTH),
            .ATOM_SIZE(ATOM_SIZE)
        ) ram_i (
            .clk,
            .rst_n,
            .cs,
            .we,
            .addr,
            .wdata,
            .watomenable,
            .rdata
        );

        assign _unused_err_inj = 1'b0 && (err_inj_i & |err_inj_msk_i);
        assign err_cor_o = '0;
        assign err_unc_o = '0;
    end

endmodule : hpdcache_sram_watomenable
// vim: ts=4 : sts=4 : sw=4 : et : tw=100 : spell : spelllang=en
