/* 
 * sim_ibex.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2018-2020 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

timeunit 1ps;
timeprecision 1ps;

module sim_ibex #(
  parameter PROB_STALL = 0.1,
  parameter NC = 8,
  parameter MP = 4,
  parameter ID = 10,
  parameter MEMORY_SIZE = 256*1024,
  parameter BASE_ADDR = 0
)
(
  input logic clk_i,
  input logic clk_delayed_i,
  input logic rst_ni,
  input logic test_mode_i,
  input logic enable_i,
  input logic clear_i,
  input logic fetch_enable,       // 1'b0;
  input logic randomize_mem,      // 1'b0;
  input logic enable_mem,         // 1'b1;
  output logic flag
);

  hwpe_stream_intf_tcdm instr[0:0] (.clk(clk_i));
  hwpe_stream_intf_tcdm stack[0:0] (.clk(clk_i));
  hwpe_stream_intf_tcdm tcdm [0:0] (.clk(clk_i));

  logic [NC-1:0][1:0] evt;

  logic          instr_req;
  logic          instr_gnt;
  logic          instr_rvalid;
  logic [31:0]   instr_addr;
  logic [31:0]   instr_rdata;

  logic          data_req;
  logic          data_gnt;
  logic          data_rvalid;
  logic          data_we;
  logic [3:0]    data_be;
  logic [31:0]   data_addr;
  logic [31:0]   data_wdata;
  logic [31:0]   data_rdata;
  logic          data_err;

  // ATI timing parameters.
`ifndef VERILATOR
  parameter time TCP = 1.0ns; // clock period, 1GHz clock
  parameter time TA  = 0.2ns; // application time
  parameter time TT  = 0.8ns; // test time
`else
  parameter time TCP = 0; // clock period, 1 GHz clock
  parameter time TA  = 0; // application time
  parameter time TT  = 0; // test time
`endif

  // bindings

  always_comb
  begin : bind_instrs
    instr[0].req  = instr_req;
    instr[0].add  = instr_addr;
    instr[0].wen  = 1'b1;
    instr[0].be   = '0;
    instr[0].data = '0;
    instr_gnt    = instr[0].gnt;
    instr_rdata  = instr[0].r_data;
    instr_rvalid = instr[0].r_valid;
  end

  always_comb
  begin : bind_stack
    stack[0].req  = data_req & (data_addr[31:24] == '0);
    stack[0].add  = data_addr;
    stack[0].wen  = ~data_we;
    stack[0].be   = data_be;
    stack[0].data = data_wdata;
  end

  assign tcdm[0].req  = data_req & (data_addr[31:24] != '0);
  assign tcdm[0].add  = {8'b0, data_addr[23:0]};
  assign tcdm[0].wen  = ~data_we;
  assign tcdm[0].be   = data_be;
  assign tcdm[0].data = data_wdata;
  assign data_gnt    = stack[0].req ? stack[0].gnt : tcdm[0].gnt;
  assign data_rdata  = stack[0].r_valid ? stack[0].r_data : tcdm[0].r_data;
  assign data_rvalid = stack[0].r_valid | tcdm[0].r_valid;

  tb_dummy_memory #(
    .MP          ( 1           ),
    .MEMORY_SIZE ( MEMORY_SIZE ),
    .BASE_ADDR   ( BASE_ADDR   ),
    .PROB_STALL  ( PROB_STALL  ),
    .TCP         ( TCP         ),
    .TA          ( TA          ),
    .TT          ( TT          )
  ) i_dummy_memory (
    .clk_i         ( clk_i         ),
    .clk_delayed_i ( clk_delayed_i ),
    .randomize_i   ( randomize_mem ),
    .enable_i      ( enable_mem    ),
    .stallable_i   ( 1'b1          ),
    .tcdm          ( tcdm          )
  );

  tb_dummy_memory #(
    .MP          ( 1           ),
    .MEMORY_SIZE ( MEMORY_SIZE ),
    .BASE_ADDR   ( BASE_ADDR   ),
    .PROB_STALL  ( 0           ),
    .TCP         ( TCP         ),
    .TA          ( TA          ),
    .TT          ( TT          )
  ) i_dummy_instr_memory (
    .clk_i       ( clk_i ),
    .clk_delayed_i ( clk_delayed_i ),
    .randomize_i ( 1'b0  ),
    .enable_i    ( 1'b1  ),
    .stallable_i ( 1'b0  ),
    .tcdm        ( instr )
  );

  tb_dummy_memory #(
    .MP          ( 1           ),
    .MEMORY_SIZE ( MEMORY_SIZE ),
    .BASE_ADDR   ( BASE_ADDR   ),
    .PROB_STALL  ( 0           ),
    .TCP         ( TCP         ),
    .TA          ( TA          ),
    .TT          ( TT          )
  ) i_dummy_stack_memory (
    .clk_i         ( clk_i         ),
    .clk_delayed_i ( clk_delayed_i ),
    .randomize_i   ( 1'b0          ),
    .enable_i      ( 1'b1          ),
    .stallable_i   ( 1'b0          ),
    .tcdm          ( stack         )
  );

  zeroriscy_core #(
    .N_EXT_PERF_COUNTERS ( 0 ),
    .RV32E               ( 0 ),
    .RV32M               ( 1 )
  ) i_ibex (
    .clk_i               ( clk_i        ),
    .rst_ni              ( rst_ni       ),
    .clock_en_i          ( 1'b1         ),
    .test_en_i           ( 1'b0         ),
    .core_id_i           ( '0           ),
    .cluster_id_i        ( '0           ),
    .boot_addr_i         ( '0           ),
    .instr_req_o         ( instr_req    ),
    .instr_gnt_i         ( instr_gnt    ),
    .instr_rvalid_i      ( instr_rvalid ),
    .instr_addr_o        ( instr_addr   ),
    .instr_rdata_i       ( instr_rdata  ),
    .data_req_o          ( data_req     ),
    .data_gnt_i          ( data_gnt     ),
    .data_rvalid_i       ( data_rvalid  ),
    .data_we_o           ( data_we      ),
    .data_be_o           ( data_be      ),
    .data_addr_o         ( data_addr    ),
    .data_wdata_o        ( data_wdata   ),
    .data_rdata_i        ( data_rdata   ),
    .data_err_i          ( data_err     ),
    .irq_i               ( evt[0][0]    ),
    .irq_id_i            ( '0           ),
    .irq_ack_o           (              ),
    .irq_id_o            (              ),
    .debug_req_i         ( '0           ),
    .debug_gnt_o         (              ),
    .debug_rvalid_o      (              ),
    .debug_addr_i        ( '0           ),
    .debug_we_i          ( '0           ),
    .debug_wdata_i       ( '0           ),
    .debug_rdata_o       (              ),
    .debug_halted_o      (              ),
    .debug_halt_i        ( '0           ),
    .debug_resume_i      ( '0           ),
    .fetch_enable_i      ( fetch_enable ),
    .ext_perf_counters_i ( '0           )
  );

  import "DPI-C" function string my_getenv(input string env_name);

  initial begin
    // load instruction memory
    $readmemh(my_getenv("IBEX_TB_STIM_INSTR"), sim_ibex.i_dummy_instr_memory.memory);
    $readmemh(my_getenv("IBEX_TB_STIM_DATA"), sim_ibex.i_dummy_memory.memory);
    $display("Welcome to the Ibex testbench!");
  end

  int returned = -1;

  assign flag = sim_ibex.i_ibex.sleeping & (returned!=-1);

  always_ff @(posedge clk_i)
  begin
    if((data_addr == 32'h80000000) && (data_we & data_req == 1'b1))
      returned = data_wdata;
  end

  int cnt = 0;
  always_ff @(posedge clk_i)
  begin
    if(flag) begin
      if(cnt == 0) begin
        $display("errors=%08x", returned);
      end
      else if(cnt > 10) begin
        $finish;
      end
      cnt += 1;
    end
  end

endmodule // sim_ibex
