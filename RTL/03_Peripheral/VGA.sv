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
VGA_VRAM VGA_VRAM (
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

VGA_CROM VGA_CROM(
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


// ==========================================================
//                 VGA Utility
// ==========================================================
module VGA_VRAM #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 16
)(
    input logic clock_a,
    input logic wren_a,
    input logic [ADDR_WIDTH-1:0] address_a,
    input logic [DATA_WIDTH-1:0] data_a,
    output logic [DATA_WIDTH-1:0] q_a,

    input logic clock_b,
    input logic wren_b,
    input logic [ADDR_WIDTH-1:0] address_b,
    input logic [DATA_WIDTH-1:0] data_b,
    output logic [DATA_WIDTH-1:0] q_b
);

    // Memory block definitions
    (* ramstyle = "M10K" *) logic [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];

    // Port A operation
    always_ff @(posedge clock_a) begin
        if (wren_a) begin
            ram[address_a] <= data_a;
        end
        q_a <= ram[address_a];
    end

    // Port B operation
    always_ff @(posedge clock_b) begin
        if (wren_b) begin
            ram[address_b] <= data_b;
        end
        q_b <= ram[address_b];
    end

endmodule


module VGA_CROM(
    input logic clk,
    input logic [5:0] address,
    output logic [11:0] data
);

always_ff @(posedge clk) begin
    data <= rom_data;
end

logic [11:0] rom_data;
always_comb
    case(address[5:0])
        6'h00: rom_data = 12'h666;
        6'h01: rom_data = 12'h02B;
        6'h02: rom_data = 12'h20D;
        6'h03: rom_data = 12'h50B;
        6'h04: rom_data = 12'h707;
        6'h05: rom_data = 12'h802;
        6'h06: rom_data = 12'h710;
        6'h07: rom_data = 12'h530;
        6'h08: rom_data = 12'h240;
        6'h09: rom_data = 12'h050;
        6'h0A: rom_data = 12'h051;
        6'h0B: rom_data = 12'h052;
        6'h0C: rom_data = 12'h047;
        6'h0D: rom_data = 12'h000;
        6'h0E: rom_data = 12'h000;
        6'h0F: rom_data = 12'h000;

        6'h10: rom_data = 12'hBBB;
        6'h11: rom_data = 12'h15F;
        6'h12: rom_data = 12'h53F;
        6'h13: rom_data = 12'h91F;
        6'h14: rom_data = 12'hC1D;
        6'h15: rom_data = 12'hD17;
        6'h16: rom_data = 12'hC30;
        6'h17: rom_data = 12'hA50;
        6'h18: rom_data = 12'h680;
        6'h19: rom_data = 12'h2A0;
        6'h1A: rom_data = 12'h0A0;
        6'h1B: rom_data = 12'h0A4;
        6'h1C: rom_data = 12'h08B;
        6'h1D: rom_data = 12'h000;
        6'h1E: rom_data = 12'h000;
        6'h1F: rom_data = 12'h000;

        6'h20: rom_data = 12'hFFF;
        6'h21: rom_data = 12'h5BF;
        6'h22: rom_data = 12'h98F;
        6'h23: rom_data = 12'hD6F;
        6'h24: rom_data = 12'hF5F;
        6'h25: rom_data = 12'hF6D;
        6'h26: rom_data = 12'hF75;
        6'h27: rom_data = 12'hFA0;
        6'h28: rom_data = 12'hCC0;
        6'h29: rom_data = 12'h8E0;
        6'h2A: rom_data = 12'h4F1;
        6'h2B: rom_data = 12'h2F8;
        6'h2C: rom_data = 12'h3DF;
        6'h2D: rom_data = 12'h555;
        6'h2E: rom_data = 12'h000;
        6'h2F: rom_data = 12'h000;

        6'h30: rom_data = 12'hFFF;
        6'h31: rom_data = 12'hBEF;
        6'h32: rom_data = 12'hDDF;
        6'h33: rom_data = 12'hECF;
        6'h34: rom_data = 12'hFCF;
        6'h35: rom_data = 12'hFCE;
        6'h36: rom_data = 12'hFCC;
        6'h37: rom_data = 12'hFDA;
        6'h38: rom_data = 12'hEE8;
        6'h39: rom_data = 12'hDF8;
        6'h3A: rom_data = 12'hBFA;
        6'h3B: rom_data = 12'hBFC;
        6'h3C: rom_data = 12'hBFF;
        6'h3D: rom_data = 12'hBBB;
        6'h3E: rom_data = 12'h000;
        6'h3F: rom_data = 12'h000;
        default: rom_data = 'x;
    endcase

endmodule