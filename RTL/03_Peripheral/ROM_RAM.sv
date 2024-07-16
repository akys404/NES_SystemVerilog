// ==========================================================
//                 Sprite SRAM
// ==========================================================
module SP_RAM(
    input logic cs, n_we,
    input logic [10:0] addr_bus,
    inout logic [7:0] data_bus
);

endmodule


// ==========================================================
//                 Background SRAM
// ==========================================================
module BG_RAM(
    input logic n_cs, n_we, n_oe,
    input logic [10:0] addr_bus,
    inout logic [7:0] data_bus
);

endmodule


// ==========================================================
//                 VGA CROM
// ==========================================================
module CROM(
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
