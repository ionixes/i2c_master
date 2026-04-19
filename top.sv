module i2c_master (
    input clk_i,   
    input rstn_i,  

    input  [5:0] btn_brd_i,   
    output [3:0] led_brd_o,   


    inout  sda_io,   
    output scl_io,    
	output clk_os
);

// PARAM FOR SETTINGS

  localparam SLAVE_ADDR = 7'b1010000;
  localparam R = 1'b1;
  localparam W = 1'b0;

  typedef enum logic [3:0] {
    IDLE_STATE  = 4'd1,
    WRITE_STATE = 4'd2,
    READ_STATE  = 4'd3,
    WAIT_STATE  = 4'd4
  } state;

  state state_r = IDLE_STATE;

  typedef enum logic [3:0] {
    START_CMD = 4'd1,
    WR_CMD = 4'd2,
    RD_CMD = 4'd3,
    STOP_CMD = 4'd4,
    RESTART_CMD = 4'd5
  } cmd;

  cmd cmd_r = START_CMD;

  logic [31:0] timer_r;

  logic wr_i2c_r;

  logic [6:0] slave_addr_r = SLAVE_ADDR;
  logic [7:0] reg_addr_r = 0;
  logic [7:0] data_write_r = 0;

  logic [7:0] read_data_r;
  logic [7:0] read_data_w;

  logic [7:0] write_data_r;

  logic ack_bit_r;
  logic ack_bit_w;

   
   
   

  logic led_write_pulse_r;		 
  logic led_read_pulse_r;		 

// LEDS FOR READ/WRITE _ ACK DEBUG
   
  led_driver led_driver_m0 (
      .clk_i  (clk_i),
      .rstn_i (rstn_i),
      .state_i(ack_bit_w),
      .led_o  (led_brd_o[0])
  );
   
  led_driver led_driver_m1 (
      .clk_i  (clk_i),
      .rstn_i (rstn_i),
      .state_i(led_read_pulse_r),
      .led_o  (led_brd_o[1])
  );
   
  led_driver led_driver_m2 (
      .clk_i  (clk_i),
      .rstn_i (rstn_i),
      .state_i(led_write_pulse_r),
      .led_o  (led_brd_o[2])
  );

  logic clk_div_w;

  clock_divider clock_divider_m0 (
      .clk_i(clk_i),
      .clk_o(clk_div_w),
  );

  assign clk_os = clk_div_w;

