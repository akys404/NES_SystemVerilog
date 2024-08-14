# PPU仕様書

## インターフェース

```systemverilog
module PPU(
    input logic clk, reset,
    // rendering section
    output logic n_int,
    output logic [7:0] pixel,
    output logic [8:0] hcnt, vcnt,
    // ppu bus section
    output logic ale, n_rd, n_we
    output logic [5:0] ppu_msb_bus,
    inout logic [7:0] ppu_lsb_bus
    // cpu bus section
    input logic rw, n_dbe,
    input logic [2:0] cpu_addr_bus,
    inout logic [7:0] cpu_data_bus
);

endmodule
```



## インターフェースの整理

Inoutポートを展開し、仮想的にInput/Outputポートに変換する。

```systemverilog
/*
module PPU(
    input logic clk, reset,
    // rendering section
    output logic n_int,
    output logic [7:0] pixel,
    output logic [8:0] hcnt, vcnt,
    // ppu bus section
    input logic [7:0] ppu_data_bus_in,
    output logic ale, n_rd, n_we,
    output logic [7:0] ppu_data_bus_out,
    output logic [13:0] ppu_addr_bus,
    // cpu bus section
    input logic rw, n_dbe,
    input logic [2:0] cpu_addr_bus,
    input logic [7:0] cpu_data_bus_in,
    output logic [7:0] cpu_data_bus_out
);

endmodule
*/
```

### CPUバスの展開

```systemverilog
logic [7:0] cpu_data_bus_in;
logic [7:0] cpu_data_bus_out;

wire cpu_data_bus_en = !n_dbe && rw;

assign cpu_data_bus = (cpu_data_bus_en) ? cpu_data_bus_out : 8'bz;
assign cpu_data_bus_in = (!cpu_data_bus_en) ? cpu_data_bus : 8'b0;
```

### PPUバスの展開

```systemverilog
logic [13:0] ppu_addr_bus;
logic [7:0] ppu_data_bus_in;
logic [7:0] ppu_data_bus_out;

assign ppu_msb_bus = ppu_addr_bus[13:8];
assign ppu_lsb_bus = (ale) ? ppu_addr_bus[7:0] : (!n_we) ? ppu_data_bus_out : 8'bz;
assign ppu_data_bus_in = (!ale && !n_rd) ? ppu_lsb_bus : 8'b0;
```



## インターフェースモジュール

### 描画モジュール

レンダリングパイプラインを定義するモジュール。

```systemverilog
module Renderer(
    // Internal section
    // n_int
    input logic [7:0] ppustatus,
    input logic [7:0] ppuctrl,
	// pixel
    input logic [7:0] bg_lsb,
    input logic [7:0] bg_msb,
    input logic [7:0] bg_attr,
    input logic [7:0] sprites [7:0],

    // External section
    input logic clk, reset,
    output logic n_int,
    output logic [7:0] pixel,
    output logic [8:0] hcnt, vcnt
)
    // parameter
    parameter HCNTMAX = 9'd340;
    parameter VCNTMAX = 9'd261;
    parameter VCNTVIS = 9'd239;

endmodule
```

#### n_int

