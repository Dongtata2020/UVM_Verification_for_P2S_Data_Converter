package m1_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  class m1_trans extends uvm_sequence_item;
    rand logic [3:0] data[];
	rand int data_ud_dly;
	bit rsp;
	
	constraint cstr{
	  soft data.size inside {4,8,12,16,20,24,28,32,36,40,44,48,52,56,60,64};
	  foreach(data[i]) soft data[i] == i;
	  soft data_ud_dly inside{[0:6]};
	};
    
	`uvm_object_utils_begin(m1_trans)
	  `uvm_field_array_int(data,UVM_ALL_ON)
	  `uvm_field_int(rsp,UVM_ALL_ON)
	  `uvm_field_int(data_ud_dly,UVM_ALL_ON)
	`uvm_object_utils_end
	
	function new(string name = "m1_trans");
	  super.new(name);
	endfunction
  endclass : m1_trans
  
  
  class m1_driver extends uvm_driver #(m1_trans);
    local virtual m1_intf intf;
	
	`uvm_component_utils(m1_driver)
	
	function new(string name = "m1_driver", uvm_component parent);
	  super.new(name,parent);
	endfunction
  
    function void set_interface(virtual m1_intf intf);
	  if(intf == null)
	    $error("interface handl is NULL, plesae check if targeet interface has been intantiated");
	  else 
	    this.intf = intf;
	endfunction
  
    task run_phase(uvm_phase phase);
	  fork
	    do_drive();
		do_reset();
	  join
	endtask
	
	extern task do_drive();
	extern task do_reset();
	extern task do_write(input m1_trans t);
	//extern task m1_idle();
  endclass : m1_driver
  
  task m1_driver::do_drive();
    m1_trans req,rsp;
	@(posedge intf.rstn);
	forever begin
	  seq_item_port.get_next_item(req);
	  m1_driver::do_write(req);
	  void'($cast(rsp,req.clone()));
	  rsp.rsp = 1;
	  rsp.set_sequence_id(req.get_sequence_id());
	  seq_item_port.item_done(rsp);	
	end
  endtask
  
  task m1_driver::do_reset();
    forever begin
	  @(negedge intf.rstn);
	  intf.data <= 'd0;
	end
  endtask
  
  task m1_driver::do_write(input m1_trans t);
    logic [3:0] databuf;
	logic [3:0] parity = 0;	
    foreach(t.data[i]) begin
	  @(posedge intf.ack);
	  fork 
	    begin
		  @(negedge intf.ack);
		  `uvm_info(get_type_name(),$sformatf("sent data 4'b%x",t.data[i]),UVM_HIGH)
		end
		begin
		  repeat(t.data_ud_dly) @(posedge intf.sclk);//update data for next transform.//data_ud_dly 为数据更新的时间延迟
		  if(i == t.data.size() + 1) begin //最后一位，奇偶位
		    intf.drv_ck.data <= parity;
		    `uvm_info(get_type_name(),$sformatf("update first data is 4'b%x",parity),UVM_HIGH)			
		  end
		  else if(i == 0) begin  	
			intf.drv_ck.data <= t.data.size()/4;
			`uvm_info(get_type_name(),$sformatf("update first data is 4'b%x",t.data.size()),UVM_HIGH)
		  end
		  else begin
		    parity[0] = ^{t.data[i-1],parity};//对所有数据求奇偶
		    intf.drv_ck.data <= t.data[i-1];
		    `uvm_info(get_type_name(),$sformatf("update data is 4'b%x",t.data[i]),UVM_HIGH)		    
		  end
		end
	  join	  
	end
  endtask 
  
  
  
  
  class m1_sequencer extends uvm_sequencer #(m1_trans);
    `uvm_component_utils(m1_sequencer)
    function new (string name = "m1_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass: m1_sequencer
  
  
  
  class m1_data_sequence extends uvm_sequence #(m1_trans);
    rand bit [3:0] data[];
	rand int data_ud_dly;
	rand int data_size = -1;
	constraint cstr{
	  soft data_size == -1;
	  soft data_ud_dly == -1;
	  soft data.size() == data_size+2;
	  foreach(data[i]) soft data[i] == i;
	};
	
    `uvm_object_utils_begin(m1_data_sequence)
      `uvm_field_int(data_ud_dly, UVM_ALL_ON)
	  `uvm_field_int(data_size, UVM_ALL_ON)
    `uvm_object_utils_end
    `uvm_declare_p_sequencer(m1_sequencer)	  
	
    function new(string name = "m1_data_sequence");
	  super.new(name);
	endfunction
	
	task body();
	  send_trans();	
	endtask:body
	
	function void post_randomize();
      string s;
      s = {s, "AFTER RANDOMIZATION \n"};
      s = {s, "=======================================\n"};
      s = {s, "m1_data_sequence object content is as below: \n"};
      s = {s, super.sprint()};
      s = {s, "=======================================\n"};
      `uvm_info(get_type_name(), s, UVM_HIGH)
    endfunction
	
	extern task send_trans();
  endclass: m1_data_sequence
  
  task m1_data_sequence::send_trans();
    m1_trans req,rsp;
	`uvm_do_with(req,{local::data_ud_dly>=0 -> data_ud_dly == local::data_ud_dly;
						local::data_size >0 -> data.size() == local::data_size+2;//包头和包尾为“总量/4”和“奇偶位”
						foreach(local::data[i]) local::data[i]>=0 -> data[i] == local::data[i];
					})
	`uvm_info(get_type_name(),req.sprint(),UVM_HIGH)
	get_response(rsp);
	`uvm_info(get_type_name(),rsp.sprint(),UVM_HIGH)
	assert(rsp.rsp)
	  else $error("[RSPERR] %0t error response received!", $time);
  endtask
  

	
  
  
  class m1_mon_trans extends uvm_sequence_item;
    logic [3:0] data;
	realtime start_time;
    `uvm_object_utils(m1_mon_trans)
    function new (string name = "m1_mon_trans");
      super.new(name);
    endfunction	
  endclass: m1_mon_trans
  
  
  class m1_monitor extends uvm_monitor;
    local virtual m1_intf intf;
	uvm_analysis_port #(m1_mon_trans) mon_ana_port;
	
    `uvm_component_utils(m1_monitor)
    function new(string name="m1_monitor", uvm_component parent);
      super.new(name, parent);
      mon_ana_port = new("mon_ana_port", this);
    endfunction	
	
    function void set_interface(virtual m1_intf intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction	
  
    task run_phase(uvm_phase phase);
      this.mon_trans();
    endtask
	
	task mon_trans();
	  m1_mon_trans m;
	  forever begin
	    @(posedge intf.ack);
		m = m1_mon_trans::type_id::create("m");
		m.data = intf.mon_ck.data;
	    m.start_time = $realtime();
		mon_ana_port.write(m);
		`uvm_info(get_type_name(),$sformatf("monitored M1 data 4'b%x",m.data),UVM_HIGH);
	  end
	endtask
  endclass : m1_monitor
  
  
  
  class m1_agent extends uvm_agent;
    m1_driver driver;
	m1_monitor monitor;
	m1_sequencer sequencer;
	local virtual m1_intf m1_vif;
	
    `uvm_component_utils(m1_agent)

    function new(string name = "m1_agent", uvm_component parent);
      super.new(name, parent);
    endfunction	
  
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      // get virtual interface
      if(!uvm_config_db#(virtual m1_intf)::get(this,"","m1_vif", m1_vif)) begin
        `uvm_fatal("GETVIF","cannot get m1_vif handle from config DB")
      end
      driver = m1_driver::type_id::create("driver", this);
      monitor = m1_monitor::type_id::create("monitor", this);
      sequencer = m1_sequencer::type_id::create("sequencer", this);
    endfunction
	
	function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
      this.set_interface(m1_vif);
    endfunction

    function void set_interface(virtual m1_intf vif);
      driver.set_interface(vif);
      monitor.set_interface(vif);
    endfunction
  endclass:m1_agent
  
endpackage