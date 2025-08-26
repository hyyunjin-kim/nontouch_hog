`timescale 1ns / 1ps

module Diff_comparator #(
    parameter THRESHOLD = 8'd25
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] gray_curr,    // 실시간 입력 프레임
    input  logic [7:0] gray_back,    // 저장된 배경 프레임
    output logic       motion_mask,  // 이진 마스크 (1: 움직임 있음)
    output logic       test_led      // 디버깅용 (LED toggle 등)
);

    logic [7:0] diff;

    // 절댓값 차이 계산: 조합 로직 (동기화 필요 없음)
    assign diff = (gray_curr > gray_back) ? 
                  (gray_curr - gray_back) : 
                  (gray_back - gray_curr);

    // 동기화된 threshold 비교
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            motion_mask <= 1'b0;
            test_led    <= 1'b0;
        end else begin
            motion_mask <= (diff > THRESHOLD);
            test_led    <= (diff > THRESHOLD);
            // 또는 test_led <= test_led ^ (diff > THRESHOLD); // 토글 버전
        end
    end

endmodule
