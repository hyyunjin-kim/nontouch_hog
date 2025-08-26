`timescale 1ns / 1ps

module Gaussian (
    input  logic        clk,
    input  logic        reset,
    input  logic [11:0] pixel_in,   // 입력 픽셀 (12비트)
    input  logic [16:0] addr,       // 현재 픽셀 주소 (0부터 IMG_WIDTH×IMG_HEIGHT–1)
    output logic [11:0] Gaussian_out    // 가우시안 필터링 결과 (12비트)
);

    // ==========================================================
    // 1) 이미지 해상도 정의 (현재 320×240 고정)
    //    만약 다른 해상도를 쓸 경우, IMG_WIDTH / IMG_HEIGHT 값을 수정
    // ==========================================================
    localparam int IMG_WIDTH  = 320;
    localparam int IMG_HEIGHT = 240;

    // ==========================================================
    // 2) 주소(addr) → (x_pixel, y_pixel) 계산
    //    - x_pixel = addr % IMG_WIDTH
    //    - y_pixel = addr / IMG_WIDTH
    //    이 연산은 합성 시 상수 나누기/나머지로 처리됨
    // ==========================================================
    logic [9:0] x_pixel;
    logic [9:0] y_pixel;

    always_comb begin
        y_pixel = addr / IMG_WIDTH;
        x_pixel = addr - (y_pixel * IMG_WIDTH);
    end

    // ==========================================================
    // 3) 라인 버퍼: 3줄 윈도우를 만들기 위한 버퍼 선언
    //    - 최대 가로 픽셀 수 = IMG_WIDTH(320)
    //    - 각 버퍼는 입력 픽셀(bit width 12) 저장
    // ==========================================================
    logic [11:0] line_top [0:IMG_WIDTH-1];
    logic [11:0] line_mid [0:IMG_WIDTH-1];

    // ==========================================================
    // 4) 3×3 윈도우 픽셀 레지스터
    //      p11, p12, p13: 윈도우 상단 행 (왼쪽→오른쪽)
    //      p21, p22, p23: 중간 행
    //      p31, p32, p33: 하단 행
    // ==========================================================
    logic [11:0] p11, p12, p13;
    logic [11:0] p21, p22, p23;
    logic [11:0] p31, p32, p33;

    // ==========================================================
    // 5) 유효 위치 판정 및 좌표 딜레이용 레지스터
    //    - x_pixel_d: x_pixel을 두 사이클 지연시켜 line buffer와 정렬
    //    - valid_shift: 3×3 윈도우가 완전히 구성된 뒤 한 사이클 뒤 활성화
    // ==========================================================
    logic [9:0]  x_pixel_d;
    logic [2:0]  valid_shift;
    logic [9:0]  x_delay [0:2];
    logic [9:0]  y_delay [0:2];

    // ==========================================================
    // 6) 컨볼루션 합(sum_conv)
    //    3×3 가우시안 커널 [1 2 1; 2 4 2; 1 2 1]
    //    최대 합 = (픽셀 최댓값 4095 * 16) = 65520 → 16비트 필요
    //    sum_conv은 16비트로 선언하되, 최종 출력은 >>4 후 12비트
    // ==========================================================
    logic [15:0] sum_conv;

    integer i;

    // ==========================================================
    // 7) 화면 범위 내에서만 작동하도록 하는 디스플레이 enable
    //    - IMG_WIDTH×IMG_HEIGHT 내의 addr일 때 true
    // ==========================================================
    logic display_enable;
    assign display_enable = (x_pixel < IMG_WIDTH) && (y_pixel < IMG_HEIGHT);

    // ==========================================================
    // 8) x_pixel 딜레이: (x_pixel >= 2) 일 때만 -2 보정
    // ==========================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            x_pixel_d <= 0;
        end else begin
            if (x_pixel >= 2)
                x_pixel_d <= x_pixel - 2;
            else
                x_pixel_d <= 0;
        end
    end

    // ==========================================================
    // 9) 라인 버퍼에 픽셀 저장
    //    - 매 클록마다 display_enable일 때
    //       line_top[x_pixel_d] <= 이전에 저장된 line_mid[x_pixel_d]
    //       line_mid[x_pixel_d] <= 현재 입력 pixel_in
    // ==========================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < IMG_WIDTH; i++) begin
                line_top[i] <= 0;
                line_mid[i] <= 0;
            end
        end else if (display_enable) begin
            line_top[x_pixel_d] <= line_mid[x_pixel_d];
            line_mid[x_pixel_d] <= pixel_in;
        end
    end

    // ==========================================================
    // 10) 3×3 윈도우 시프트 및 유효성 관리
    //     - p13 ← line_top[x_pixel_d], p12 ← 이전 p13, p11 ← 이전 p12
    //     - p23 ← line_mid[x_pixel_d], p22 ← 이전 p23, p21 ← 이전 p22
    //     - p33 ← pixel_in,         p32 ← 이전 p33, p31 ← 이전 p32
    //     - valid_shift: (x_pixel ≥ 2 && x_pixel < IMG_WIDTH-1 && y_pixel ≥ 2)이면 1
    // ==========================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            {p11, p12, p13, p21, p22, p23, p31, p32, p33} <= 0;
            valid_shift <= 0;
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
            p33 <= pixel_in;
            p32 <= p33;
            p31 <= p32;

            // 좌표 딜레이
            x_delay[0] <= x_pixel;
            y_delay[0] <= y_pixel;
            for (i = 1; i < 3; i++) begin
                x_delay[i] <= x_delay[i-1];
                y_delay[i] <= y_delay[i-1];
            end

            // 3×3 창이 채워지는 유효 영역 (가장자리 제외)
            valid_shift <= { valid_shift[1:0],
                             (x_pixel >= 2 && x_pixel < IMG_WIDTH-1 && y_pixel >= 2) };
        end else begin
            valid_shift <= { valid_shift[1:0], 1'b0 };
        end
    end

    // ==========================================================
    // 11) 가우시안 컨볼루션 및 출력
    //     - sum_conv = p11 + 2*p12 + p13
    //                + 2*p21 + 4*p22 + 2*p23
    //                + p31 + 2*p32 + p33
    //     - 최종 출력 = sum_conv >> 4  (16으로 나누기)
    // ==========================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            sum_conv  <= 0;
            Gaussian_out  <= 0;
        end else if (valid_shift[1]) begin
            // 3×3 가중치 합산 (16비트 레지스터에 계산)
            sum_conv <= (p11       + (p12 << 1) + p13)
                      + ((p21 << 1) + (p22 << 2) + (p23 << 1))
                      + (p31       + (p32 << 1) + p33);

            // 16으로 나눈 뒤 상위 12비트 출력
            Gaussian_out <= sum_conv[15:4];
        end else begin
            Gaussian_out <= 12'h000;
        end
    end

endmodule
