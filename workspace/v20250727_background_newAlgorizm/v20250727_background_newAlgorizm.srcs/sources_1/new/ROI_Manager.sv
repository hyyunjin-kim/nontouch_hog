`timescale 1ns / 1ps

module ROI_Manager(
    input  logic       clk,
    input  logic       reset,
    input  logic       motion_mask,   // 움직임 감지 마스크 (1일 때 좌표 누적)
    input  logic [9:0] x,             // 현재 픽셀 X
    input  logic [9:0] y,             // 현재 픽셀 Y
    input  logic       frame_end,     // 프레임 종료 신호 (frame의 마지막 픽셀 도달 시)

    output logic [9:0] min_x,
    output logic [9:0] max_x,
    output logic [9:0] min_y,
    output logic [9:0] max_y,
    output logic       roi_valid      // 유효한 ROI 출력 신호 (frame_end와 동기)
);

    // 내부 레지스터
    logic [9:0] min_x_reg, max_x_reg;
    logic [9:0] min_y_reg, max_y_reg;

    // ROI 추적 logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            min_x_reg <= 10'd319;
            max_x_reg <= 10'd0;
            min_y_reg <= 10'd239;
            max_y_reg <= 10'd0;
            roi_valid <= 1'b0;
        end else begin
            // motion_mask가 있을 때만 좌표 누적
            if (motion_mask) begin
                if (x < min_x_reg) min_x_reg <= x;
                if (x > max_x_reg) max_x_reg <= x;
                if (y < min_y_reg) min_y_reg <= y;
                if (y > max_y_reg) max_y_reg <= y;
            end

            // 프레임이 끝날 때 ROI 값 출력 및 초기화
            if (frame_end) begin
                min_x    <= min_x_reg;
                max_x    <= max_x_reg;
                min_y    <= min_y_reg;
                max_y    <= max_y_reg;
                roi_valid <= 1'b1;

                // 초기화 (다음 프레임용)
                min_x_reg <= 10'd319;
                max_x_reg <= 10'd0;
                min_y_reg <= 10'd239;
                max_y_reg <= 10'd0;
            end else begin
                roi_valid <= 1'b0;
            end
        end
    end

endmodule
