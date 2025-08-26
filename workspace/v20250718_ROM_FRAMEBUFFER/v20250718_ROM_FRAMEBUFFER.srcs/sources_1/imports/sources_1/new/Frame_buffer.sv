`timescale 1ns / 1ps

module Frame_buffer #(
    parameter int H = 320,
    parameter int V = 240
)(
    // write side
    input  logic        rst,
    input  logic        wclk,
    input  logic        we,
    input  logic [$clog2(H*V)-1:0] wAddr,
    input  logic [11:0] wData,
    // read side
    input  logic        rclk,
    input  logic        oe,
    input  logic [$clog2(H*V)-1:0] rAddr,
    output logic [11:0] rData
);

    logic [11:0] mem [0:H*V-1];

    // write
    always_ff @(posedge wclk) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end
    // read
    always_ff @(posedge rclk) begin
        if (oe) begin
            rData <= mem[rAddr];
        end
    end
endmodule