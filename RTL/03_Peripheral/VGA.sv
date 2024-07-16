module VGA(
    input logic clk_ppu, clk_vga,
    input logic reset, 
    input logic [7:0] ppu_pixel,
    input logic [8:0] ppu_hcnt, ppu_vcnt,

    output logic vga_hsync, vga_vsync,
    output logic [3:0] vga_r, vga_g, vga_b
);


// ==========================================================
//                 Counter operation
// ==========================================================
logic [9:0] vga_hcnt;
always_ff @(posedge clk_vga)
    if (reset)
        vga_hcnt <= 10'd0;
    else if (vga_hcnt == 10'd799)
        vga_hcnt <= 10'd0;
    else
        vga_hcnt <= vga_hcnt + 10'd1;

logic [9:0] vga_vcnt;
always_ff @(posedge clk_vga)
    if (reset)
        vga_vcnt <= 10'd0;
    else if (vga_hcnt == 10'd799 && vga_vcnt == 10'd524)
        vga_vcnt <= 10'd0;
    else if (vga_hcnt == 10'd799)
        vga_vcnt <= vga_vcnt + 10'd1;


// ==========================================================
//                 vga_hsync / vga_vsync
// ==========================================================
always_ff @(posedge clk_vga)
    if (reset)
        vga_hsync <= 1'b0;
    else if (vga_hcnt == 10'd594)
        vga_hsync <= 1'b0;
    else if (vga_hcnt == 10'd690)
        vga_hsync <= 1'b1;

always_ff @(posedge clk_vga)
    if (reset)
        vga_vsync <= 1'b0;
    else if (vga_hcnt == 10'd594 && vga_vcnt == 10'd489)
        vga_vsync <= 1'b0;
    else if (vga_hcnt == 10'd594 && vga_vcnt == 10'd491)
        vga_vsync <= 1'b1;


// ==========================================================
//                 VGA VRAM
// ==========================================================
// Stores data in VRAM
wire [5:0] vga_pixel;
wire [8:0] vram_hcnt = ppu_hcnt -  9'd4;
wire [15:0] address_a = {ppu_vcnt[7:0], vram_hcnt[7:0]};
wire [15:0] address_b = {vga_vcnt[8:1], vga_hcnt[8:1]};
wire vram_we = vram_hcnt <= 9'd255 && ppu_vcnt <= 9'd239;
VRAM VRAM (
// Create a 65536 × 8 2-Port RAM using IP cores
    // NES section
    .data_a(ppu_pixel),
    .address_a(address_a),
    .wren_a(vram_we),
    .clock_a(clk_ppu),
    .q_a(),
    // VGA section
    .data_b(8'h00),
    .address_b(address_b),
    .wren_b(1'b0),
    .clock_b(clk_vga),
    .q_b(vga_pixel)
);


// ==========================================================
//                 VGA CROM
// ==========================================================
wire [11:0] vga_rgb;
CROM CROM(
    .clk(clk_vga),
    .address(vga_pixel[5:0]),
    .data(vga_rgb)
);


// ==========================================================
//                 VGA RGB
// ==========================================================
logic [1:0] vga_rgb_en;
always_ff @(posedge clk_vga)
    if (vga_hcnt < 512 && vga_vcnt < 480)
        vga_rgb_en <= {vga_rgb_en[0], 1'b1};
    else
        vga_rgb_en <= {vga_rgb_en[0], 1'b0};

// VGA_R, VGA_G, VGA_B
always_ff @(posedge clk_vga)
    if (reset) begin
        vga_r <= 4'h0;
        vga_g <= 4'h0;
        vga_b <= 4'h0;
    end
    else if (vga_rgb_en[1]) begin
        vga_r <= vga_rgb[11:8];
        vga_g <= vga_rgb[7:4];
        vga_b <= vga_rgb[3:0];
    end
    else begin
        vga_r <= 4'h0;
        vga_g <= 4'h0;
        vga_b <= 4'h0;
    end

endmodule