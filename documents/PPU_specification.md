# PPU仕様書

## 1. インターフェース

### 1-1. 定義

```systemverilog
module PPU(
    input logic clk, reset,
    // Timing section
    output logic [8:0] hcnt, vcnt,
    // rendering section
    output logic n_int,
    output logic [7:0] pixel,
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

### 1-2. 仮想インターフェース

Inoutポートを展開し、仮想的にInput/Outputポートに変換する。

```systemverilog
/*
module PPU(
    input logic clk, reset,
    // Timing section
    output logic [8:0] hcnt, vcnt,
    // rendering section
    output logic n_int,
    output logic [7:0] pixel,
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

#### CPUバスの展開

```systemverilog
logic [7:0] cpu_data_bus_in;
logic [7:0] cpu_data_bus_out;

wire cpu_data_bus_en = !n_dbe && rw;

assign cpu_data_bus = (cpu_data_bus_en) ? cpu_data_bus_out : 8'bz;
assign cpu_data_bus_in = (!cpu_data_bus_en) ? cpu_data_bus : 8'b0;
```

#### PPUバスの展開

```systemverilog
logic [13:0] ppu_addr_bus;
logic [7:0] ppu_data_bus_in;
logic [7:0] ppu_data_bus_out;

assign ppu_msb_bus = ppu_addr_bus[13:8];
assign ppu_lsb_bus = (ale) ? ppu_addr_bus[7:0] : (!n_we) ? ppu_data_bus_out : 8'bz;
assign ppu_data_bus_in = (!ale && !n_rd) ? ppu_lsb_bus : 8'b0;
```



## 2. 外部出力部

### 2-1. カウンタ

```systemverilog
module Counter(
    // External section
    input logic clk, reset,
    output logic [8:0] hcnt, vcnt
)

endmodule
```

#### ★ hcnt, vcnt

```systemverilog
// parameter
parameter HCNTMAX = 9'd340;
parameter VCNTMAX = 9'd261;
parameter VCNTVIS = 9'd239;

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



### 2-2. 描画モジュール

レンダリングパイプラインを定義するモジュール。

```systemverilog
module Renderer(
    // Internal section
    // n_int
    input logic [7:0] ppustatus,
    input logic [7:0] ppuctrl,
    // pixel
    input logic [8:0] hcnt, vcnt,
    input logic [14:0] ppu_v,
    input logic [2:0] ppu_x,
    input logic [7:0] bg_msb, bg_lsb, bg_attr,
    input logic [4:0] sp_index,

    // External section
    input logic clk, reset,
    output logic n_int,
    output logic [7:0] pixel
)

endmodule
```

#### ★ n_int

> 参考：[https://www.nesdev.org/wiki/NMI](https://www.nesdev.org/wiki/NMI)

1. Start of vertical blanking (dot 1 of line 241) : Set vblank_flag in PPU to true.
2. End of vertical blanking (dot 1 of line 261) : Set vblank_flag to false.
3. Read [PPUSTATUS](https://www.nesdev.org/wiki/PPUSTATUS): Return old status of vblank_flag in bit 7, then set vblank_flag to false.
4. Write to [PPUCTRL](https://www.nesdev.org/wiki/PPUCTRL): Set NMI_output to bit 7.

The PPU pulls /NMI low if and only if both vblank_flag and NMI_output are true.

```systemverilog
wire n_int = !(ppustatus[7] && ppuctrl[7]);
```

#### ★ pixel

> 参考１：https://www.nesdev.org/wiki/PPU_rendering#PPU_address_bus_contents
>
> 参考２：https://www.nesdev.org/wiki/PPU_memory_map

On every 8th dot in these background fetch regions (the same dot on which the coarse x component of v is incremented), the pattern and attributes data are transferred into registers used for producing pixel data.

To generate the background in the picture region, the PPU performs memory fetches on dots 321-336 and 1-256 of scanlines 0-239 and 261. On every dot in these background fetch regions, a 4-bit pixel is selected by the fine x register from the low 8 bits of the pattern and attributes shift registers, which are then shifted.

// ここでスプライト0ヒットの判定を行う必要がありそう。

```systemverilog
// Shift utility
wire trans_en = bg_fetch_en && (hcnt[2:0] == 3'b111);

// BG shift register
// {bg_msb, bg_lsb} -> $BG_SHIFT;
logic [15:0] bg_msb_shift, bg_lsb_shift;
always_ff @(posedge clk)
    if (trans_en) begin
        bg_msb_shift <= {bg_msb_shift[14:7], bg_msb};
        bg_lsb_shift <= {bg_lsb_shift[14:7], bg_lsb};
    end
    else if (shift_en) begin
        bg_msb_shift <= {bg_msb_shift[14:0], 1'b1};
        bg_lsb_shift <= {bg_lsb_shift[14:0], 1'b1};
    end

// Attributes shift register
// {bg_attr} -> $AT_SHIFT;
logic [15:0] attr_msb_shift, attr_lsb_shift;
always_ff @(posedge clk)
    if (trans_en) begin
        attr_msb_shift <= {attr_msb_shift[14:7], 8{bg_attr_mux[1]}};
        attr_lsb_shift <= {attr_lsb_shift[14:7], 8{bg_attr_mux[0]}};
    end
    else if (shift_en) begin
        attr_msb_shift <= {attr_msb_shift[14:0], 1'b1};
        attr_lsb_shift <= {attr_lsb_shift[14:0], 1'b1};
    end

logic [1:0] bg_attr_mux;
always_comb
    case({ppu_v[6], ppu_v[1]})
        2'b00: bg_attr_mux = bg_attr[1:0];
        2'b01: bg_attr_mux = bg_attr[3:2];
        2'b10: bg_attr_mux = bg_attr[5:4];
        2'b11: bg_attr_mux = bg_attr[7:6];
        default: bg_attr_mux = 'x;
    endcase


// Fine_x select mux
// $SHIFTER * $REG_X -> $INDEX_BG;
logic [3:0] bg_index, bg_index_mux;
always_ff @(posedge CLK)
    bg_index <= bg_index_mux;
always_comb
    case(ppu_x)
        3'b000: bg_index_mux = {attr_msb_shift[15], attr_lsb_shift[15], bg_msb_shift[15], bg_lsb_shift[15]};
        3'b001: bg_index_mux = {attr_msb_shift[14], attr_lsb_shift[14], bg_msb_shift[14], bg_lsb_shift[14]};
        3'b010: bg_index_mux = {attr_msb_shift[13], attr_lsb_shift[13], bg_msb_shift[13], bg_lsb_shift[13]};
        3'b011: bg_index_mux = {attr_msb_shift[12], attr_lsb_shift[12], bg_msb_shift[12], bg_lsb_shift[12]};
        3'b100: bg_index_mux = {attr_msb_shift[11], attr_lsb_shift[11], bg_msb_shift[11], bg_lsb_shift[11]};
        3'b101: bg_index_mux = {attr_msb_shift[10], attr_lsb_shift[10], bg_msb_shift[10], bg_lsb_shift[10]};
        3'b110: bg_index_mux = {attr_msb_shift[9], attr_lsb_shift[9], bg_msb_shift[9], bg_lsb_shift[9]};
        3'b111: bg_index_mux = {attr_msb_shift[8], attr_lsb_shift[8], bg_msb_shift[8], bg_lsb_shift[8]};
        default: bg_index_mux = 'x;
    endcase


// Priority mux
// ${bg_index} * {sp_index} -> $INDEX;



// Pallet RAM
// $INDEX -> {pixel};

```



### 2-3. PPUバス入出力

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

#### ★ ale

```systemverilog
logic 
```

#### ★ n_rd

```systemverilog
logic 
```

#### ★ n_we

```systemverilog
logic 
```

#### ★ ppu_data_bus_out

```systemverilog
logic 
```

#### ★ ppu_addr_bus

During frame rendering, provided rendering is enabled (i.e., when either background or sprite rendering is enabled in [$2001:3-4](https://www.nesdev.org/wiki/PPU_registers)), the value on the PPU address bus is as indicated in the descriptions above and in the frame timing diagram below. During VBlank and when rendering is disabled, the value on the PPU address bus is the current value of the [v](https://www.nesdev.org/wiki/PPU_scrolling) register.

```systemverilog
logic 
```



### 2-4. CPUバス入出力

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

#### ★ cpu_data_bus_out

```systemverilog
logic 
```



## 3. 背景データ

To generate the background in the picture region, the PPU performs memory fetches on dots 321-336 and 1-256 of scanlines 0-239 and 261.

### 3-1. 背景データ取得

```systemverilog
module BG_Fetch(
    // Internal section
    input logic [8:0] hcnt, vcnt,
    output logic bg_fetch_en,
    // External section
    input logic clk, reset
)

endmodule
```

#### bg_fetch_en

```systemverilog
// parameter
parameter HFETCH_BEGIN = 9'd1;
parameter HFETCH_END = 9'd256;
parameter HPREFETCH_BEGIN = 9'd321;
parameter HPREFETCH_END = 9'd336;

parameter VFETCH_BEGIN = 9'd0;
parameter VFETCH_END = 9'd239;
parameter VPREFETCH = 9'd261;

// backgrond fetch
wire bg_hfetch_en = ((HFETCH_BEGIN - 9'd1 <= hcnt) && (hcnt <= HFETCH_END - 9'd1))
|| ((HPREFETCH_BEGIN - 9'd1 <= hcnt) && (hcnt <= HPREFETCH_END - 9'd1));
wire bg_vfetch_en = ((VFETCH_BEGIN <= vcnt) && (vcnt <= VFETCH_END))
|| (vcnt == VPREFETCH);
wire bg_fetch_en = bg_hfetch_en && bg_vfetch_en;
```



### 3-2. 背景データ

#### bg_msb

```systemverilog
```

#### bg_lsb

```systemverilog
```

#### bg_attr

```systemverilog
```



## 4. スプライトデータ

### 4-1. OAM

> 参考：https://www.nesdev.org/wiki/PPU_OAM

#### oam

```systemverilog
```

#### oam_2nd

Y座標のチェック方法：0 <= Scanline.Y座標 - Sprite.Y座標 < Sprite.高さ

```systemverilog

```



### 4-2. スプライト取得

> 参考１：https://www.nesdev.org/wiki/PPU_sprite_evaluation
>
> 参考２：https://www.nesdev.org/wiki/PPU_sprite_priority

OAM -> Secondary OAM -> Sprite fetch -> Sprite output unit [7:0] -> sp_index

#### sp_fetch

```systemverilog

```



### 4-3. スプライト

#### sp_output_unit

Secondary OAMの4byteの属性、Sprite pattern data、hcntからindexデータを吐き出すユニット。
クロック毎にX座標を減算し、X座標が0~-7の間出力する

```systemverilog
module Sprite_output_unit(
    // Internal section
    input logic [8:0] hcnt, vcnt,
    input logic // Secondary OAM 4byte,
    input logic // Sprite pattern data,
    output logic [4:0] sp_index_raw
    // External section
)
    
endmodule
```

#### sp_index

Sprite_output_unit#0~7を入力として、優先度の高いユニットからの入力を出力する。

```systemverilog
always_comb
```



## 5. 内部制御部

### 5-1. Pallet RAM

```systemverilog
/*
logic [7:0] PPU_PRAM [2**5-1:0];
always_ff @(posedge CLK)
    if (PPU_PRAM_EN && REG_PRAM_WR)
        if (PPU_ADDR[1:0] == 2'b00 )
            PPU_PRAM[{1'b0, PPU_ADDR[3:0]}] <= CPU_DATA;
        else
            PPU_PRAM[PPU_ADDR[4:0]] <= CPU_DATA;


logic [7:0] PPU_PRAM_DATA;
always_comb
    if (PPU_PRAM_EN && REG_PRAM_WR)
        PPU_PRAM_DATA = CPU_DATA;
    else if (PPU_PRAM_EN && PPU_RD)
        PPU_PRAM_DATA = PPU_PRAM[PPU_ADDR[4:0]];
    else if (RND_INDEX[1:0] == 2'b00)
        PPU_PRAM_DATA = PPU_PRAM[5'h00];
    else
        PPU_PRAM_DATA = PPU_PRAM[RND_INDEX];

always_ff @(posedge CLK)
    PPU_PIXEL <= PPU_PRAM_DATA;

wire PPU_PRAM_EN = (14'h3F00 <= ppu_addr_bus) && (ppu_addr_bus <= 14'h3FFF);
*/
```



### 5-2. レジスタ

#### ppuctrl

```systemverilog
```

#### ppumask

```systemverilog
```

#### ppustatus

```systemverilog
```

#### oamaddr

```systemverilog
```

#### oamdata

```systemverilog
```

#### ppuscroll

```systemverilog
```

#### ppuaddr

```systemverilog
```

#### ppudata

```systemverilog
```



### 5-3. 内部レジスタ

#### ppu_v

```systemverilog
```

#### ppu_t

```systemverilog
```

#### ppu_x

```systemverilog
```
