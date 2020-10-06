`timescale 1ns/1ps
`define halfperiod 50

import uvm_pkg::*;
 `include "uvm_macros.svh"

interface m1_intf(input sclk, input rstn);
  logic [3:0] data;
  logic ack;
  clocking drv_ck @(posedge sclk);
    default input #1ps output #1ps;
	input ack;
	output data;
  endclocking
  clocking mon_ck @(posedge sclk);
    default input #1ps output #1ps;
	input ack,data;
  endclocking
endinterface

interface m2_intf(input sclk, input rstn);
  logic [15:0] data_16b;
  clocking mon_ck @(posedge sclk);
    default input #1ps output #1ps;
	input data_16b;
  endclocking
endinterface

//create this interface for M1 timing check
interface dt_intf(input sclk,input rstn);
  logic ack,scl,sda;
  clocking mon_ck @(posedge sclk);
    default input #1ps output #1ps;
    input ack,scl,sda;
  endclocking  

  property sda_afer_ack;
    @(negedge sclk) $rose(ack)|=>$rose(sda);
  endproperty:sda_afer_ack
  assert property(sda_afer_ack) else `uvm_error("ASSERT","ack is not rise after ack")
  
  property sda_down_while_scl_high;
    @(negedge sclk) ($rose(sda) ##[1:2] $fell(sda))and(ack)  |-> $fell(scl);//注意$rose和$fell的判定机制
  endproperty:sda_down_while_scl_high
  assert property(sda_down_while_scl_high) else `uvm_error("ASSERT","sda fell assertion 1 error")
  
  property sda_down_while_scl_high2;
    @(negedge sclk) ($rose(sda) ##2 $fell(sda))and(!ack) |-> $rose(scl);
  endproperty:sda_down_while_scl_high2
  assert property(sda_down_while_scl_high2) else `uvm_error("ASSERT","sda fell assertion 2 error")  
  
  initial begin: assertion_control
    fork
      forever begin
        wait(rstn == 0);
        $assertoff();
        wait(rstn == 1);
        $asserton();
      end
    join_none
  end
endinterface




module tb;
logic sclk;
logic rstn;

initial begin
  rstn = 1;
  sclk = 0;
  #10 rstn = 0;
  #(`halfperiod*2+3) rstn = 1;
  forever begin 
		#(`halfperiod) sclk = ~sclk;
  end
end

top top_inst(
  	.rst(rstn),
	.sclk(sclk),
	.data(m1_if.data),
	.ack(m1_if.ack),
	.outhigh(m2_if.data_16b)
	);

import uvm_pkg::*;
 `include "uvm_macros.svh"
import dt_pkg::*;	
	
m1_intf m1_if(.*);
m2_intf m2_if(.*);
dt_intf dt_if(.*);

assign dt_if.ack = tb.top_inst.ack_m1_m0;
assign dt_if.scl = tb.top_inst.slc_m1_m2;
assign dt_if.sda = tb.top_inst.sda_m1_m2;

initial begin
  uvm_config_db#(virtual m1_intf)::set(uvm_root::get(), "uvm_test_top.env.m1_agt", "m1_vif", m1_if);
  uvm_config_db#(virtual m1_intf)::set(uvm_root::get(), "uvm_test_top.env.m2_agt", "m1_vif", m1_if);
  uvm_config_db#(virtual m2_intf)::set(uvm_root::get(), "uvm_test_top.env.m2_agt", "m2_vif", m2_if);
  uvm_config_db#(virtual m2_intf)::set(uvm_root::get(), "uvm_test_top.env.chker.*", "m2_vif", m2_if);
  run_test("mcdf_data_consistence_basic_test");
end



/*
//每次请求新数据信号正跳边沿，等一段时间后将输出数据增加1
always @(posedge ask_for_data)
begin
  #(`halfperiod/2 +3) data = data +1; 
end
*/




endmodule