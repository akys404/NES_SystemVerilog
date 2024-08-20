# PPU仕様書

## 1. インターフェース

### 1-1. 定義

```systemverilog
module PPU(
    input logic clk, reset,
    // counter section
    output logic n_int,
    output logic [8:0] hcnt, vcnt,
    // rendering section
    output logic [7:0] pixel,
    // ppu bus section
    output logic ale, n_rd, n_we
    output logic [5:0] ppu_msb_bus,
    inout logic [7:0] ppu_lsb_bus, ppu_lsb_bus_ale,
    // cpu bus section
    input logic rw, n_dbe,
    input logic [2:0] cpu_addr_bus,
    inout logic [7:0] cpu_data_bus
);
```

### 1-2. 仮想インターフェース

Inoutポートを展開し、仮想的にInput/Outputポートに変換する。

```systemverilog
/*
module PPU(
    input logic clk, reset,
    // counter section
    output logic n_int,
    output logic [8:0] hcnt, vcnt,
    // rendering section
    output logic [7:0] pixel,
    // ppu bus section
    output logic ale, n_rd, n_we,
    output logic [13:0] ppu_addr_bus,
    input logic [7:0] ppu_data_bus_in,
    output logic [7:0] ppu_data_bus_out,
    // cpu bus section
    input logic rw, n_dbe,
    input logic [2:0] cpu_addr_bus,
    input logic [7:0] cpu_data_bus_in,
    output logic [7:0] cpu_data_bus_out
);
*/
```

#### PPUバスの展開

```systemverilog
logic [13:0] ppu_addr_bus;
logic [7:0] ppu_data_bus_in;
logic [7:0] ppu_data_bus_out;

assign ppu_msb_bus = ppu_addr_bus[13:8];
assign ppu_lsb_bus = (ale) ? ppu_addr_bus[7:0] : ppu_data_bus_out;
assign ppu_lsb_bus_ale = ppu_addr_bus[7:0];
assign ppu_data_bus_in = ppu_lsb_bus;
```

#### CPUバスの展開

```systemverilog
logic [7:0] cpu_data_bus_in;
logic [7:0] cpu_data_bus_out;

assign cpu_data_bus = cpu_data_bus_out;
assign cpu_data_bus_in = cpu_data_bus;
```



## 2. 基幹制御

### 2-1. カウンタ

```systemverilog
module Counter(
    input logic clk, reset,
    // n_int
    input logic [7:0] ppustatus,
    input logic [7:0] ppuctrl,
    output logic n_int,
    // hcnt, vcnt
    output logic [8:0] hcnt, vcnt
);
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



### 2-2. レンダリング

レンダリングパイプラインを定義するモジュール。

```systemverilog
module Renderer(
    input logic clk, reset,
    // pixel
    input logic [3:0] bg_index,
    input logic [4:0] sp_index,
    output logic rendering_en,
    output logic [7:0] pixel,
    // sprite0_hit
    input logic sprite0_scanline,
    input logic sprite0_rendering,
    output logic sprite0_hit
);
```

#### rendering_en

- [ ] n_vblankフラグを作成する
- [ ] sp_fetch_en = n_vblank & (261~320 ↑1,2,3,4 ↓5,6,7,8 )にする
- [ ] bg_fetch_en = n_vbalnk & !sp_fetch_enにする

```systemverilog
assign rendering_en = ppumask[3] & ppumask[4];
```

#### index

| BG pixel | Sprite pixel | Priority |     Output     |
| :------: | :----------: | :------: | :------------: |
|    0     |      0       |    X     | EXT in ($3F00) |
|    0     |     1-3      |    X     |     Sprite     |
|   1-3    |      0       |    X     |       BG       |
|   1-3    |     1-3      |    0     |     Sprite     |
|   1-3    |     1-3      |    1     |       BG       |

**Border region**
The border region displays the palette RAM entry selected by EXT input, either the data on the EXT pins if in input mode or 0 if in output mode. The first pixel on the left border is displayed with greyscale mode enabled. The border is affected by PPUMASK emphasis and greyscale effects.

**Rendering disabled**
With rendering disabled, both the picture and border regions display only EXT input. On PPUs that support CPU reads from palette RAM (RP2C02G, RP2C02H), the automatic greyscale effect on the first border pixel is disabled if a CPU palette read occurs at the exact same time.[1]

```systemverilog
// Priority mux
// ${bg_index} * {sp_index} -> $INDEX;

