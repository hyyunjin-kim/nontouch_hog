`timescale 1ns / 1ps

module sobel_filter (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] gray_in,       // 입력: 8비트 그레이스케일 영상
    //input  logic [7:0] threshold,     // 소벨 임계값
    input logic sw_upscale,
    input  logic [9:0] x_pixel,       // 현재 x좌표
    input  logic [9:0] y_pixel,       // 현재 y좌표
    output logic [11:0] sobel_out      // 출력: 엣지 결과
);

    localparam IMG_WIDTH  = 320;
    localparam IMG_HEIGHT = 240;
    /*logic [9:0] img_width, img_height;

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
    localparam threshold =20;

    // 라인 버퍼: 3줄 윈도우를 만들기 위한 버퍼
    logic [7:0] line_top[0:IMG_WIDTH-1];
    logic [7:0] line_mid[0:IMG_WIDTH-1];

    // 3x3 윈도우 픽셀 값
    logic [7:0] p11, p12, p13;
    logic [7:0] p21, p22, p23;
    logic [7:0] p31, p32, p33;

    // 유효 위치를 위한 딜레이 및 플래그
    logic [2:0] valid_shift;
    logic [9:0] x_delay[0:2];
    logic [9:0] y_delay[0:2];
    logic [9:0] x_pixel_d;

    logic signed [10:0] gx, gy;
    logic [10:0] G_abs;

    integer i;

    // 화면 범위 내일 때만 display_enable
    logic display_enable;
    assign display_enable = (x_pixel < IMG_WIDTH) && (y_pixel < IMG_HEIGHT);

    // x_pixel 딜레이: 데이터 정렬을 위한 -2 보정
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

    // 라인 버퍼에 픽셀 저장
    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < IMG_WIDTH; i++) begin
                line_top[i] <= 0;
                line_mid[i] <= 0;
            end
        end else if (display_enable) begin
            line_top[x_pixel_d] <= line_mid[x_pixel_d];
            line_mid[x_pixel_d] <= gray_in;
        end
    end

    // 3x3 윈도우 시프트 및 위치 유효성 관리
    always_ff @(posedge clk) begin
        if (reset) begin
            {p11, p12, p13, p21, p22, p23, p31, p32, p33} <= 0;
            valid_shift <= 0;
        end else if (display_enable) begin
            // 윈도우 시프트: 한 줄씩 이동
            p13 <= line_top[x_pixel_d];
            p12 <= p13;
            p11 <= p12;

            p23 <= line_mid[x_pixel_d];
            p22 <= p23;
            p21 <= p22;

            p33 <= gray_in;
            p32 <= p33;
            p31 <= p32;

            // 좌표 딜레이
            x_delay[0] <= x_pixel;
            y_delay[0] <= y_pixel;
            for (i = 1; i < 3; i++) begin
                x_delay[i] <= x_delay[i-1];
                y_delay[i] <= y_delay[i-1];
            end

            // 윈도우가 유효한 영역(가장자리 제외)에서만 연산
            valid_shift <= {valid_shift[1:0], (x_pixel >= 2 && x_pixel < IMG_WIDTH-1 && y_pixel >= 2)};
        end else begin
            valid_shift <= {valid_shift[1:0], 1'b0};
        end
    end

    // Sobel 계산 및 임계값 적용
    always_ff @(posedge clk) begin
        if (reset) begin
            gx        <= 0;
            gy        <= 0;
            G_abs     <= 0;
            sobel_out <= 0;
        end else if (valid_shift[1]) begin
            // Gx, Gy 계산
            gx = (p11 + 2*p21 + p31) - (p13 + 2*p23 + p33);
            gy = (p11 + 2*p12 + p13) - (p31 + 2*p32 + p33);

            // 절댓값 합산
            G_abs = (gx[10] ? -gx : gx) + (gy[10] ? -gy : gy);

            // 임계값 적용 (binary edge map)
            sobel_out <= (G_abs > threshold) ? 12'hFFF : 12'h000;
        end else begin
            sobel_out <= 12'h000;
        end
    end

endmodule
