// ==========================================================
//                 Clock generator
// ==========================================================
module CLKGEN(
    input logic clk, n_reset,
    output logic clk_cpu, clk_ppu, clk_vga, reset
);

endmodule


// ==========================================================
//                 ADDR FF (LS373)
// ==========================================================
module ADDR_FF(
    input logic ale,
    inout logic [7:0] d,
    output logic [7:0] q
);

endmodule


// ==========================================================
//                 ADDR decoder (LS139)
// ==========================================================
module ADDR_DEC(
    input logic m2,
    output logic cs, n_rom_sel, n_dbe,
    input logic [2:0] address
);

endmodule