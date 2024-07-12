module VGA(
    input logic clk_ppu, clk_vga,
    input logic reset, 
    input logic [7:0] ppu_pixel,
    input logic [8:0] ppu_hcnt, ppu_vcnt,

    output logic vga_hsync, vga_vsync,
    output logic [3:0] vga_r, vga_g, vga_b
);

endmodule