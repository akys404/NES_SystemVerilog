module NES(
    // Common section
    input logic clk, n_reset,

    // CPU section
    input logic n_irq,
    output logic m2, rw, n_rom_sel,
    output logic [14:0] cpu_addr,
    inout logic [7:0] cpu_data,

    // PPU section
    input logic n_vram_cs, n_vram_a10,
    output logic n_rd, n_we,
    output logic [13:0] ppu_addr,
    inout logic [7:0] ppu_data
);

endmodule