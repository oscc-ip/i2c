/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE rev.B2 compliant I2C Master bit-controller        ////
////                                                             ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/projects/i2c/    ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////
// Bit controller section
/////////////////////////////////////
//
// Translate simple commands into SCL/SDA transitions
// Each command has 5 states, A/B/C/D/idle
//
// start:	SCL	~~~~~~~~~~\____
//	SDA	~~~~~~~~\______
//		 x | A | B | C | D | i
//
// repstart	SCL	____/~~~~\___
//	SDA	__/~~~\______
//		 x | A | B | C | D | i
//
// stop	SCL	____/~~~~~~~~
//	SDA	==\____/~~~~~
//		 x | A | B | C | D | i
//
//- write	SCL	____/~~~~\____
//	SDA	==X=========X=
//		 x | A | B | C | D | i
//
//- read	SCL	____/~~~~\____
//	SDA	XXXX=====XXXX
//		 x | A | B | C | D | i
//

// Timing:     Normal mode      Fast mode
///////////////////////////////////////////////////////////////////////
// Fscl        100KHz           400KHz
// Th_scl      4.0us            0.6us   High period of SCL
// Tl_scl      4.7us            1.3us   Low period of SCL
// Tsu:sta     4.7us            0.6us   setup time for a repeated start condition
// Tsu:sto     4.0us            0.6us   setup time for a stop conditon
// Tbuf        4.7us            1.3us   Bus free time between a stop and start condition
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// i2c is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "i2c_define.sv"

