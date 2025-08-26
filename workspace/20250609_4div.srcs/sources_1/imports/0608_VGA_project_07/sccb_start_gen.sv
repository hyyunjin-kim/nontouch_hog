`timescale 1ns / 1ps
module sccb_start_gen (
    input  logic clk,
    input  logic reset,
    output logic sccb_start
);
    logic [3:0] counter;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            counter <= 0;
        else if (counter < 10)
            counter <= counter + 1;
    end

    assign sccb_start = (counter == 1);
endmodule

module xclk_gen (
    input  logic clk,
    input  logic reset,
    output logic xclk
);
    logic [2:0] x_counter;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            x_counter <= 0;
            xclk <= 0;
        end else begin
            if (x_counter == 3) begin
                x_counter <= 0;
                xclk <= 1;
            end else begin
                x_counter <= x_counter + 1;
                xclk <= 0;
            end
        end
    end
endmodule