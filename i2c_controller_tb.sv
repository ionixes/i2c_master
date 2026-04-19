`timescale 1ns / 1ps

// TODO modeling of slave feedback

module i2c_controller_tb;
	
	// Clock
	reg clk_r;

	localparam CLK_PERIOD = 10;
	always #(CLK_PERIOD/2) clk_r = ~clk_r;

	// Registers
	reg rstn_r = 1'b1;
	reg [2:0] cmd_r;
	reg [3:0] state_r;

	reg ready_r;
	reg wr_i2c_r = 0;

	reg [4:0] bit_count_r;
	reg [4:0] counter_r = 0;
	
	reg [7:0] din_r;
	
	// Wires
	wire scl_w;
	wire sda_w;

	// UUT
	// i2c_master uut(
	//	.rstni(rstn_r),
	//	.clki(clk_r),
	//	
	//	.wri(wr_i2c_r),
	//	.cmdi(cmd_r),
	//	
	//	.dini(din_r),
		
	//	.stateo(state_r),
	//	.readyo(ready_r),
	//	.bitcount(bit_count_r),
		
	//	.sdaio(sda_w),
	//	.sclio(scl_w)
	// );	

	// Commands constants
	localparam START_CMD   = 3'b001;
	localparam WR_CMD      = 3'b010;
	localparam RD_CMD      = 3'b011;
	localparam STOP_CMD    = 3'b100;
	localparam RESTART_CMD = 3'b101;
	
	initial begin
	
		rstn_r = 0;
		clk_r = 0;
		
		#10;
		
		rstn_r = 1;
		
		#10;
		
		cmd_r = START_CMD;	
		
		#10; 
		
		wr_i2c_r = 1;
		din_r = 8'b11111111;
		
		#400;
		
		din_r = 8'b10101010;
		
		#1000;
		$stop;
		
	end
	
	always @(posedge ready_r) begin
		counter_r = counter_r + 1;
		
		if (counter_r == 3)
		begin
			cmd_r = RESTART_CMD;
			din_r = 8'b10101010;
		end else if (counter_r == 4) 
		begin
			cmd_r = WR_CMD;
		end else if (counter_r == 5) 
		begin
			cmd_r = STOP_CMD;
		end
	end
	
endmodule