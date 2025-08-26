`timescale 1ns / 1ps

module GraySharpen (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] gray_in,       // 입력: 8비트 그레이스케일 영상
    input  logic [9:0] x_pixel,       // 현재 x좌표
    input  logic [9:0] y_pixel,       // 현재 y좌표
    output logic [11:0] sharpen_out   // 출력: 샤프닝 결과 (4비트 R, 4비트 G, 4비트 B)
);

    //--------------------------------------------------------------------------
    // 1) 이미지 크기 설정 (기본 320×240). 스케일 모드를 지원하려면 아래 img_width/img_height 주석 해제
    //--------------------------------------------------------------------------
    localparam IMG_WIDTH  = 320;
    localparam IMG_HEIGHT = 240;
    /*
    logic [9:0] img_width, img_height;
    always_comb begin
        if (sw_upscale) begin
            img_width  = 320;
            img_height = 240;
        end else begin
            img_width  = 160;
            img_height = 120;
        end
    end
    */

    //--------------------------------------------------------------------------
    // 2) 내부에서 사용할 4×4비트 그레이 값 임계(샤프닝 강도) - 예시로 20 고정
    //--------------------------------------------------------------------------
    localparam logic [7:0] threshold = 8'd20;

    //--------------------------------------------------------------------------
    // 3) 라인 버퍼: 3줄 윈도우를 만들기 위한 버퍼
    //    - IMG_WIDTH 크기(320)만큼 할당, 각 요소는 4비트(상위 그레이스케일 비트) 저장
    //--------------------------------------------------------------------------
    logic [3:0] line_top [0:IMG_WIDTH-1];
    logic [3:0] line_mid [0:IMG_WIDTH-1];

    //--------------------------------------------------------------------------
    // 4) 3×3 윈도우 픽셀 값 (4비트씩)
    //--------------------------------------------------------------------------
    logic [3:0] p11, p12, p13;
    logic [3:0] p21, p22, p23;
    logic [3:0] p31, p32, p33;

    //--------------------------------------------------------------------------
    // 5) 유효 위치를 위한 딜레이 및 플래그
    //    - x_pixel_d: x_pixel을 두 사이클 지연시켜서 라인 버퍼 인덱싱 정렬
    //    - valid_shift: 3×3 창이 완성된 뒤 한 사이클 뒤에 활성화
    //--------------------------------------------------------------------------
    logic [2:0] valid_shift;
    logic [9:0] x_delay [0:2];
    logic [9:0] y_delay [0:2];
    logic [9:0] x_pixel_d;

    //--------------------------------------------------------------------------
    // 6) 샤프닝 연산 중간값
    //    - signed 형식: 5×4비트(최대 75)와 이웃 픽셀 4개 합(최대 60) 차이 계산
    //    - 범위: [-60 .. +75], 최종 0~15로 클램핑
    //--------------------------------------------------------------------------
    logic signed [7:0] sharpen_val;
    logic [3:0] sharp_val;

    integer i;

    //--------------------------------------------------------------------------
    // 7) 화면 범위 내일 때만 동작하도록 하는 display_enable
    //--------------------------------------------------------------------------
    logic display_enable;
    assign display_enable = (x_pixel < IMG_WIDTH) && (y_pixel < IMG_HEIGHT);

    //--------------------------------------------------------------------------
    // 8) x_pixel 딜레이: 데이터 정렬을 위한 -2 보정
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            x_pixel_d <= 10'd0;
        end else begin
            if (x_pixel >= 2)
                x_pixel_d <= x_pixel - 2;
            else
                x_pixel_d <= 10'd0;
        end
    end

    //--------------------------------------------------------------------------
    // 9) 라인 버퍼에 픽셀 저장
    //    - 출력 색상은 gray_in[7:4] (상위 4비트)만 사용
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < IMG_WIDTH; i++) begin
                line_top[i] <= 4'd0;
                line_mid[i] <= 4'd0;
            end
        end else if (display_enable) begin
            line_top[x_pixel_d] <= line_mid[x_pixel_d];
            line_mid[x_pixel_d] <= gray_in[7:4];
        end
    end

    //--------------------------------------------------------------------------
    // 10) 3×3 윈도우 시프트 및 위치 유효성 관리
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            {p11, p12, p13,
             p21, p22, p23,
             p31, p32, p33} <= 9'h000;
            valid_shift        <= 3'b000;
        end else if (display_enable) begin
            // 상단 행
            p13 <= line_top[x_pixel_d];
            p12 <= p13;
            p11 <= p12;
            // 중단 행
            p23 <= line_mid[x_pixel_d];
            p22 <= p23;
            p21 <= p22;
            // 하단 행
            p33 <= gray_in[7:4];
            p32 <= p33;
            p31 <= p32;

            // 좌표 딜레이 저장
            x_delay[0] <= x_pixel;
            y_delay[0] <= y_pixel;
            for (i = 1; i < 3; i++) begin
                x_delay[i] <= x_delay[i-1];
                y_delay[i] <= y_delay[i-1];
            end

            // 3×3 윈도우가 유효해지는 구간 (테두리 제외)
            valid_shift <= { valid_shift[1:0],
                             (x_pixel >= 2 && x_pixel < IMG_WIDTH-1 && y_pixel >= 2) };
        end else begin
            valid_shift <= { valid_shift[1:0], 1'b0 };
        end
    end

    //--------------------------------------------------------------------------
    // 11) Sharpen 계산 및 출력
    //     - sharpen_val = (5 × 중심) - (상 + 하 + 좌 + 우)
    //     - 클램핑: 0 ~ 15
    //     - sharpen_out = {sharp_val, sharp_val, sharp_val}  (12비트, R/G/B 공통)
    //--------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            sharpen_out <= 12'd0;
        end else if (valid_shift[1]) begin
            // 중심값 p22, 상(p12), 하(p32), 좌(p21), 우(p23) 사용
            sharpen_val = (5 * p22) - (p12 + p21 + p23 + p32);

            // 클램핑
            if (sharpen_val < 0)
                sharp_val = 4'd0;
            else if (sharpen_val > 4'd15)
                sharp_val = 4'd15;
            else
                sharp_val = sharpen_val[3:0];

            // 12비트 출력: R=G=B=sharp_val
            sharpen_out <= { sharp_val, sharp_val, sharp_val };
        end else begin
            sharpen_out <= 12'd0;
        end
    end

endmodule