> 参考：[https://www.nesdev.org/wiki/NMI](https://www.nesdev.org/wiki/NMI)

1. Start of vertical blanking (dot 1 of line 241) : Set vblank_flag in PPU to true.
2. End of vertical blanking (dot 1 of line 261) : Set vblank_flag to false.
3. Read [PPUSTATUS](https://www.nesdev.org/wiki/PPUSTATUS): Return old status of vblank_flag in bit 7, then set vblank_flag to false.
4. Write to [PPUCTRL](https://www.nesdev.org/wiki/PPUCTRL): Set NMI_output to bit 7.

The PPU pulls /NMI low if and only if both vblank_flag and NMI_output are true.

```systemverilog
wire n_int = !(ppustatus[7] && ppuctrl[7]);
```

#### pixel

```systemverilog
// BG shift register
wire SHIFT_EN = (9'd001 <= HCNT) && (HCNT <= 9'd336);

logic [15:0] BGL_SHIFT, BGH_SHIFT;
always_ff @(posedge CLK)
    if (SHIFT_EN && HCNT[2:0] == 3'b000)
        BGL_SHIFT <= {BGL_SHIFT[14:7], BGL_DATA};
        BGH_SHIFT <= {BGH_SHIFT[14:7], BGH_DATA};
    else if (SHIFT_EN)
        BGL_SHIFT <= {BGL_SHIFT[14:0], 1'b1};
        BGH_SHIFT <= {BGH_SHIFT[14:0], 1'b1};

// Attributes shift register
logic [8:0] ATL_SHIFT, ATH_SHIFT;
always_ff @(posedge CLK)
    if (SHIFT_EN)
        ATL_SHIFT <= {ATL_SHIFT[7:0], AT_LATCH[0]};
        ATH_SHIFT <= {ATH_SHIFT[7:0], AT_LATCH[1]};

logic [1:0] AT_LATCH, AT_LATCH_nxt;
always_ff @(posedge CLK)
    if (SHIFT_EN && HCNT[2:0] == 3'b000)
        AT_LATCH <= AT_LATCH_nxt;
always_comb
    case({REG_V[6], REG_V[1]})
        2'b00: AT_LATCH_nxt = AT_DATA[1:0];
        2'b01: AT_LATCH_nxt = AT_DATA[3:2];
        2'b10: AT_LATCH_nxt = AT_DATA[5:4];
        2'b11: AT_LATCH_nxt = AT_DATA[7:6];
        default: AT_LATCH_nxt = 'x;
    endcase


// Fine_x select mux
logic [3:0] INDEX_BG, INDEX_BG_nxt;
always_ff @(posedge CLK)
    INDEX_BG <= INDEX_BG_nxt;
always_comb
    case(REG_X)
        3'b000: INDEX_BG_nxt = {ATH_SHIFT[7], ATL_SHIFT[7], BGH_SHIFT[15], BGH_SHIFT[15]};
        3'b001: INDEX_BG_nxt = {ATH_SHIFT[6], ATL_SHIFT[6], BGH_SHIFT[14], BGH_SHIFT[14]};
        3'b010: INDEX_BG_nxt = {ATH_SHIFT[5], ATL_SHIFT[5], BGH_SHIFT[13], BGH_SHIFT[13]};
        3'b011: INDEX_BG_nxt = {ATH_SHIFT[4], ATL_SHIFT[4], BGH_SHIFT[12], BGH_SHIFT[12]};
        3'b100: INDEX_BG_nxt = {ATH_SHIFT[3], ATL_SHIFT[3], BGH_SHIFT[11], BGH_SHIFT[11]};
        3'b101: INDEX_BG_nxt = {ATH_SHIFT[2], ATL_SHIFT[2], BGH_SHIFT[10], BGH_SHIFT[10]};
        3'b110: INDEX_BG_nxt = {ATH_SHIFT[1], ATL_SHIFT[1], BGH_SHIFT[9], BGH_SHIFT[9]};
        3'b111: INDEX_BG_nxt = {ATH_SHIFT[0], ATL_SHIFT[0], BGH_SHIFT[8], BGH_SHIFT[8]};
        default: INDEX_BG_nxt = 'x;
    endcase

// Priority mux
logic [4:0] INDEX;
always_ff @(posedge CLK)
    INDEX <= {1'b0, INDEX_BG};

// PRAM
INDEX -> PIXEL;

```

#### hcnt, vcnt

```systemverilog
// frame
logic frame;
wire frameend = (frame) ? HCNTMAX - 9'd1 : HCNTMAX;
always_ff @(posedge clk)
    if (reset)
        frame <= 1'b0;
	else if (vcnt == VCNTMAX && hcnt == frameend)
        frame <= ~frame;

// [8:0] hcnt
always_ff @(posedge clk)
    if (reset)
        hcnt <= 9'd0;
else if (vcnt == VCNTMAX && hcnt == frameend)
        hcnt <= 9'd0;
	else if (hcnt == HCNTMAX)
        hcnt <= 9'd0;
    else
        hcnt <= hcnt + 9'd1;

// [8:0] vcnt
always_ff @(posedge clk)
	if (reset)
        vcnt <= 9'd0;
else if (vcnt == VCNTMAX && hcnt == frameend)
        vcnt <= 9'd0;
	else if (hcnt == HCNTMAX)
        vcnt <= vcnt + 9'd1;
```



### PPUバスモジュール

各種の

```systemverilog
module PPU_BUS_IF(
    // Internal section

    // External section
    input logic clk, reset,
    input logic [7:0] ppu_data_bus_in,
    output logic ale, n_rd, n_we
    output logic [7:0] ppu_data_bus_out,
    output logic [13:0] ppu_addr_bus
)
    
endmodule
```

#### ale

```systemverilog
logic 
```

#### n_rd

```systemverilog
logic 
```

#### n_we

```systemverilog
logic 
```

#### ppu_data_bus_out

```systemverilog
logic 
```

#### ppu_addr_bus

```systemverilog
logic 
```



### CPUバスモジュール

各種の

```systemverilog
module CPU_BUS_IF(
    // Internal section

    // External section
    input logic clk, reset,
    input logic rw, n_dbe,
    input logic [2:0] cpu_addr_bus,
    output logic [7:0] cpu_data_bus_out
)
    
endmodule
```

#### cpu_data_bus_out

```systemverilog
logic 
```

