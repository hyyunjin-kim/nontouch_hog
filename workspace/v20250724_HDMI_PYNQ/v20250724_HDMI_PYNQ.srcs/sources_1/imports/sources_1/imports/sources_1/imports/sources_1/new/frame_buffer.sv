`timescale 1ns / 1ps

module frame_buffer (
    input  wire        reset,     // Active‐High 비동기 리셋
    // write side
    input  wire        wclk,      // OV7670 PCLK
    input  wire        we,
    input  wire [16:0] wAddr,
    input  wire [15:0] wData,
    // read side
    input  wire        rclk,      // 읽기 클럭(=VGA 클럭)
    input  wire        oe,        // 읽기 이네이블
    input  wire [16:0] rAddr,
    output reg  [15:0] rData      // 읽어온 데이터
    
);

    // 320×240 = 76800 픽셀, 각 픽셀당 16비트(RGB565)
    (* ram_style = "block" *) reg [15:0] mem [0:320*240-1];

    //========================================================
    // 1) 쓰기 포트 (비동기 리셋 + posedge wclk)
    //========================================================

    always_ff @( posedge wclk ) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end

    //========================================================
    // 2) 읽기 포트 (비동기 리셋 + posedge rclk)
    //========================================================
    always_ff @(posedge rclk or posedge reset) begin
        if (reset) begin
            rData <= 16'd0;
        end else if (oe) begin
            rData <= mem[rAddr];
        end else begin
            rData <= rData;  // 읽기 이네이블이 없으면 그대로 유지
        end
    end

endmodule
