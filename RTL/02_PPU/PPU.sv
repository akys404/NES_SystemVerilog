module PPU(
    input logic clk, reset,

    // control signal
    output logic ale, n_rd, n_we, n_int, n_dbe,
    output logic [7:0] pixel,

    // data bus
    input logic [2:0] cpu_addr_bus,
    inout logic [7:0] cpu_data_bus,
    output logic [13:0] ppu_addr_bus,
    inout logic [7:0] ppu_data_bus,
);

endmodule