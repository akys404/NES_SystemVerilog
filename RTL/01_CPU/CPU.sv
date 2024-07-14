module CPU(
    input logic clk, reset,

    // control signal
    input logic n_irq, n_nmi,
    output logic m2, rw,

    // data bus
    output logic [15:0] addr_bus,
    inout logic [7:0] data_bus
);

endmodule