`timescale 1ns/1ps

module tb_top_fpga;

  // parameters
  localparam WIDTH   = 320;
  localparam HEIGHT  = 240;
  localparam FRAME_N = 5;

  // clk / reset
  logic clk, reset;
  initial begin
    clk   = 0;
    reset = 1;
    #100;
    reset = 0;
  end
  always #10 clk = ~clk;  // 50 MHz

  // camera interface signals
  logic        ov7670_pclk;
  logic        ov7670_href;
  logic        ov7670_v_sync;
  logic [7:0]  ov7670_data;
  // control switches
  logic sw_gray   = 1;
  logic sw_upscale= 0;

  // VGA outputs (unused in TB)
  logic        tx_out;
  logic        ov7670_scl, ov7670_sda, ov7670_xclk;
  logic        h_sync, v_sync;
  logic [4:0]  red_port;
  logic [5:0]  green_port;
  logic [4:0]  blue_port;

  // DUT outputs
  logic [8:0]  o_hand_x;
  logic [7:0]  o_hand_y;
  logic        motion;
  logic        done;

  // instantiate DUT
Top_FPGA DUT(
    .clk(clk),
    .reset(reset),
    .sw_gray(sw_gray),
    .sw_upscale(sw_upscale),
    .ov7670_pclk(ov7670_pclk),
    .ov7670_href(ov7670_href),
    .ov7670_v_sync(ov7670_v_sync),
    .ov7670_data(ov7670_data),
    .tx_out(tx_out),
    .ov7670_scl(ov7670_scl),
    .ov7670_sda(ov7670_sda),
    .ov7670_xclk(ov7670_xclk),
    .h_sync(h_sync),
    .v_sync(v_sync),
    .red_port(red_port),
    .green_port(green_port),
    .blue_port(blue_port)
    );

  // drive pclk = same as system clk
  assign ov7670_pclk = clk;

  integer file, i;
  reg [7:0] buffer [0:WIDTH*HEIGHT-1];

  initial begin
    ov7670_href   = 0;
    ov7670_v_sync = 0;
    ov7670_data   = 0;

    // 리셋 해제 대기
    @(negedge reset);

    // **한 개의 C 소스 파일을 메모리로 읽어들이기**
    file = $fopen("C:/Users/kccistc/Desktop/test_image1.c", "rb");
    if (file == 0) begin
      $display("## ERROR: cannot open test_image1.c");
      $finish;
    end

    // 파일 크기만큼(예: 320×240) 1바이트씩 읽어서 buffer[]에 저장
    for (i = 0; i < WIDTH*HEIGHT; i = i + 1) begin
      buffer[i] = $fgetc(file);
    end
    $fclose(file);

    // 한 프레임으로 간주해서 vsync, href, data를 그대로 흘려줌
    // vsync 펄스
    ov7670_v_sync = 1;
    @(posedge clk);
    ov7670_v_sync = 0;

    // 픽셀 스트리밍
    for (i = 0; i < WIDTH*HEIGHT; i = i + 1) begin
      ov7670_href = 1;
      ov7670_data = buffer[i];
      @(posedge clk);
    end
    ov7670_href = 0;

    // 파이프라인 플러시를 위해 잠시 대기
    repeat (100) @(posedge clk);

    $display("=== Simulation completed ===");
    $finish;
  end

endmodule

