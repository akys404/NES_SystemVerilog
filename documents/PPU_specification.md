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

    // External section
    input logic clk, reset,
    output logic n_int,
    output logic [7:0] pixel,
    output logic [8:0] hcnt, vcnt
)
    
endmodule
```

#### n_int

```systemverilog
logic 
```

#### pixel

```systemverilog
logic 
```

#### hcnt, vcnt

```systemverilog
// parameter
parameter HCNTMAX = 9'd340;
parameter VCNTMAX = 9'd261;

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
	else if (vcnt == VCNTMAX, hcnt == frameend)
        hcnt <= 9'd0;
	else if (hcnt == HCNTMAX)
        hcnt <= 9'd0;
    else
        hcnt <= hcnt + 9'd1;

// [8:0] vcnt
always_ff @(posedge clk)
	if (reset)
        vcnt <= 9'd0;
	else if (vcnt == VCNTMAX, hcnt == frameend)
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

