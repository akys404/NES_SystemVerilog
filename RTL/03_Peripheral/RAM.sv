// ==========================================================
//                 Sprite SRAMの実装
// ==========================================================
module SP_RAM(
    input logic cs, n_we,
    input logic [10:0] addr_bus,
    inout logic [7:0] data_bus
);

endmodule


// ==========================================================
//                 Background SRAMの実装
// ==========================================================
module BG_RAM(
    input logic n_cs, n_we, n_oe,
    input logic [10:0] addr_bus,
    inout logic [7:0] data_bus
);

endmodule