// THIS CONTROLLER

  i2c_controller i2c_controller_m0 (

      .rstni(rstn_i),     
      .clki (clk_div_w),  

      .wri(wr_i2c_r),   
      .cmdi(cmd_r),   

      .dini(write_data_r),   
      .douto(read_data_w),   
      .acko(ack_bit_w),   

      .readyo(ready_w),   

      .sdaio(sda_io),   
      .sclio(scl_io)    
  );

  always @(*) begin
    read_data_r <= read_data_w;
    ack_bit_r   <= ack_bit_w;
  end

  always @(posedge clk_i or negedge rstn_i) begin
    if (rstn_i == 1'b0) begin
      reg_addr_r   <= 0;
      data_write_r <= 0;
    end else begin

      if (btn_brd_i[2]) begin
        reg_addr_r = reg_addr_r + 1;
      end

      if (btn_brd_i[3]) begin
        reg_addr_r = reg_addr_r - 1;
      end

      if (btn_brd_i[4]) begin
        data_write_r = data_write_r + 1;
      end

      if (btn_brd_i[5]) begin
        data_write_r = data_write_r - 1;
      end

    end
  end

// COMMAND STATE MACHINE

  logic [4:0] counter_r = 0;
  always @(posedge ready_w or negedge rstn_i) begin

    if (rstn_i == 1'b0) begin
      counter_r = 0;
    end else begin

      counter_r = counter_r + 1;

      case (state_r)

        READ_STATE: begin
          if (counter_r == 7) begin
            counter_r = 0;
          end
        end

        WRITE_STATE: begin
          if (counter_r == 5) begin
            counter_r = 0;
          end
        end

        default: begin
          counter_r = 0;
        end

      endcase

    end
  end

  always @(posedge clk_i or negedge rstn_i) begin

    if (rstn_i == 1'b0) begin

      led_write_pulse_r = 0;
      led_read_pulse_r = 0;

      cmd_r    = START_CMD;
      state_r   = IDLE_STATE;
      write_data_r  = 0;
      wr_i2c_r  = 0;

    end else begin
      case (state_r)

        IDLE_STATE: begin
          wr_i2c_r = 0;

           Button for Read operation	
          if (btn_brd_i[0]) begin
            if (ready_w) begin
              state_r = READ_STATE;
            end
          end

           
          if (btn_brd_i[1]) begin
            if (ready_w) begin
              state_r = WRITE_STATE;
            end
          end
        end

        READ_STATE: begin
          led_read_pulse_r <= ~led_read_pulse_r;   
          wr_i2c_r = 1;   

          case (counter_r)

            0: begin
            end

            1: begin
              write_data_r = {slave_addr_r, W};   
            end

            2: begin
              write_data_r = reg_addr_r;
            end

            3: begin
              cmd_r = RESTART_CMD;
              write_data_r = {slave_addr_r, R};
            end

            4: begin
              cmd_r = WR_CMD;
              write_data_r = {slave_addr_r, R};
            end

            5: begin
              cmd_r = RD_CMD;
            end

            6: begin
              cmd_r   = STOP_CMD;

              state_r = WAIT_STATE;
              timer_r = 0;
            end
            default: begin
              cmd_r = START_CMD;

              state_r = IDLE_STATE;
              write_data_r = 0;
            end

          endcase
        end

        WRITE_STATE: begin
          led_write_pulse_r <= ~led_write_pulse_r;
          wr_i2c_r = 1;

          case (counter_r)
            0: begin
            end

            1: begin
              write_data_r = {slave_addr_r, W};
            end

            2: begin
              write_data_r = reg_addr_r;
            end

            3: begin
              write_data_r <= data_write_r;
            end

            4: begin
              cmd_r   = STOP_CMD;

              state_r = WAIT_STATE;
              timer_r = 0;
            end

            default: begin
              cmd_r = START_CMD;
              state_r = IDLE_STATE;
              write_data_r = 0;
            end

          endcase
        end

        WAIT_STATE: begin

          wr_i2c_r = 1;

          if (timer_r >= 32'd1000) begin
            state_r <= IDLE_STATE;
            write_data_r = 0;
            cmd_r = START_CMD;
          end else timer_r <= timer_r + 32'd1;
        end

        default: begin
          wr_i2c_r = 0;
          state_r <= IDLE_STATE;
        end

      endcase
    end
  end

endmodule

module led_driver (
    input clk_i,   
    input rstn_i,   
    input state_i,   
    output led_o   
);

  logic led_r;

  always @(posedge clk_i or negedge rstn_i) begin
    if (~rstn_i) begin
      led_r <= 0;
    end else if (state_i) begin
      led_r <= 1'b1;
    end else begin
      led_r <= 1'b0;
    end
  end

  assign led_o = led_r;

endmodule

// TODO: make some against the button delay

// module gpio_debouncer #(
//     parameter CNT_WIDTH = 32,   
//     parameter FREQ = 50,   
//     parameter MAX_TIME = 20	 
// ) (
//     input clk_i,   
//     input rstn_i,   
//     input button_i,   
//     output logic button_posedge_r,   
//     output logic button_negedge_r,   
//     output logic button_out_r   
// );

//   localparam TIMER_MAX_VAL = MAX_TIME * 1000 * FREQ; 	 

//   logic  d1;
//   logic  d2;

//   logic q_reset;

//   assign q_reset = (d1 ^ d2);

//   logic [CNT_WIDTH-1:0] q_reg;   
//   logic [CNT_WIDTH-1:0] q_next;   

//   logic q_add;

//   assign q_add = ~(q_reg == TIMER_MAX_VAL);

//   always @(posedge clk_i or negedge rstn_i) begin
//     if (rstn_i == 1'b0) button_out_r <= 1'b1;
//     else if (q_reg == TIMER_MAX_VAL) button_out_r <= d2;
//     else button_out_r <= button_out_r;
//   end

//   always @(q_reset, q_add, q_reg) begin
//     case ({
//       q_reset, q_add
//     })
//       2'b00:   
//       q_next <= q_reg;   
//       2'b01:   
//       q_next <= q_reg + 1;   
//       default:   
//       q_next <= {CNT_WIDTH{1'b0}};   
//     endcase
//   end

//   logic button_out_d0_r;

//   always @(posedge clk_i or negedge rstn_i) begin

//     if (rstn_i == 1'b0) begin
//       button_out_d0_r  <= 1'b1;
//       button_posedge_r <= 1'b0;
//       button_negedge_r <= 1'b0;
//     end else begin
//       button_out_d0_r  <= button_out_r;
//       button_posedge_r <= ~button_out_d0_r & button_out_r;
//       button_negedge_r <= button_out_d0_r & ~button_out_r;
//     end
//   end

// endmodule

module clock_divider #(
    parameter DIVISOR = 32   
) (
    input clk_i,
    output logic clk_o
);

  logic [27:0] counter = 28'd0;

  always @(posedge clk_i) begin
    counter <= counter + 28'd1;

    if (counter >= (DIVISOR - 1)) counter <= 28'd0;

    clk_o <= (counter < DIVISOR / 2) ? 1'b1 : 1'b0;
  end

endmodule
