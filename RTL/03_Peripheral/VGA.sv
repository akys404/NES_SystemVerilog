module VGA(
    input logic clk_ppu, clk_vga,
    input logic reset, 
    input logic [7:0] ppu_pixel,
    input logic [8:0] ppu_hcnt, ppu_vcnt,

    output logic vga_hsync, vga_vsync,
    output logic [3:0] vga_r, vga_g, vga_b
);
// ==========================================================
//                 Parameter
// ==========================================================
parameter HPERIOD = 10'd800;
parameter HFRONT = 10'd80;
parameter HWIDTH = 10'd96;
parameter HBACK = 10'd112;

parameter VPERIOD = 10'd525;
parameter VFRONT = 10'd10;
parameter VWIDTH = 10'd2;
parameter VBACK = 10'd33;

parameter PPU_HDISP = 9'd256;
parameter PPU_VDISP = 9'd240;
parameter PPU_DELAY = 9'd3;     // INDEX_BG -> INDEX -> PRAM
parameter VGA_DELAY = 10'd3;    // VRAM -> CROM -> FF


// ==========================================================
//                 Module definitions
// ==========================================================
VRAM VRAM (
    // NES section
    .data_a(ppu_pixel),
    .address_a(address_a),
    .wren_a(wren),
    .clock_a(clk_ppu),
    .q_a(),
    // VGA section
    .data_b(8'h00),
    .address_b(address_b),
    .wren_b(1'b0),
    .clock_b(clk_vga),
    .q_b(vga_pixel)
);

CROM CROM(
    .clk(clk_vga),
    .address(vga_pixel[5:0]),
    .data(vga_rgb)
);


// ==========================================================
//                 Counter operation
// ==========================================================
logic [9:0] vga_hcnt;
logic [9:0] vga_vcnt;

wire hcntend = (vga_hcnt == HPERIOD - 10'd1);

always_ff @(posedge clk_vga)
    if (reset)
        vga_hcnt <= 10'd0;
    else if (hcntend)
        vga_hcnt <= 10'd0;
    else
        vga_hcnt <= vga_hcnt + 10'd1;

always_ff @(posedge clk_vga)
    if (reset)
        vga_vcnt <= 10'd0;
    else if (hcntend)
        if (vga_vcnt == VPERIOD - 10'd1)
            vga_vcnt <= 10'd0;
        else
            vga_vcnt <= vga_vcnt + 10'd1;


// ==========================================================
//                 vga_hsync / vga_vsync
// ==========================================================
wire [9:0] hsstart = HFRONT - 10'd1;
wire [9:0] hsend = HFRONT + HWIDTH - 10'd1;
wire [9:0] vsstart = VFRONT;
wire [9:0] vsend = VFRONT + VWIDTH;

always_ff @(posedge clk_vga)
    if (reset)
        vga_hsync <= 1'b1;
    else if (vga_hcnt == hsstart)
        vga_hsync <= 1'b0;
    else if (vga_hcnt == hsend)
        vga_hsync <= 1'b1;

always_ff @(posedge clk_vga)
    if (reset)
        vga_vsync <= 1'b1;
    else if (vga_hcnt == hsstart)
        if (vga_vcnt == vsstart)
            vga_vsync <= 1'b0;
        else if (vga_vcnt == vsend)
            vga_vsync <= 1'b1;


// ==========================================================
//                 NES section
// ==========================================================
wire [8:0] address_a_lsb = ppu_hcnt - PPU_DELAY;
wire [15:0] address_a = {ppu_vcnt[7:0], address_a_lsb[7:0]};
wire h_wren = address_a_lsb < PPU_HDISP;
wire v_wren = ppu_vcnt < PPU_VDISP;
wire wren =  h_wren && v_wren; 


// ==========================================================
//                 VGA section
// ==========================================================
// VRAM section
logic [5:0] vga_pixel;
wire [9:0] vga_ihcnt = vga_hcnt - HFRONT - HWIDTH - HBACK + VGA_DELAY;
wire [9:0] vga_ivcnt = vga_vcnt - VFRONT - VWIDTH - VBACK;
wire [15:0] address_b = {vga_ivcnt[8:1], vga_ihcnt[8:1]};

// CROM section
logic [11:0] vga_rgb;

// FF section
logic hdispen, vdispen;

wire [9:0] hdstart = HFRONT + HWIDTH + HBACK - 10'd2;
wire [9:0] hdend = HPERIOD - 10'd2;
wire [9:0] vdstart = VFRONT + VWIDTH + VBACK - 10'd1;
wire [9:0] vdend = VPERIOD - 10'd1;
wire dispen = hdispen && vdispen;

always_ff @(posedge clk_vga)
    if (reset)
        hdispen <= 1'b0;
    else if (vga_hcnt == hdstart)
        hdispen <= 1'b1;
    else if (vga_hcnt == hdend)
        hdispen <= 1'b0;

always_ff @(posedge clk_vga)
    if (reset)
        vdispen <= 1'b0;
    else if (vga_hcnt == hdstart)
        if (vga_vcnt == vdstart)
            vdispen <= 1'b1;
        else if (vga_vcnt == vdend)
            vdispen <= 1'b0;

always_ff @(posedge clk_vga)
    if (reset) begin
        vga_r <= 4'h0;
        vga_g <= 4'h0;
        vga_b <= 4'h0;
    end
    else if (dispen) begin
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