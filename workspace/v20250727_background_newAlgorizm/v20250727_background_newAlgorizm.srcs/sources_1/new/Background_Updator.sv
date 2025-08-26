`timescale 1ns / 1ps

module Background_Updator(
    input logic clk,
    input logic reset,
    input logic store_background,  // 배경 저장 트리거
    input logic [9:0] x,
    input logic [9:0] y,
    input logic [7:0] gray_in,     // 현재 프레임 입력 
    output logic [7:0] bg_pixel_out  // 읽은 배경 출력 (옵션)
    );

    logic [7:0] background_mem [0:320*240-1];
    logic [16:0] addr;

    assign addr = y * 320 + x;

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
    ////////////////////////////////////////////////////////        
        end else if (store_background) begin
            background_mem[addr] <= gray_in;
        end
    end

    assign bg_pixel_out = background_mem[addr];

endmodule
