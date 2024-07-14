module PPU(
    input logic clk, reset,

    // control signal
    output logic ale, n_rd, n_we, n_int, n_dbe,
    output logic [7:0] pixel,
    output logic [8:0] hcnt, vcnt,

    // data bus
    input logic [2:0] cpu_addr_bus,
    inout logic [7:0] cpu_data_bus,
    output logic [5:0] ppu_msb_bus,
    inout logic [7:0] ppu_lsb_bus
);

endmodule