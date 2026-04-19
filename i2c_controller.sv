//`timescale 1ns/1ps

module i2c_controller 
#(parameter D = 8)
(
	input rstni,              	
	input clki,                  	
	
	input wri,               	
	input [2:0] cmdi,            	
	
	input [D-1:0] dini,            
	output [D-1:0] douto,	     
	output acko,			

	output [3:0] stateo,         	
	output readyo,               	
	output [4:0] bitcount,	
		
	inout tri sdaio,             	
	output tri sclio		
);

typedef enum logic [2:0] {NONE = 3'b000, START_CMD = 3'b001, WR_CMD = 3'b010, 
								RD_CMD = 3'b011, STOP_CMD = 3'b100, RESTART_CMD = 3'b101} cmdtype;
								
typedef enum logic [3:0] {SETUP = 4'd0, IDLE_STATE = 4'd1, START1_STATE = 4'd2, 
									START2_STATE = 4'd3, HOLD_STATE = 4'd4, RESTART1_STATE = 4'd5,
									RESTART2_STATE = 4'd6, STOP1_STATE = 4'd7, 
									STOP2_STATE = 4'd8, STOP3_STATE = 4'd9, DATA1_STATE = 4'd10, 
									DATA2_STATE = 4'd11, DATA3_STATE = 4'd12, DATA4_STATE = 4'd13, DATAEND_STATE = 4'd14} statetype;


reg sda_out_r;
reg scl_out_r;

reg sda_r;
reg scl_r;

reg data_phase_r;		
cmdtype cmd_r;		
cmdtype cmd_next_r;


reg [D+1:0] tx_r;
reg [D+1:0] tx_next_r;
	
reg [D+1:0] rx_r;
reg [D+1:0] rx_next_r;

reg [4:0] bit_r;

wire into_w;	

reg ready_r;			
reg [4:0] bit_next_r;		

assign readyo = ready_r;	
assign bitcount = bit_r;	


assign douto = rx_r[8:1];	
assign acko = rx_r[0];    	

wire nack_w;
assign nack_w = dini[0];

assign into_w = (data_phase_r && cmd_r == RD_CMD && bit_r < 8) || (data_phase_r && cmd_r == WR_CMD && bit_r == 8); 
assign sdaio = (into_w || sda_r) ? 1'bz : 1'b0;

assign sclio = (scl_r) ? 1'bz : 1'b0;

// STATE MACHINE

statetype state_r;		
statetype state_next_r;		

assign stateo = state_r;	

always_ff @(posedge clki, negedge rstni)
begin
  if (~rstni)  begin
		sda_r <= 1'b1;
		scl_r <= 1'b1;
      state_r <= IDLE_STATE;
		bit_r   <= 0;               	
		cmd_r   <= NONE; 
		tx_r    <= 0;                   
		rx_r    <= 0;                   
  end else begin
		sda_r <= sda_out_r; 
      	scl_r <= scl_out_r;
      	state_r <= state_next_r;
		bit_r   <= bit_next_r;      
		cmd_r   <= cmd_next_r;
		tx_r    <= tx_next_r;            
		rx_r    <= rx_next_r;       
  end
end 

always_comb begin
	state_next_r = state_r;	
	ready_r = 1'b0;		
	data_phase_r = 1'b0;	
	cmd_next_r = cmd_r;	
	bit_next_r = bit_r;
	scl_out_r = 1'b1;
	sda_out_r = 1'b0;
	tx_next_r = tx_r;           
	rx_next_r = rx_r;           	

	case (state_r)
		IDLE_STATE: begin	
			ready_r = 1'b1;
			if(wri && cmdi == START_CMD) begin	
				state_next_r = START1_STATE;	
			end				
		end		
		START1_STATE: begin 				  				
			state_next_r = START2_STATE;
			sda_out_r = 1'b0;	

		end
		START2_STATE: begin
			state_next_r = HOLD_STATE;
			scl_out_r = 1'b0;	
			sda_out_r = 1'b0;	
		end
			
		HOLD_STATE: begin
			ready_r = 1'b1;
			scl_out_r = 1'b0;	
			sda_out_r = 1'b0;	
			if (wri)	begin
				cmd_next_r =  cmdtype'(cmdi);		
					
				case (cmdtype'(cmdi))                   
					RESTART_CMD:
						state_next_r = RESTART1_STATE; 
						
					STOP_CMD:
						state_next_r = STOP1_STATE;
							
					default: begin
						bit_next_r   = 5'b0;	
						state_next_r = DATA1_STATE;		
						tx_next_r = {dini, nack_w};	
               end
				endcase
			end			
		end
			
		DATA1_STATE: begin 
			data_phase_r = 1'b1;
			scl_out_r = 1'b0;	
			state_next_r = DATA2_STATE;
				
			sda_out_r = tx_r[8];		
			scl_out_r = 1'b0;		
		end
	
		DATA2_STATE: begin 
			data_phase_r = 1'b1;										 
         state_next_r = DATA3_STATE;
		
			sda_out_r = tx_r[8];		
			scl_out_r = 1'b0;	
			
			rx_next_r = {rx_r[7:0], sdaio};	
		end
			
		DATA3_STATE: begin 
			data_phase_r = 1'b1;			 
         state_next_r = DATA4_STATE;	
			
			sda_out_r = tx_r[8];		
			scl_out_r = 1'b0;
		end
			
		DATA4_STATE: begin 
			scl_out_r = 1'b0;	
         data_phase_r = 1'b1;

			sda_out_r = tx_r[8];
	
			if (bit_r == 8) begin
				state_next_r = DATAEND_STATE;
			end else begin
				bit_next_r = bit_r + 1;		
				state_next_r = DATA1_STATE;	
			end
		end
			
		DATAEND_STATE: begin
			state_next_r = HOLD_STATE;
			scl_out_r = 1'b0;	
			sda_out_r = 1'b0;	
		end
			
		RESTART1_STATE: begin 
			state_next_r = RESTART2_STATE;	
			
		end
			
		RESTART2_STATE: begin 
			state_next_r = START1_STATE;	
			scl_out_r = 1'b0;	
		end
			
		STOP1_STATE: begin 
			state_next_r = STOP2_STATE;	
			scl_out_r = 1'b0;	
		end
			
		STOP2_STATE: begin 	
           		state_next_r = STOP3_STATE;	
		end
		
		default: begin				
			state_next_r = IDLE_STATE;	
		end
			
	endcase
end

endmodule
