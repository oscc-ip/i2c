// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// i2c is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_I2C_DEF_SV
`define INC_I2C_DEF_SV

/* register mapping
 * I2C_CTRL:
 * BITS:   | 31:8 | 7  | 6   | 5:0  |
 * FIELDS: | RES  | EN | IEN | RES  |
 * PERMS:  | NONE | RW | RW  | NONE |
 * ----------------------------------------------------------
 * I2C_PSCR:
 * BITS:   | 31:16 | 15:0 |
 * FIELDS: | RES   | PSCR |
 * PERMS:  | NONE  | RW   |
 * ----------------------------------------------------------
 * I2C_TXR:
 * BITS:   | 31:8 | 7:0  |
 * FIELDS: | RES  | DATA |
 * PERMS:  | NONE | RW   |
 * ----------------------------------------------------------
 * I2C_RXR:
 * BITS:   | 31:8 | 7:0  |
 * FIELDS: | RES  | DATA |
 * PERMS:  | NONE | RO   |
 * ----------------------------------------------------------
 * I2C_CMD:
 * BITS:   | 31:8 | 7   | 6   | 5  | 4  | 3   | 2:1  | 0    |
 * FIELDS: | RES  | STA | STO | RD | WR | ACK | RES  | IACK |
 * PERMS:  | NONE | WO  | WO  | WO | WO | WO  | NONE | WO   |
 * ----------------------------------------------------------
 * I2C_SR:
 * BITS:   | 31:8 | 7   | 6   | 5  | 4:2  | 1   | 0  |
 * FIELDS: | RES  | RXK | BSY | AL | RES  | TIP | IF |
 * PERMS:  | NONE | RO  | RO  | RO | NONE | RO  | RO |
 * ----------------------------------------------------------
*/

// verilog_format: off
`define I2C_CTRL 4'b0000 // BASEADDR + 0x00
`define I2C_PSCR 4'b0001 // BASEADDR + 0x04
`define I2C_TXR  4'b0010 // BASEADDR + 0x08
`define I2C_RXR  4'b0011 // BASEADDR + 0x0C
`define I2C_CMD  4'b0100 // BASEADDR + 0x10
`define I2C_SR   4'b0101 // BASEADDR + 0x14

`define I2C_CTRL_ADDR {26'b0, `I2C_CTRL, 2'b00}
`define I2C_PSCR_ADDR {26'b0, `I2C_PSCR, 2'b00}
`define I2C_TXR_ADDR  {26'b0, `I2C_TXR , 2'b00}
`define I2C_RXR_ADDR  {26'b0, `I2C_RXR , 2'b00}
`define I2C_CMD_ADDR  {26'b0, `I2C_CMD , 2'b00}
`define I2C_SR_ADDR   {26'b0, `I2C_SR  , 2'b00}

`define I2C_CTRL_WIDTH 8
`define I2C_PSCR_WIDTH 16
`define I2C_TXR_WIDTH  8
`define I2C_RXR_WIDTH  8
`define I2C_CMD_WIDTH  8
`define I2C_SR_WIDTH   8

`define I2C_PSCR_MAX_VAL {(`I2C_PSCR_WIDTH){1'b1}}

`define I2C_CMD_NOP   4'b0000
`define I2C_CMD_START 4'b0001
`define I2C_CMD_STOP  4'b0010
`define I2C_CMD_WRITE 4'b0100
`define I2C_CMD_READ  4'b1000
// verilog_format: on

interface i2c_if ();
  logic scl_i;
  logic scl_o;
  logic scl_dir_o;
  logic sda_i;
  logic sda_o;
  logic sda_dir_o;
  logic irq_o;

  modport dut(
      input scl_i,
      output scl_o,
      output scl_dir_o,
      input sda_i,
      output sda_o,
      output sda_dir_o,
      output irq_o
  );

  modport tb(
      output scl_i,
      input scl_o,
      input scl_dir_o,
      output sda_i,
      input sda_o,
      input sda_dir_o,
      input irq_o
  );
endinterface

`endif