module i2c_master_bit_ctrl (
    input             clk_i,      // system clock
    input             rst_n_i,    // asynchronous active low reset
    input             ena_i,      // core enable signal
    input      [15:0] clk_cnt_i,  // clock prescale value
    input      [ 3:0] cmd_i,      // command (from byte controller)
    output reg        cmd_ack_o,  // command complete acknowledge
    output reg        busy_o,     // i2c bus busy_o
    output reg        al_o,       // i2c bus arbitration lost
    input             dat_i,
    output reg        dat_o,
    input             scl_i,      // i2c clock line input
    output            scl_o,      // i2c clock line output
    output reg        scl_dir_o,  // i2c clock line output enable (active low)
    input             sda_i,      // i2c data line input
    output            sda_o,      // i2c data line output
    output reg        sda_dir_o   // i2c data line output enable (active low)
);

  reg [1:0] r_cSCL, r_cSDA;  // capture SCL and SDA
  reg [2:0] r_fSCL, r_fSDA;  // SCL and SDA filter inputs
  reg r_sSCL, r_sSDA;  // filtered and synchronized SCL and SDA inputs
  reg r_dSCL, r_dSDA;  // delayed versions of r_sSCL and r_sSDA
  reg        r_dscl_dir;  // delayed scl_dir_o
  reg        r_sda_chk;  // check SDA output (Multi-master arbitration)
  reg        r_clk_en;  // clock generation signals
  reg        r_slave_wait;  // slave inserts wait states
  reg [15:0] r_cnt;  // clock divider counter (synthesis)
  reg [13:0] r_filter_cnt;  // clock divider for filter


  // state machine variable
  reg [17:0] r_c_state;
  // whenever the slave is not ready it can delay the cycle by pulling SCL low
  // delay scl_dir_o
  always @(posedge clk_i) r_dscl_dir <= scl_dir_o;

  // r_slave_wait is asserted when master wants to drive SCL high, but the slave pulls it low
  // r_slave_wait remains asserted until the slave releases SCL
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) r_slave_wait <= 1'b0;
    else r_slave_wait <= (scl_dir_o & ~r_dscl_dir & ~r_sSCL) | (r_slave_wait & ~r_sSCL);

  // master drives SCL high, but another master pulls it low
  // master start counting down its low cycle now (clock synchronization)
  wire s_scl_sync = r_dSCL & ~r_sSCL & scl_dir_o;


  // generate clk_i enable signal
  always @(posedge clk_i or negedge rst_n_i)
    if (~rst_n_i) begin
      r_cnt    <= 16'h0;
      r_clk_en <= 1'b1;
    end else if (~|r_cnt || !ena_i || s_scl_sync) begin
      r_cnt    <= clk_cnt_i;
      r_clk_en <= 1'b1;
    end else if (r_slave_wait) begin
      r_cnt    <= r_cnt;
      r_clk_en <= 1'b0;
    end else begin
      r_cnt    <= r_cnt - 16'h1;
      r_clk_en <= 1'b0;
    end


  // generate bus status controller
  // capture SDA and SCL
  // reduce metastability risk
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) begin
      r_cSCL <= 2'b00;
      r_cSDA <= 2'b00;
    end else begin
      r_cSCL <= {r_cSCL[0], scl_i};
      r_cSDA <= {r_cSDA[0], sda_i};
    end


  // filter SCL and SDA signals; (attempt to) remove glitches
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) r_filter_cnt <= 14'h0;
    else if (!ena_i) r_filter_cnt <= 14'h0;
    else if (~|r_filter_cnt) r_filter_cnt <= clk_cnt_i >> 2;  //16x I2C bus frequency
    else r_filter_cnt <= r_filter_cnt - 1;


  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) begin
      r_fSCL <= 3'b111;
      r_fSDA <= 3'b111;
    end else if (~|r_filter_cnt) begin
      r_fSCL <= {r_fSCL[1:0], r_cSCL[1]};
      r_fSDA <= {r_fSDA[1:0], r_cSDA[1]};
    end


  // generate filtered SCL and SDA signals
  always @(posedge clk_i or negedge rst_n_i)
    if (~rst_n_i) begin
      r_sSCL <= 1'b1;
      r_sSDA <= 1'b1;

      r_dSCL <= 1'b1;
      r_dSDA <= 1'b1;
    end else begin
      r_sSCL <= &r_fSCL[2:1] | &r_fSCL[1:0] | (r_fSCL[2] & r_fSCL[0]);
      r_sSDA <= &r_fSDA[2:1] | &r_fSDA[1:0] | (r_fSDA[2] & r_fSDA[0]);

      r_dSCL <= r_sSCL;
      r_dSDA <= r_sSDA;
    end

  // detect start condition => detect falling edge on SDA while SCL is high
  // detect stop condition => detect rising edge on SDA while SCL is high
  reg r_sta_cond;
  reg r_sto_cond;
  always @(posedge clk_i or negedge rst_n_i)
    if (~rst_n_i) begin
      r_sta_cond <= 1'b0;
      r_sto_cond <= 1'b0;
    end else begin
      r_sta_cond <= ~r_sSDA & r_dSDA & r_sSCL;
      r_sto_cond <= r_sSDA & ~r_dSDA & r_sSCL;
    end


  // generate i2c bus busy_o signal
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) busy_o <= 1'b0;
    else busy_o <= (r_sta_cond | busy_o) & ~r_sto_cond;


  // generate arbitration lost signal
  // aribitration lost when:
  // 1) master drives SDA high, but the i2c bus is low
  // 2) stop detected while not requested
  reg r_cmd_stop;
  always @(posedge clk_i or negedge rst_n_i)
    if (~rst_n_i) r_cmd_stop <= 1'b0;
    else if (r_clk_en) r_cmd_stop <= cmd_i == `I2C_CMD_STOP;

  always @(posedge clk_i or negedge rst_n_i)
    if (~rst_n_i) al_o <= 1'b0;
    else al_o <= (r_sda_chk & ~r_sSDA & sda_dir_o) | (|r_c_state & r_sto_cond & ~r_cmd_stop);

  // generate dat_o signal (store SDA on rising edge of SCL)
  always @(posedge clk_i) if (r_sSCL & ~r_dSCL) dat_o <= r_sSDA;


  // generate statemachine
  // nxt_state decoder
  parameter [17:0] idle = 18'b0_0000_0000_0000_0000;
  parameter [17:0] start_a = 18'b0_0000_0000_0000_0001;
  parameter [17:0] start_b = 18'b0_0000_0000_0000_0010;
  parameter [17:0] start_c = 18'b0_0000_0000_0000_0100;
  parameter [17:0] start_d = 18'b0_0000_0000_0000_1000;
  parameter [17:0] start_e = 18'b0_0000_0000_0001_0000;
  parameter [17:0] stop_a = 18'b0_0000_0000_0010_0000;
  parameter [17:0] stop_b = 18'b0_0000_0000_0100_0000;
  parameter [17:0] stop_c = 18'b0_0000_0000_1000_0000;
  parameter [17:0] stop_d = 18'b0_0000_0001_0000_0000;
  parameter [17:0] rd_a = 18'b0_0000_0010_0000_0000;
  parameter [17:0] rd_b = 18'b0_0000_0100_0000_0000;
  parameter [17:0] rd_c = 18'b0_0000_1000_0000_0000;
  parameter [17:0] rd_d = 18'b0_0001_0000_0000_0000;
  parameter [17:0] wr_a = 18'b0_0010_0000_0000_0000;
  parameter [17:0] wr_b = 18'b0_0100_0000_0000_0000;
  parameter [17:0] wr_c = 18'b0_1000_0000_0000_0000;
  parameter [17:0] wr_d = 18'b1_0000_0000_0000_0000;

  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) begin
      r_c_state <= idle;
      cmd_ack_o <= 1'b0;
      scl_dir_o <= 1'b1;
      sda_dir_o <= 1'b1;
      r_sda_chk <= 1'b0;
    end else if (al_o) begin
      r_c_state <= idle;
      cmd_ack_o <= 1'b0;
      scl_dir_o <= 1'b1;
      sda_dir_o <= 1'b1;
      r_sda_chk <= 1'b0;
    end else begin
      cmd_ack_o <= 1'b0;  // default no command acknowledge + assert cmd_ack_o only 1clk cycle

      if (r_clk_en)
        case (r_c_state)  // synopsys full_case parallel_case
          // idle state
          idle: begin
            case (cmd_i)  // synopsys full_case parallel_case
              `I2C_CMD_START: r_c_state <= start_a;
              `I2C_CMD_STOP:  r_c_state <= stop_a;
              `I2C_CMD_WRITE: r_c_state <= wr_a;
              `I2C_CMD_READ:  r_c_state <= rd_a;
              default:        r_c_state <= idle;
            endcase

            scl_dir_o <= scl_dir_o;  // keep SCL in same state
            sda_dir_o <= sda_dir_o;  // keep SDA in same state
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          start_a: begin
            r_c_state <= start_b;
            scl_dir_o <= scl_dir_o;  // keep SCL in same state
            sda_dir_o <= 1'b1;  // set SDA high
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          start_b: begin
            r_c_state <= start_c;
            scl_dir_o <= 1'b1;  // set SCL high
            sda_dir_o <= 1'b1;  // keep SDA high
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          start_c: begin
            r_c_state <= start_d;
            scl_dir_o <= 1'b1;  // keep SCL high
            sda_dir_o <= 1'b0;  // set SDA low
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          start_d: begin
            r_c_state <= start_e;
            scl_dir_o <= 1'b1;  // keep SCL high
            sda_dir_o <= 1'b0;  // keep SDA low
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          start_e: begin
            r_c_state <= idle;
            cmd_ack_o <= 1'b1;
            scl_dir_o <= 1'b0;  // set SCL low
            sda_dir_o <= 1'b0;  // keep SDA low
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          stop_a: begin
            r_c_state <= stop_b;
            scl_dir_o <= 1'b0;  // keep SCL low
            sda_dir_o <= 1'b0;  // set SDA low
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          stop_b: begin
            r_c_state <= stop_c;
            scl_dir_o <= 1'b1;  // set SCL high
            sda_dir_o <= 1'b0;  // keep SDA low
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          stop_c: begin
            r_c_state <= stop_d;
            scl_dir_o <= 1'b1;  // keep SCL high
            sda_dir_o <= 1'b0;  // keep SDA low
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          stop_d: begin
            r_c_state <= idle;
            cmd_ack_o <= 1'b1;
            scl_dir_o <= 1'b1;  // keep SCL high
            sda_dir_o <= 1'b1;  // set SDA high
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          rd_a: begin
            r_c_state <= rd_b;
            scl_dir_o <= 1'b0;  // keep SCL low
            sda_dir_o <= 1'b1;  // tri-state SDA
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          rd_b: begin
            r_c_state <= rd_c;
            scl_dir_o <= 1'b1;  // set SCL high
            sda_dir_o <= 1'b1;  // keep SDA tri-stated
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          rd_c: begin
            r_c_state <= rd_d;
            scl_dir_o <= 1'b1;  // keep SCL high
            sda_dir_o <= 1'b1;  // keep SDA tri-stated
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          rd_d: begin
            r_c_state <= idle;
            cmd_ack_o <= 1'b1;
            scl_dir_o <= 1'b0;  // set SCL low
            sda_dir_o <= 1'b1;  // keep SDA tri-stated
            r_sda_chk <= 1'b0;  // don't check SDA output
          end

          wr_a: begin
            r_c_state <= wr_b;
            scl_dir_o <= 1'b0;  // keep SCL low
            sda_dir_o <= dat_i;  // set SDA
            r_sda_chk <= 1'b0;  // don't check SDA output (SCL low)
          end

          wr_b: begin
            r_c_state <= wr_c;
            scl_dir_o <= 1'b1;  // set SCL high
            sda_dir_o <= dat_i;  // keep SDA
            r_sda_chk <= 1'b0;  // don't check SDA output yet
            // allow some time for SDA and SCL to settle
          end

          wr_c: begin
            r_c_state <= wr_d;
            scl_dir_o <= 1'b1;  // keep SCL high
            sda_dir_o <= dat_i;
            r_sda_chk <= 1'b1;  // check SDA output
          end

          wr_d: begin
            r_c_state <= idle;
            cmd_ack_o <= 1'b1;
            scl_dir_o <= 1'b0;  // set SCL low
            sda_dir_o <= dat_i;
            r_sda_chk <= 1'b0;  // don't check SDA output (SCL low)
          end

        endcase
    end

  // assign scl and sda output (always zero)
  assign scl_o = 1'b0;
  assign sda_o = 1'b0;

endmodule
