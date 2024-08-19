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
    inout logic [7:0] ppu_data,

    // VGA section
    output logic vga_hsync, vga_vsync,
    output logic [3:0] vga_r, vga_g, vga_b
);

// CPU section
assign cpu_addr = cpu_addr_bus[14:0];
assign cpu_data = cpu_data_bus;

// PPU section
assign ppu_addr = {~ppu_msb_bus[5], ppu_msb_bus[4:0], ppu_lsb_bus_ff};
assign ppu_data = ppu_lsb_bus;


// ==========================================================
//                 CPU.sv
// ==========================================================
wire [15:0] cpu_addr_bus;
wire [7:0] cpu_data_bus;
CPU CPU(
    .clk(clk_cpu),
    .reset(reset),
    // control signal
    .n_irq(n_irq),
    .n_nmi(n_int),
    .m2(m2),
    .rw(rw),
    // data bus
    .addr_bus(cpu_addr_bus),
    .data_bus(cpu_data_bus)
);

// ==========================================================
//                 PPU.sv
// ==========================================================
wire ale, n_int;
wire [5:0] ppu_msb_bus;
wire [7:0] ppu_lsb_bus, ppu_pixel;
wire [8:0] ppu_hcnt, ppu_vcnt;
PPU PPU(
    .clk(clk_ppu),
    .reset(reset),
    // control signal
    .ale(ale),
    .n_rd(n_rd),
    .n_we(n_we),
    .n_int(n_int),
    .n_dbe(n_dbe),
    .pixel(ppu_pixel),
    .hcnt(ppu_hcnt),
    .vcnt(ppu_vcnt),
    // data bus
    .cpu_addr_bus(cpu_addr_bus[2:0]),
    .cpu_data_bus(cpu_data_bus),
    .ppu_msb_bus(ppu_msb_bus),
    .ppu_lsb_bus(ppu_lsb_bus)
);

// ==========================================================
//                 Utility.sv
// ==========================================================
wire clk_cpu, clk_ppu, clk_vga, reset;
CLKGEN CLKGEN(
    .clk(clk),
    .n_reset(n_reset),
    .clk_cpu(clk_cpu),
    .clk_ppu(clk_ppu),
    .clk_vga(clk_vga),
    .reset(reset)
);

SRAM CPU_SRAM(
    .clk(clk_cpu),
    .reset(reset),
    .n_cs(!cpu_sram_cs),
    .n_we(rw),
    .n_oe(1'b0),
    .address(cpu_addr_bus[10:0]),
    .data(cpu_data_bus)
);

SRAM PPU_SRAM(
    .clk(clk_ppu),
    .reset(reset),
    .n_cs(n_vram_cs),
    .n_we(n_we),
    .n_oe(n_rd),
    .address({n_vram_a10, ppu_msb_bus[1:0], ppu_lsb_bus_ff}), // Unclear if n_vram_a10 should be inverted
    .data(ppu_lsb_bus)
);

wire [7:0] ppu_lsb_bus_ff;
ADDR_latch ADDR_latch(
    .ale(ale),
    .d(ppu_lsb_bus),
    .q(ppu_lsb_bus_ff)
);

wire n_dbe, cpu_sram_cs;
ADDR_decoder ADDR_decoder(
    .m2(m2),
    .cs(cpu_sram_cs),
    .n_rom_sel(n_rom_sel),
    .n_dbe(n_dbe),
    .address(cpu_addr_bus[15:13])
);

// ==========================================================
//                 VGA.sv
// ==========================================================
VGA VGA(
    .clk_ppu(clk_ppu),
    .clk_vga(clk_vga),
    .reset(reset),
    .ppu_pixel(ppu_pixel),
    .ppu_hcnt(ppu_hcnt),
    .ppu_vcnt(ppu_vcnt),

    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync),
    .vga_r(vga_r),
    .vga_g(vga_g),
    .vga_b(vga_b)
);

endmodule