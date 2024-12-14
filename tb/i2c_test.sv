// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
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

// verilog_format: off
`define I2C_TEST_START       32'h80
`define I2C_TEST_STOP        32'h40
`define I2C_TEST_READ        32'h20
`define I2C_TEST_WRITE       32'h10
`define I2C_TEST_START_READ  32'hA0
`define I2C_TEST_START_WRITE 32'h90
`define I2C_TEST_STOP_READ   32'h60
`define I2C_TEST_STOP_WRITE  32'h50
// verilog_format: on

class I2CTest extends APB4Master;
  string                 name;
  int                    wr_val;
  int                    rd_val;
  int                    normal_mode_pscr;
  int                    page_wr_rd_num;
  int                    slave_addr;

  virtual apb4_if.master apb4;

  extern function new(string name = "i2c_test", virtual apb4_if.master apb4);
  extern task automatic test_reset_reg();
  extern task automatic i2c_setup(input bit [31:0] pscr, input bit ena);
  extern task automatic i2c_send_data(input bit [31:0] data);
  extern task automatic i2c_send_cmd(input bit [31:0] cmd);
  extern task automatic i2c_get_ack();
  extern task automatic i2c_get_status(output bit [31:0] status);
  extern task automatic i2c_get_data(output bit [31:0] data);
  extern task automatic i2c_busy(output bit busy);
  extern task automatic test_wr_rd_reg(input bit [31:0] run_times = 1000);
  extern task automatic test_i2c_24lc04a_wr_rd();
  extern task automatic test_irq(input bit [31:0] run_times = 10);
endclass

function I2CTest::new(string name, virtual apb4_if.master apb4);
  super.new("apb4_master", apb4);
  this.name             = name;
  this.wr_val           = 0;
  this.rd_val           = 0;
  this.normal_mode_pscr = 0;  // APB: 100MHz / (5* 100KHz) - 1
  this.slave_addr       = 0;
  this.page_wr_rd_num   = 12;
  this.apb4             = apb4;
endfunction