```

#### ★ pixel

When the PPU isn't rendering, its v register specifies the current VRAM address (and is output on the PPU's address pins). Whenever the low 14 bits of v point into palette RAM ($3F00-$3FFF), the PPU will continuously draw the color at that address instead of the EXT input, overriding the backdrop color. This is because the only way to access palette RAM is with this drawing mechanism.

PPUMASK emphasis and greyscale effects apply even with rendering disabled.

Addresses $3F04/$3F08/$3F0C are not used by the PPU when normally rendering (since the pattern values that would otherwise select those cells select the backdrop color instead). They can still be shown using the background palette direct access, explained below.

- [ ] index演算で対応する。$3F04/$3F08/$3F0C/$3F10/$3F14/$3F18/$3F1C = $3F00とする。

Addresses $3F10/$3F14/$3F18/$3F1C are mirrors of $3F00/$3F04/$3F08/$3F0C. Note that this goes for writing as well as reading. A symptom of not having implemented this correctly in an emulator is the sky being black in *Super Mario Bros.*, which writes the backdrop color through $3F10.

- [ ] pallet ramで対応する。

```systemverilog
// Pallet RAM
// $INDEX -> {pixel};

wire n_pram_cs = !((14'h3F00 <= pram_address) && (pram_address <= 14'h3FFF));
wire n_pram_we = ;
wire n_pram_oe = ;

