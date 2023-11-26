// Copyright (c) 2023 Beijing Institute of Open Source Chip
// i2c is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_I2C_TEST_SV
`define INC_I2C_TEST_SV

`include "apb4_master.sv"
`include "i2c_define.sv"

class I2CTest extends APB4Master;
  string                 name;
  int                    wr_val;
  virtual apb4_if.master apb4;
  virtual i2c_if.tb      i2c;

  extern function new(string name = "i2c_test", virtual apb4_if.master apb4, virtual i2c_if.tb i2c);
  extern task automatic test_reset_reg();
  extern task automatic test_wr_rd_reg(input bit [31:0] run_times = 1000);
  extern task automatic test_clk_div(input bit [31:0] run_times = 10);
  extern task automatic test_irq(input bit [31:0] run_times = 10);
endclass

function I2CTest::new(string name, virtual apb4_if.master apb4, virtual i2c_if.tb i2c);
  super.new("apb4_master", apb4);
  this.name   = name;
  this.wr_val = 0;
  this.apb4   = apb4;
  this.i2c    = i2c;
endfunction

task automatic I2CTest::test_reset_reg();
  super.test_reset_reg();
  // verilog_format: off
  // this.rd_check(`PWM_CTRL_ADDR, "CTRL REG", 32'b0 & {`PWM_CTRL_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  // verilog_format: on
endtask

task automatic I2CTest::test_wr_rd_reg(input bit [31:0] run_times = 1000);
  super.test_wr_rd_reg();
  // verilog_format: off
  for (int i = 0; i < run_times; i++) begin
    // this.wr_rd_check(`PWM_CTRL_ADDR, "CTRL REG", $random & {`PWM_CTRL_WIDTH{1'b1}}, Helper::EQUL);
  end
  // verilog_format: on
endtask

task automatic I2CTest::test_clk_div(input bit [31:0] run_times = 10);
  $display("=== [test i2c clk div] ===");
endtask

task automatic I2CTest::test_irq(input bit [31:0] run_times = 10);
  super.test_irq();
endtask
`endif
