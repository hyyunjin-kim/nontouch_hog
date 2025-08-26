`timescale 1ns / 1ps

module Frame_AddressGen(
    input logic clk,
    input logic reset,
    input logic valid_in,    // 유효한 데이터가 들어오는 시점만 카운트
    output logic [9:0] x,
    output logic [9:0] y,
    output logic frame_end   // frame 마지막 위치에서 high 
    );

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            x <= 10'd0;
            y <= 10'd0;
            frame_end <= 1'b0;
        end
        else if (valid_in) begin
            if(x == 319) begin
                x <= 0;
                if(y == 239) begin
                    y <= 0;
                    frame_end <= 1'b1; // 마지막 픽셀
                end else begin
                    y <= y + 1;
                    frame_end <= 1'b0;
                end
            end
            else begin
                    x <= x + 1;
                    frame_end <= 1'b0;
                end
            end
        end
endmodule
