`timescale 1ns / 1ps

module camera_hdmi_top (
    input  logic        pixel_clk, //25MHz
    input  logic        serial_clk, // 250MHz
    input  logic        rst,

    // Camera input (from OV7670 RGB565 interface)
    input  logic [15:0] rgb565_in,
    input  logic        hsync,
    input  logic        vsync,
    input  logic        vde,  // video data enable

    // TMDS HDMI Output
    output logic        tmds_clk_p,  // HDMI TMDS 클럭 채널
    output logic        tmds_clk_n,
    output logic [2:0]  tmds_data_p, // HDMI TMDS 데이터 채널(R,G,B 각각)
    output logic [2:0]  tmds_data_n,

    output logic         hdmi_out_en
);

    // Internal signals
    logic [23:0] rgb888;
    logic        hsync_out, vsync_out, vde_out;
    logic [9:0]  tmds_red, tmds_green, tmds_blue;

    assign hdmi_out_en = 1'b1;

    // Step 1: Convert RGB565 to RGB888
    rgb565_to_rgb888 rgb_conv_inst (
        .pixel_clk (pixel_clk),
        .rgb565_in (rgb565_in),
        .hsync     (hsync),
        .vsync     (vsync),
        .vde       (vde),
        .rgb888_out(rgb888),
        .hsync_out (hsync_out),
        .vsync_out (vsync_out),
        .vde_out   (vde_out)
    );

    // Step 2: TMDS Encoding for each channel
    tmds_encoder enc_r (
        .clk      (pixel_clk),
        .rst      (rst),
        .data_in  (rgb888[23:16]),
        .c0       (1'b0),
        .c1       (1'b0),
        .vde      (vde_out),
        .data_out (tmds_red)
    );

    tmds_encoder enc_g (
        .clk      (pixel_clk),
        .rst      (rst),
        .data_in  (rgb888[15:8]),
        .c0       (1'b0),
        .c1       (1'b0),
        .vde      (vde_out),
        .data_out (tmds_green)
    );

    tmds_encoder enc_b (
        .clk      (pixel_clk),
        .rst      (rst),
        .data_in  (rgb888[7:0]),
        .c0       (hsync_out),
        .c1       (vsync_out),
        .vde      (vde_out),
        .data_out (tmds_blue)
    );

    // Step 3: Serialize each TMDS channel
    output_serdes ser_r (
        .pixel_clk (pixel_clk),
        .serial_clk(serial_clk),
        .data_in   (tmds_red),
        .rst       (rst),
        .data_p    (tmds_data_p[2]),
        .data_n    (tmds_data_n[2])
    );

    output_serdes ser_g (
        .pixel_clk (pixel_clk),
        .serial_clk(serial_clk),
        .data_in   (tmds_green),
        .rst       (rst),
        .data_p    (tmds_data_p[1]),
        .data_n    (tmds_data_n[1])
    );

    output_serdes ser_b (
        .pixel_clk (pixel_clk),
        .serial_clk(serial_clk),
        .data_in   (tmds_blue),
        .rst       (rst),
        .data_p    (tmds_data_p[0]),
        .data_n    (tmds_data_n[0])
    );

    // Step 4: TMDS Clock output
    tmds_clk_output clk_out_inst (
        .pixel_clk (pixel_clk),
        .serial_clk(serial_clk),
        .rst       (rst),
        .clk_p     (tmds_clk_p),
        .clk_n     (tmds_clk_n)
    );

endmodule

module rgb565_to_rgb888 (
    input  logic         pixel_clk,
    input  logic [15:0]  rgb565_in,
    input  logic         hsync,
    input  logic         vsync,
    input  logic         vde,

    output logic [23:0]  rgb888_out,
    output logic         hsync_out,
    output logic         vsync_out,
    output logic         vde_out
);

    logic [7:0] r8, g8, b8;

    // RGB565 to RGB888 변환
    always_ff @(posedge pixel_clk) begin
        // R: 5bit → 8bit
        r8 <= {rgb565_in[15:11], rgb565_in[15:13]}; // 상위 + 복사
        // G: 6bit → 8bit
        g8 <= {rgb565_in[10:5],  rgb565_in[10:9]};
        // B: 5bit → 8bit
        b8 <= {rgb565_in[4:0],   rgb565_in[4:2]};

        rgb888_out <= {r8, g8, b8};

        // 동기 신호 그대로 전달
        hsync_out <= hsync;
        vsync_out <= vsync;
        vde_out   <= vde;
    end

endmodule

module tmds_encoder (
    input  logic        clk,
    input  logic        rst,
    input  logic [7:0]  data_in,
    input  logic        c0, c1,   // hsync, vsync
    input  logic        vde,      // video data enable
    output logic [9:0]  data_out
);
    // Internal registers
    logic [3:0] ones_count;
    logic [8:0] q_m;
    logic [9:0] q_out;
    logic disparity;
    logic [7:0] din;
    logic       vde_r;

    always_ff @(posedge clk or posedge rst) begin
            if (rst) begin
                data_out <= 10'b0;
                disparity <= 1'b0;
            end else begin
                din <= data_in;
                vde_r <= vde;

                if (vde_r) begin
                    // Step 1: Transition Minimize (XOR/XNOR) → q_m[0:8]
                    q_m[0] = din[0];
                    for (int i = 1; i < 8; i++) begin
                        q_m[i] = q_m[i-1] ^ din[i];
                    end

                    // Count number of 1s in din
                    ones_count = 0;
                    for (int i = 0; i < 8; i++) begin
                        ones_count += din[i];
                    end

                    // Step 2: Disparity Control (8b to 10b encoding)
                    if ((ones_count > 4) || ((ones_count == 4) && (din[0] == 0))) begin
                        q_m[8] = 1'b0;
                        q_out = {1'b1, ~q_m[8:0]};
                    end else begin
                        q_m[8] = 1'b1;
                        q_out = {1'b0, q_m[8:0]};
                    end

                    data_out <= q_out;
                end else begin
                    // During blanking (vde=0), send control codes
                    case ({c1, c0})
                        2'b00: data_out <= 10'b1101010100; // Control 0
                        2'b01: data_out <= 10'b0010101011; // Control 1
                        2'b10: data_out <= 10'b0101010100; // Control 2
                        2'b11: data_out <= 10'b1010101011; // Control 3
                    endcase
                end
            end
        end
endmodule

module output_serdes (
    input  logic         pixel_clk,     // TMDS 데이터 입력 기준 클럭 (1x, 예: 25MHz, 74.25MHz 등)
    input  logic         serial_clk,    // TMDS 직렬 출력용 빠른 클럭 (pixel_clk의 5배 또는 10배 속도)
    input  logic [9:0]   data_in,       // TMDS 인코딩된 10비트 병렬 데이터
    input  logic         rst,           // synchronous reset

    output logic         data_p,        // TMDS positive
    output logic         data_n         // TMDS negative
);

    // Internal wires
    wire oserdes_out;

    // Use OBUFDS to generate differential output
    OBUFDS #(
        .IOSTANDARD("TMDS_33"),
        .SLEW("FAST")
    ) obufds_inst (
        .O(data_p),
        .OB(data_n),
        .I(oserdes_out)
    );

    // Use OSERDESE2 for 10:1 serialization
    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),           // Double data rate (required for HDMI)
        .DATA_RATE_TQ("SDR"),
        .DATA_WIDTH(10),
        .SERDES_MODE("MASTER"),
        .TRISTATE_WIDTH(1),
        .TBYTE_CTL("FALSE"),
        .TBYTE_SRC("FALSE"),
        .INIT_OQ(0),
        .INIT_TQ(0)
    ) oserdes_master (
        .OQ(oserdes_out),
        .CLK(serial_clk),               // Fast clock (5x or 10x)
        .CLKDIV(pixel_clk),             // Pixel clock
        .D1(data_in[0]),
        .D2(data_in[1]),
        .D3(data_in[2]),
        .D4(data_in[3]),
        .D5(data_in[4]),
        .D6(data_in[5]),
        .D7(data_in[6]),
        .D8(data_in[7]),
        //.D9(data_in[8]),   // 추가
        //.D10(data_in[9]),  // 추가
        .SHIFTIN1(1'b0),
        .SHIFTIN2(1'b0),
        .OCE(1'b1),
        .TCE(1'b0),
        .RST(rst),
        .TQ(),
        .TBYTEIN(1'b0),
        .TBYTEOUT()
        //.T(1'b0)
    );

    // Slave used only if using full 10-bit (8+2), omitted here for simplicity

endmodule

module tmds_clk_output (
    input  logic         pixel_clk,    // 1x clk (예: 25.2MHz)
    input  logic         serial_clk,   // 10x clk (예: 252MHz)
    input  logic         rst,

    output logic         clk_p,        // TMDS Clock +
    output logic         clk_n         // TMDS Clock -
);

    // 클럭 패턴: 10비트 반복 시퀀스
    logic [9:0] clk_pattern = 10'b1111100000;
    wire        oserdes_out;

    // 디퍼런셜 버퍼 출력
    OBUFDS #(
        .IOSTANDARD("TMDS_33"),
        .SLEW("FAST")
    ) obufds_clk (
        .O(clk_p),
        .OB(clk_n),
        .I(oserdes_out)
    );

    // 10비트 TMDS 클럭 패턴 직렬화 (OSERDESE2)
    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"),
        .DATA_RATE_TQ("SDR"),
        .DATA_WIDTH(10),
        .SERDES_MODE("MASTER"),
        .TRISTATE_WIDTH(1),
        .TBYTE_CTL("FALSE"),
        .TBYTE_SRC("FALSE"),
        .INIT_OQ(0),
        .INIT_TQ(0)
    ) oserdes_clk (
        .OQ(oserdes_out),
        .CLK(serial_clk),
        .CLKDIV(pixel_clk),
        .D1(clk_pattern[0]),
        .D2(clk_pattern[1]),
        .D3(clk_pattern[2]),
        .D4(clk_pattern[3]),
        .D5(clk_pattern[4]),
        .D6(clk_pattern[5]),
        .D7(clk_pattern[6]),
        .D8(clk_pattern[7]),
        //.D9(clk_pattern[8]),    // 반드시 추가
        //.D10(clk_pattern[9]),   // 반드시 추가
        .SHIFTIN1(1'b0),
        .SHIFTIN2(1'b0),
        .OCE(1'b1),
        .TCE(1'b0),
        .RST(rst),
        .TQ(),
        .TBYTEIN(1'b0),
        .TBYTEOUT()
//        .T(1'b0)
    );


endmodule