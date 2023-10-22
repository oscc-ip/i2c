// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// gpio is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

// verilog_format: off
`define GPIO_PADDIR    4'b0000 //BASEADDR+0x00
`define GPIO_PADIN     4'b0001 //BASEADDR+0x04
`define GPIO_PADOUT    4'b0010 //BASEADDR+0x08
`define GPIO_INTEN     4'b0011 //BASEADDR+0x0C
`define GPIO_INTTYPE0  4'b0100 //BASEADDR+0x10
`define GPIO_INTTYPE1  4'b0101 //BASEADDR+0x14
`define GPIO_INTSTATUS 4'b0110 //BASEADDR+0x18
`define GPIO_IOFCFG    4'b0111 //BASEADDR+0x1C
// verilog_format: on

module apb4_i2c (
    // verilog_format: off
    apb4_if.slave apb4,
    // verilog_format: on
    input logic  scl_i,
    output logic scl_o,
    output logic scl_dir_o,
    input logic  sda_i,
    output logic sda_o,
    output logic sda_dir_o,
    output logic irq_o
);
endmodule
