`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/23 09:50:56
// Design Name: 
// Module Name: FIFO_MODULE
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module fifo (
    input        clk,
    input        reset,
    //write
    input  [7:0] wdata,
    input        wr,
    output       full,
    //read
    input        rd,
    output [7:0] rdata,
    output       empty

);

wire w_wr;
assign w_wr = wr & ~(full);
wire [3:0] w_waddr, w_raddr;
fifo_control_unit u_cu(
    .clk(clk),
    .reset(reset),
    // write
    .wr(wr),
    .full(full),
    .waddr(w_waddr),
    //read
    .rd(rd),
    .raddr(w_raddr),
    .empty(empty)

);

register_file u_register_file (
    .clk(clk),

    // write
    .wr(w_wr),
    .waddr(w_waddr),  //4bit
    .wdata(wdata), 
    .rd(rd), //8bit

    //read
    .raddr(w_raddr),
    .rdata(rdata)
);

endmodule

module register_file (
    input clk,

    // write
    input       wr,
    input       rd,
    input [3:0] waddr,  //4bit
    input [7:0] wdata,  //8bit

    //read
    input  [3:0] raddr,
    output reg [7:0] rdata

);

    reg [7:0] mem[0:2**4 -1];  // 16개의 8bit짜리  address 
    wire [3:0] read_addr;

    //write
    always @(posedge clk) begin
        if (wr) mem[waddr] <= wdata;  // 한클럭 뒤에 
    end

    //read
    always @(*) begin
    rdata = 0;
    if(rd) rdata = mem[raddr];  //바로바로
    end


endmodule

module fifo_control_unit (
    input        clk,
    input        reset,
    // write
    input        wr,
    output       full,
    output [3:0] waddr,
    //read
    input        rd,
    output [3:0] raddr,
    output       empty

);

    reg c_full, n_full, c_empty, n_empty;  // 1bit 상태 출력
    reg [3:0] c_wptr, n_wptr, c_rptr, n_rptr;  // 4bit address 관리 

    assign waddr = c_wptr;
    assign raddr = c_rptr;
    assign full = c_full;
    assign empty = c_empty;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_full  <= 0;
            c_empty <= 1'b1; // 초기상태 
            c_wptr  <= 0;
            c_rptr  <= 0;
        end else begin
            c_full  <= n_full;
            c_empty <= n_empty;
            c_wptr  <= n_wptr;
            c_rptr  <= n_rptr;
        end
    end

    always @(*) begin // tick이 아니니깐 current로 초기화 
        n_full  = c_full;
        n_empty = c_empty;
        n_wptr  = c_wptr;
        n_rptr  = c_rptr;

        //유지해야 full/ empty 출력가능 
     
        case({wr,rd}) // state만들기 귀찮  {i, a[3:0]} 
        2'b01: begin
            if(c_empty == 1'b0) begin
                n_rptr = c_rptr + 1;
                n_full = 1'b0;
                if(c_wptr == n_rptr)
                begin 
                    n_empty = 1'b1;

                end
            end
        end

        2'b10: begin
            if(c_full == 1'b0) begin
                n_wptr = c_wptr + 1;
                n_empty = 1'b0;
                if(c_rptr == n_wptr) begin
                    n_full = 1'b1;
                end
                end

        end
        // read 바로 write 
        2'b11: begin
            if(c_empty == 1'b1) begin
                n_wptr = c_wptr + 1; 
                n_empty = 1'b0;
            end
            else begin
                if(c_full) begin
                    n_rptr = c_rptr + 1;
                    n_full = 1'b0;
                end

                else begin
                    n_rptr = c_rptr + 1;
                    n_wptr = c_wptr + 1;
                end
            end
            end
     
        
    endcase
end

//메모리 초기화 필요 x 어차피 wdata address를 통해 채워짐 
 
endmodule