logic [13:0] pram_address;
always_comb
    case({??})
        1'b1: pram_address = 14'h3F00 & {9'b0, index};
        1'b0: pram_address = ppu_addr_bus;
        default: bg_index_mux = 'x;
    endcase

tri [7:0] pram_data;
always_comb
    case({n_pram_cs, n_pram_we, n_pram_oe})
        3'bxxx: pram_data = ppu_data_bus_out;
        default: pram_data = 8'bz;
    endcase

assign pixel = pram_data;

Pallet_RAM Pallet_RAM(
    .clk(clk),
    .reset(reset),
    .n_cs(n_pram_cs),
    .n_we(n_pram_we),
    .n_oe(n_pram_oe),
    .address(pram_address[4:0]),
    .data(pram_data)
);
```

#### sprite0_hit

> 参考：https://www.nesdev.org/wiki/PPU_OAM#Internal_operation

```cpp
// sprite0_hit pseudo code
/*
input logic sprite0_scanline,
input logic sprite0_rendering,
output logic sprite0_hit
*/

// Sprite Zero Hit detection
if (bSpriteZeroHitPossible && bSpriteZeroBeingRendered)
{
    // Sprite zero is a collision between foreground and background
    // so they must both be enabled
    if (mask.render_background & mask.render_sprites)
    {
        // The left edge of the screen has specific switches to control
        // its appearance. This is used to smooth inconsistencies when
        // scrolling (since sprites x coord must be >= 0)
        if (~(mask.render_background_left | mask.render_sprites_left))
        {
            if (cycle >= 9 && cycle < 258)
            {
                status.sprite_zero_hit = 1;
            }
        }
        else
        {
            if (cycle >= 1 && cycle < 258)
            {
                status.sprite_zero_hit = 1;
            }
        }
    }
}
```



### 2-2. PPUバス入出力

```systemverilog
module PPU_BUS_IF(
    input logic clk, reset,
    output logic ale, n_rd, n_we,
    output logic [13:0] ppu_addr_bus,
    output logic [7:0] ppu_data_bus_out,
    // ale, n_rd, n_we
    input logic bg_fetch_en, sp_fetch_en,
    input logic ppu_bus_rd_en, ppu_bus_we_en,
    // ppu_addr_bus
    input logic rendering_en
);
```

#### ★ ale

ppu_lsb_busがPPUとカートリッジから同時に駆動されないようにするため、aleと!n_rd、!n_weが同時にアクティブにならないように注意する。

```systemverilog
assign ale = (n_rd && n_we);
```

#### ★ n_rd

- [ ] rendering_rd / ppu_bus_rdを作成し、n_rd = !(rendering_rd | ppu_bus_rd)とする
- [ ] rendering_rd は(n_vblank & rendering_en) = 0なら1で、それ以外なら hcntに応じた適切な値を出力するようにする。
- [ ] ppu_bus_rdは通常１で、ppu_bus_rd_enが成立していたら前回値を反転する。

```systemverilog
always_ff @(posedge clk)
    if (reset)
        n_rd <= 1'b1;
    else if (bg_fetch_en || sp_fetch_en || ppu_bus_rd_en)
        n_rd <= ~n_rd;
    else
        n_rd <= 1'b1;
```

#### ★ n_we

```systemverilog
always_ff @(posedge clk)
    if (reset)
        n_we <= 1'b1;
    else if (ppu_bus_we_en)
        n_we <= ~n_we;
    else
        n_we <= 1'b1;
```

#### ★ ppu_addr_bus

During frame rendering, provided rendering is enabled (i.e., when either background or sprite rendering is enabled in [$2001:3-4](https://www.nesdev.org/wiki/PPU_registers)), the value on the PPU address bus is as indicated in the descriptions above and in the frame timing diagram below. During VBlank and when rendering is disabled, the value on the PPU address bus is the current value of the [v](https://www.nesdev.org/wiki/PPU_scrolling) register.

```systemverilog
always_comb
    casex({rendering_en, sp_fetch_en, bg_fetch_en})
        3'b0xx: ppu_addr_bus = ppu_v;
        3'b100: ppu_addr_bus = ppu_v;
        3'b11x: ppu_addr_bus = sp_fetch_addr;
        3'b101: ppu_addr_bus = bg_fetch_addr;
        default: ppu_addr_bus = 'x;
    endcase
```

#### ★ ppu_data_bus_out

```systemverilog
always_comb
    casex({ppu_bus_we_en})
        1'b1: ppu_data_bus_out = reg_ppu_data_bus_out;
        1'b0: ppu_data_bus_out = 'z;
        default: ppu_data_bus_out = 'x;
    endcase
```



### 2-3. CPUバス入出力

```systemverilog
module CPU_BUS_IF(
    input logic clk, reset,
    input logic rw, n_dbe,
    input logic [2:0] cpu_addr_bus,
    output logic [7:0] cpu_data_bus_out
);
```

#### ★ cpu_data_bus_out

```systemverilog
// レジスタの処理を書き終わってから再度検討する。
always_comb
    casex({!n_dbe, !rw})
        2'b1x: cpu_data_bus_out = 'z;
        2'b01: cpu_data_bus_out = 'z;
        default: cpu_data_bus_out = 'x;
    endcase
```



## 3. 背景制御

To generate the background in the picture region, the PPU performs memory fetches on dots 321-336 and 1-256 of scanlines 0-239 and 261.

### 3-1. 背景データ取得

```systemverilog
module BG_fetch(
    input logic clk, reset,
    input logic bg_shift_en,
    input logic [8:0] hcnt, vcnt,
    input logic [7:0] ppu_data_bus_in,
    // for PPU_BUS_IF
    output logic bg_fetch_en,
    output logic [13:0] bg_fetch_addr,
    // for BG_shifter
    output logic bg_shift_en,
    output logic [7:0] bg_at, bg_lsb, bg_msb
);
```

#### bg_fetch_en

```systemverilog
// parameter
parameter VCNT_FETCH_BEG = 9'd0;
parameter VCNT_FETCH_END = 9'd239;
parameter VCNT_PREFETCH = 9'd261;

// backgrond fetch
wire bg_fetch_en = ((VCNT_FETCH_BEG <= vcnt) && (vcnt <= VCNT_FETCH_END)) || (vcnt == VCNT_PREFETCH);
```

#### bg_fetch_addr

PPU addresses within the pattern tables can be decoded as follows:

```
DCBA98 76543210
---------------
0HNNNN NNNNPyyy
|||||| |||||+++- T: Fine Y offset, the row number within a tile
|||||| ||||+---- P: Bit plane (0: lsb; 1: msb)
||++++-++++----- N: Tile number from name table
|+-------------- H: Half of pattern table (0: "left"; 1: "right")
+--------------- 0: Pattern table is at $0000-$1FFF
```



```systemverilog
// Address multiplexer
always_ff @(posedge clk)
    bg_fetch_addr <= bg_fetch_addr_mux;

logic [13:0] bg_fetch_addr_mux;
always_comb
    case(hcnt[2:1])
        2'b00: bg_fetch_addr_mux = bg_nt_addr;
        2'b01: bg_fetch_addr_mux = (bg_shift_en) ? bg_at_addr : bg_nt_addr;
        2'b10: bg_fetch_addr_mux = bg_lsb_addr;
        2'b11: bg_fetch_addr_mux = bg_msb_addr;
        default: bg_fetch_addr_mux = 'x;
    endcase

// Addressing
wire [13:0] bg_nt_addr = {2'b10, ppu_v[11:0]};
wire [13:0] bg_at_addr = {2'b10, ppu_v[11:10], 4'b1111, ppu_v[9:7], ppu_v[4:2]};
wire [13:0] bg_lsb_addr = {1'b0, ppuctrl[4], bg_nt, 1'b0, ppu_v[14:12]};
wire [13:0] bg_msb_addr = {1'b0, ppuctrl[4], bg_nt, 1'b1, ppu_v[14:12]};
```

#### bg_nt

```systemverilog
logic [7:0] bg_nt;
always_ff @(posedge clk)
    if (bg_fetch_en && hcnt[2:0] == 3'b010)
        bg_nt <= ppu_data_bus_in;
```

#### bg_at

```systemverilog
always_ff @(posedge clk)
    if (bg_fetch_en && hcnt[2:0] == 3'b100)
        bg_at <= ppu_data_bus_in;
```

#### bg_lsb

```systemverilog
always_ff @(posedge clk)
    if (bg_fetch_en && hcnt[2:0] == 3'b110)
        bg_lsb <= ppu_data_bus_in;
```

#### bg_msb

```systemverilog
assign bg_msb = ppu_data_bus_in;
```



### 3-2. 背景データ出力

> 参考１：https://www.nesdev.org/wiki/PPU_rendering#PPU_address_bus_contents
>
> 参考２：https://www.nesdev.org/wiki/PPU_memory_map

On every 8th dot in these background fetch regions (the same dot on which the coarse x component of v is incremented), the pattern and attributes data are transferred into registers used for producing pixel data.

To generate the background in the picture region, the PPU performs memory fetches on dots 321-336 and 1-256 of scanlines 0-239 and 261. On every dot in these background fetch regions, a 4-bit pixel is selected by the fine x register from the low 8 bits of the pattern and attributes shift registers, which are then shifted.

```systemverilog
module BG_shifter(
    input logic clk, reset,
    input logic bg_shift_en,
    input logic [14:0] ppu_v,
    input logic [2:0] ppu_x,
    input logic [7:0] bg_at, bg_lsb, bg_msb,
    // for BG_fetch
    output logic bg_shift_en,
    // for Renderer
    output logic [3:0] bg_index
);
```

#### bg_shift_en

```systemverilog
// parameter
parameter HCNT_SHIFT_BEG = 9'd1;
parameter HCNT_SHIFT_END = 9'd336;

// Shift enable
wire shift_en = ((HCNT_SHIFT_BEG <= hcnt) && (hcnt <= HCNT_SHIFT_END));
```

#### bg_index

```systemverilog
// Shift utility
wire trans_en = shift_en && (hcnt[2:0] == 3'b000);

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
// {bg_at} -> $AT_SHIFT;
logic [15:0] attr_msb_shift, attr_lsb_shift;
always_ff @(posedge clk)
    if (trans_en) begin
        attr_msb_shift <= {attr_msb_shift[14:7], 8{bg_at_mux[1]}};
        attr_lsb_shift <= {attr_lsb_shift[14:7], 8{bg_at_mux[0]}};
    end
    else if (shift_en) begin
        attr_msb_shift <= {attr_msb_shift[14:0], 1'b1};
        attr_lsb_shift <= {attr_lsb_shift[14:0], 1'b1};
    end

logic [1:0] bg_at_mux;
always_comb
    case({ppu_v[6], ppu_v[1]})
        2'b00: bg_at_mux = bg_at[1:0];
        2'b01: bg_at_mux = bg_at[3:2];
        2'b10: bg_at_mux = bg_at[5:4];
        2'b11: bg_at_mux = bg_at[7:6];
        default: bg_at_mux = 'x;
    endcase


// Fine_x select mux
// $SHIFTER * $REG_X -> $INDEX_BG;
always_ff @(posedge clk)
    bg_index <= bg_index_mux;

logic [3:0] bg_index_mux;
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
```





## 4. スプライト制御

### 4-1. OAM評価

Y座標のチェック方法：0 <= Scanline.Y座標 - Sprite.Y座標 < Sprite.高さ

```systemverilog
input logic sprite0_scanline,
input logic sprite0_rendering,
```

#### sprite0_scanline

```systemverilog
output logic sprite0_scanline,

logic sprite0_next_scanline
```

#### sprite0_rendering

```systemverilog
```



### 4-2. スプライト取得

```systemverilog
module SP_fetch(
    input logic clk, reset,
    input logic [8:0] hcnt, vcnt,
    input logic [7:0] ppu_data_bus_in,
    // for PPU_BUS_IF
    output logic sp_fetch_en,
    output logic [13:0] sp_fetch_addr,
    // for SP_
);
```

> 参考１：https://www.nesdev.org/wiki/PPU_sprite_evaluation
>
> 参考２：https://www.nesdev.org/wiki/PPU_sprite_priority

OAM -> Secondary OAM -> Sprite fetch -> Sprite output unit [7:0] -> sp_index

#### sp_fetch_en

Sprite evaluation occurs if either the sprite layer or background layer is enabled via $2001. Unless both layers are disabled, it merely hides sprite rendering.

```systemverilog

```

#### sp_fetch_addr

```systemverilog

```

#### oam2nd

```systemverilog

```



### 4-4. スプライト出力

#### sp_output_unit

Secondary OAMの4byteの属性、Sprite pattern data、hcntからindexデータを吐き出すユニット。
クロック毎にX座標を減算し、X座標が0~-7の間出力する

```systemverilog
module Sprite_output_unit(
    input logic clk, reset,
    input logic [8:0] hcnt, vcnt,
    input logic // Secondary OAM 4byte,
    input logic // Sprite pattern data,
    output logic [4:0] sp_index_raw
    // External section
);
```

#### sp_index

Sprite_output_unit#0~7を入力として、優先度の高いユニットからの入力を出力する。

```systemverilog
always_comb
```



## 5. 内部制御

### 5-1. レジスタ

```systemverilog
module Register(
    input clk, reset,
    input logic rw, n_dbe,
    input logic [2:0] cpu_addr_bus,
    input logic [7:0] cpu_data_bus_in,
    output logic ppu_bus_rd_en, ppu_bus_we_en,
    output logic [7:0] reg_cpu_data_out
);
```

#### ppu_bus_rd_en

```systemverilog

```

#### ppu_bus_we_en

```systemverilog

```

#### reg_ppu_data_bus_out

```systemverilog
// ロジックのイメージ
always_comb
    casex({})
        2'b1x: reg_ppu_data_bus_out = ppuctrl;
        2'b01: reg_ppu_data_bus_out = ppumask;
        2'b00: reg_ppu_data_bus_out = ppustatus;
        default: reg_ppu_data_bus_out = 'x;
    endcase
```



#### ppuctrl

```systemverilog
```

#### ppumask

```
7  bit  0
---- ----
BGRs bMmG
|||| ||||
|||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)
|||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
|||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
|||| +---- 1: Show background
|||+------ 1: Show sprites
||+------- Emphasize red (green on PAL/Dendy)
|+-------- Emphasize green (red on PAL/Dendy)
+--------- Emphasize blue
```

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



### 5-2. 内部レジスタ

The 15 bit registers *t* and *v* are composed this way during rendering:

```
yyy NN YYYYY XXXXX
||| || ||||| +++++-- coarse X scroll
||| || +++++-------- coarse Y scroll
||| ++-------------- nametable select
+++----------------- fine Y scroll
```



#### ppu_v

```systemverilog
```

#### ppu_t

```systemverilog
```

#### ppu_x

```systemverilog
```

#### ppu_w

```systemverilog
```



### 5-3. OAM書込み

#### oam_dma

```systemverilog
```



## 6. Utility

### 6-1. Pallet RAM

```systemverilog
module Pallet_RAM(
    input logic clk, reset,
    input logic n_cs, n_we, n_oe,
    input logic [4:0] address,
    inout logic [7:0] data
);
    
    logic [7:0] ram_data [2**5-1:0];
    
    /*
    logic [7:0] PPU_PRAM [2**5-1:0];
    always_ff @(posedge CLK)
        if (!n_cs && REG_PRAM_WR)
            if (PPU_ADDR[1:0] == 2'b00 )
                PPU_PRAM[{1'b0, PPU_ADDR[3:0]}] <= CPU_DATA;
            else
                PPU_PRAM[PPU_ADDR[4:0]] <= CPU_DATA;


    logic [7:0] PPU_PRAM_DATA;
    always_comb
        if (!n_cs && REG_PRAM_WR)
            PPU_PRAM_DATA = CPU_DATA;
        else if (!n_cs && PPU_RD)
            PPU_PRAM_DATA = PPU_PRAM[PPU_ADDR[4:0]];
        else if (RND_INDEX[1:0] == 2'b00)
            PPU_PRAM_DATA = PPU_PRAM[5'h00];
        else
            PPU_PRAM_DATA = PPU_PRAM[RND_INDEX];

    always_ff @(posedge CLK)
        PPU_PIXEL <= PPU_PRAM_DATA;

    */

endmodule
```

### 6-2. OAM

```systemverilog
module OAM(
    input logic clk, reset,
    input logic n_cs, n_we, n_oe,
    input logic [7:0] address,
    inout logic [7:0] data
);
    
    logic [7:0] ram_data [2**8-1:0];
    
endmodule
```

### 6-3. OAM2nd

```systemverilog
module OAM2nd(
    input logic clk, reset,
    input logic n_cs, n_we, n_oe,
    input logic [4:0] address,
    inout logic [7:0] data
);
    
    logic [7:0] ram_data [2**5-1:0];
    
endmodule
```

