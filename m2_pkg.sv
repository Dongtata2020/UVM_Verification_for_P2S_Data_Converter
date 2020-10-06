package m2_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  class m2_trans extends uvm_sequence_item;
    logic [15:0] data_16b;
	bit [15:0] first_data;
	bit [15:0] last_data;
    bit rsp;
	realtime start_time;

    `uvm_object_utils_begin(m2_trans)
      `uvm_field_int(data_16b, UVM_ALL_ON)
      `uvm_field_int(rsp, UVM_ALL_ON)
	  `uvm_field_int(first_data, UVM_ALL_ON)
	  `uvm_field_int(last_data, UVM_ALL_ON)
    `uvm_object_utils_end

    function new (string name = "m2_trans");
      super.new(name);
    endfunction  
  endclass:m2_trans



  class m2_driver extends uvm_driver #(m2_trans);
	`uvm_component_utils(m2_driver)
	
	function new(string name = "m2_driver", uvm_component parent);
	  super.new(name,parent);
	endfunction    
  endclass:m2_driver



  class m2_monitor extends uvm_monitor;
    local virtual m2_intf intf;
	local virtual m1_intf m1_vif;
	uvm_analysis_port #(m2_trans) mon_ana_port;
	
    `uvm_component_utils(m2_monitor)
    function new(string name="m2_monitor", uvm_component parent);
      super.new(name, parent);
      mon_ana_port = new("mon_ana_port", this);
    endfunction	
	
    function void set_interface(virtual m2_intf intf,virtual m1_intf m1_vif);
      if(intf == null)
        $error("m2 interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
	  if(m1_vif == null)
        $error("m1 interface handle is NULL, please check if target interface has been intantiated");
      else
        this.m1_vif = m1_vif;
    endfunction	
  
    task run_phase(uvm_phase phase);
      this.mon_trans();
    endtask
	
	task mon_trans();
	  m2_trans m;
	  forever begin
	    @(posedge m1_vif.ack);
		m = m2_trans::type_id::create("m");
		m.data_16b = intf.mon_ck.data_16b;
		if($isunknown(m.data_16b)) continue;
	    m.start_time = $realtime();
		mon_ana_port.write(m);
		`uvm_info(get_type_name(),$sformatf("monitored M2 data 4'b%x",m.data_16b),UVM_HIGH);
	  end
	endtask
  endclass : m2_monitor



  class m2_agent extends uvm_agent;
    m2_driver driver;
	m2_monitor monitor;
	local virtual m2_intf m2_vif;
	local virtual m1_intf m1_vif;
	
    `uvm_component_utils(m2_agent)

    function new(string name = "m2_agent", uvm_component parent);
      super.new(name, parent);
    endfunction	
  
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // get virtual interface
      if(!uvm_config_db#(virtual m2_intf)::get(this,"","m2_vif", m2_vif)) begin
        `uvm_fatal("GETVIF","cannot get m2_vif handle from config DB")
      end
      if(!uvm_config_db#(virtual m1_intf)::get(this,"","m1_vif", m1_vif)) begin
        `uvm_fatal("GETVIF","cannot get m1_vif handle from config DB")
      end	  
      monitor = m2_monitor::type_id::create("monitor", this);
    endfunction
	
	function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      this.set_interface(m1_vif,m2_vif);	  
    endfunction

    function void set_interface(virtual m1_intf vif,virtual m2_intf m2_vif);
      monitor.set_interface(m2_vif,vif);
    endfunction  
  
  endclass:m2_agent


endpackage