task automatic I2CTest::i2c_setup(input bit [31:0] pscr, input bit ena);
  this.write(`I2C_CTRL_ADDR, 32'b0 & {`I2C_CTRL_WIDTH{1'b1}});
  this.write(`I2C_PSCR_ADDR, pscr & {`I2C_PSCR_WIDTH{1'b1}});
  this.write(`I2C_CTRL_ADDR, {ena, 7'b0} & {`I2C_CTRL_WIDTH{1'b1}});
endtask

task automatic I2CTest::i2c_send_data(input bit [31:0] data);
  this.write(`I2C_TXR_ADDR, data & {`I2C_TXR_WIDTH{1'b1}});
endtask

task automatic I2CTest::i2c_send_cmd(input bit [31:0] cmd);
  this.write(`I2C_CMD_ADDR, cmd & {`I2C_CMD_WIDTH{1'b1}});
endtask

task automatic I2CTest::i2c_get_ack();
  do begin
    this.read(`I2C_SR_ADDR);
    if (super.rd_data[1] == 1'b1) begin
      // $display("%t tip: %b", $time, super.rd_data[1]);
      break;
    end
  end while (1);

  do begin
    this.read(`I2C_SR_ADDR);
    if (super.rd_data[1] == 1'b0) begin
      // $display("%t tip: %b", $time, super.rd_data[1]);
      break;
    end
  end while (1);

  this.read(`I2C_SR_ADDR);
  // $display("%t rxk: %b", $time, super.rd_data[7]);
endtask

task automatic I2CTest::i2c_get_status(output bit [31:0] status);
  this.read(`I2C_SR_ADDR);
  status = super.rd_data;
endtask

task automatic I2CTest::i2c_get_data(output bit [31:0] data);
  this.read(`I2C_RXR_ADDR);
  data = super.rd_data;
endtask

task automatic I2CTest::i2c_busy(output bit busy);
  this.read(`I2C_SR_ADDR);
  busy = super.rd_data[6] == 1'b1;
endtask

task automatic I2CTest::test_reset_reg();
  super.test_reset_reg();
  // verilog_format: off
  this.rd_check(`I2C_CTRL_ADDR, "CTRL REG", 32'b0 & {`I2C_CTRL_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`I2C_PSCR_ADDR, "PSCR REG", '1 & {`I2C_PSCR_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`I2C_TXR_ADDR, "TXR REG", 32'b0 & {`I2C_TXR_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`I2C_RXR_ADDR, "RXR REG", 32'b0 & {`I2C_RXR_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`I2C_CMD_ADDR, "CMD REG", 32'b0 & {`I2C_CMD_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  this.rd_check(`I2C_SR_ADDR, "SR REG", 32'b0 & {`I2C_SR_WIDTH{1'b1}}, Helper::EQUL, Helper::INFO);
  // verilog_format: on
endtask

task automatic I2CTest::test_wr_rd_reg(input bit [31:0] run_times = 1000);
  super.test_wr_rd_reg();
  // verilog_format: off
  for (int i = 0; i < run_times; i++) begin
    // this.wr_rd_check(`I2C_CTRL_ADDR, "CTRL REG", $random & {`I2C_CTRL_WIDTH{1'b1}}, Helper::EQUL);
    // this.wr_rd_check(`I2C_PSCR_ADDR, "PSCR REG", $random & {`I2C_PSCR_WIDTH{1'b1}}, Helper::EQUL);
    // this.wr_rd_check(`I2C_TXR_ADDR, "TXR REG", $random & {`I2C_TXR_WIDTH{1'b1}}, Helper::EQUL);
  end
  // verilog_format: on
endtask

task automatic I2CTest::test_i2c_24lc04a_wr_rd();
  $display("=== [test i2c wr] ===");
  // why 5 ?: because ctrl need 5 phase to send/receive one bit
  this.normal_mode_pscr = 199;  // APB: 100MHz / (5 * 100KHz) - 1
  // this.normal_mode_pscr = 49;  // APB: 100MHz / (5 * 400KHz) - 1
  this.slave_addr       = 32'hA0;
  repeat (200) @(posedge this.apb4.pclk);
  this.i2c_setup(this.normal_mode_pscr, 1'b1);



  //byte/page write
  this.i2c_send_data(this.slave_addr);
  this.i2c_send_cmd(`I2C_TEST_START_WRITE);
  this.i2c_get_ack();

  this.i2c_send_data(32'b0);  // write sub addr
  this.i2c_send_cmd(`I2C_TEST_WRITE);
  this.i2c_get_ack();

  // tHDDAT can ben zero, so maybe can ignore the error tHDSTA timing check
  for (int i = 0; i < this.page_wr_rd_num; i++) begin
    $display("%t %d page wr", $time, i+1);
    this.i2c_send_data(i+1);
    this.i2c_send_cmd(`I2C_TEST_WRITE);
    this.i2c_get_ack();
  end
  this.i2c_send_cmd(`I2C_TEST_STOP);
  do begin
    this.i2c_busy(this.rd_val);
  end while (this.rd_val == 1'b1);



  //byte/page read
  this.i2c_send_data(this.slave_addr);
  this.i2c_send_cmd(`I2C_TEST_START_WRITE);
  this.i2c_get_ack();

  this.i2c_send_data(32'b0);  // write sub addr
  this.i2c_send_cmd(`I2C_TEST_WRITE);
  this.i2c_get_ack();
  this.i2c_send_cmd(`I2C_TEST_STOP);
  do begin
    this.i2c_busy(this.rd_val);
  end while (this.rd_val == 1'b1);

  this.i2c_send_data(this.slave_addr + 1'b1);
  this.i2c_send_cmd(`I2C_TEST_START_WRITE);
  this.i2c_get_ack();

  for (int i = 0; i < this.page_wr_rd_num; i++) begin
    this.i2c_send_cmd(`I2C_TEST_READ);

    this.i2c_get_ack();
    this.i2c_get_data(this.rd_val);
    $display("%t cnt: %d rd_val: %h", $time, i, this.rd_val);
  end
  this.i2c_send_cmd(`I2C_TEST_STOP);
  do begin
    this.i2c_busy(this.rd_val);
  end while (this.rd_val == 1'b1);


  //byte/page write
  this.i2c_send_data(this.slave_addr);
  this.i2c_send_cmd(`I2C_TEST_START_WRITE);
  this.i2c_get_ack();

  this.i2c_send_data(32'b0);  // write sub addr
  this.i2c_send_cmd(`I2C_TEST_WRITE);
  this.i2c_get_ack();

  // tHDDAT can ben zero, so maybe can ignore the error tHDSTA timing check
  for (int i = 0; i < this.page_wr_rd_num; i++) begin
    $display("%t %d page wr", $time, i+1);
    this.i2c_send_data(i+1);
    this.i2c_send_cmd(`I2C_TEST_WRITE);
    this.i2c_get_ack();
  end
  this.i2c_send_cmd(`I2C_TEST_STOP);
  do begin
    this.i2c_busy(this.rd_val);
  end while (this.rd_val == 1'b1);
endtask


task automatic I2CTest::test_irq(input bit [31:0] run_times = 10);
  super.test_irq();
endtask
`endif
