`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/27 14:23:03
// Design Name: 
// Module Name: rgb2gray
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rgb2gray(
        input logic [4:0] red_in,
        input logic [5:0] green_in,
        input logic [4:0] blue_in,

        output logic [7:0] gray_out
    );

    logic [11:0] red_to_gray;     // 5bit * 7bit = 12bit 필요
    logic [13:0] green_to_gray;   // 6bit * 8bit = 14bit 필요
    logic [9:0]  blue_to_gray;    // 5bit * 6bit = 10bit 필요

    logic [14:0] gray_sum;        // 15bit 필요: 12 + 14 + 10 → 15bit 안전
    logic [7:0]  gray8;        

    assign red_to_gray   = red_in   * 12'd77;
    assign green_to_gray = green_in * 14'd150;
    assign blue_to_gray  = blue_in * 10'd29;

    assign gray_sum = red_to_gray + green_to_gray + blue_to_gray;
    assign gray_out   = gray_sum[14:7];  // 상
endmodule
