package dt_pkg;
  
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import m1_pkg::*;
  import m2_pkg::*;
  
  class dt_refmod extends uvm_component;
    uvm_blocking_get_peek_port #(m1_mon_trans) in_bgpk_port;
	uvm_tlm_analysis_fifo #(m2_trans) out_tlm_fifo;
    
    `uvm_component_utils(dt_refmod) 
    function new (string name = "dt_refmod", uvm_component parent);
      super.new(name, parent);
      in_bgpk_port = new(("in_bgpk_port"), this);
      out_tlm_fifo = new(("out_tlm_fifo"), this);
    endfunction	

    task run_phase(uvm_phase phase);
	  do_ref();
    endtask	
	
	task do_ref();
	  m1_mon_trans m1;
	  m2_trans m2;
	  int i;
	  int dt_cnt = 0;
	  int length = 64;
	  logic [3:0] data_buf = 0;
	  forever begin	  
	    this.in_bgpk_port.get(m1);
		`uvm_info(get_type_name(),$sformatf("refmod get m1 data :\n %h", m1.data), UVM_MEDIUM)
		data_buf = m1.data;
		m2 = new();
		if(data_buf == 0) begin
		  m2.data_16b = 16'h8000;
		  this.out_tlm_fifo.put(m2);	
		  continue;
		end		
		else begin//如果输入的数不为0，则找出其哪一位为1
		  m2.data_16b = 16'd0;
		  m2.data_16b[data_buf-1] = 1;
		/*
	  	  for(i=0;i<16;i++) begin			
		    if(m1.data == i) begin
			  m2.data_16b[i-1] = 1;
		    end
		    else m2.data_16b[i] = 0;
		  end	
		*/		  
		end
		
		if(dt_cnt == 1) begin	//获取传输数据个数
		  length = m1.data;
		end
		else if(dt_cnt == length + 1) begin 
		  dt_cnt = 0;
		end
		dt_cnt = dt_cnt +1;
		this.out_tlm_fifo.put(m2);	
		`uvm_info(get_type_name(),$sformatf("refmod sent m1 expect data :\n %h", m2.data_16b), UVM_MEDIUM)
	  end	
	endtask
  endclass: dt_refmod



  class dt_coverage extends uvm_component;
    local virtual m2_intf m2_vif;
    `uvm_component_utils(dt_coverage)
	
	covergroup outdata;
	  coverpoint m2_vif.mon_ck.data_16b{
	    bins is_0 = {16'h8000};
		bins is_1 = {16'h0001};
		bins is_2 = {16'h0002};
		bins is_3 = {16'h0004};
		bins is_4 = {16'h0008};
		bins is_5 = {16'h0010};
		bins is_6 = {16'h0020};
		bins is_7 = {16'h0040};
		bins is_8 = {16'h0080};
		bins is_9 = {16'h0100};
		bins is_10 = {16'h0200};
		bins is_11 = {16'h0400};
		bins is_12 = {16'h0800};
		bins is_13 = {16'h1000};
		bins is_14 = {16'h2000};
		bins is_15 = {16'h4000};	  
	  }	
	endgroup	
	
    function new(string name = "dt_coverage",uvm_component parent);
	  super.new(name,parent);	
	  this.outdata = new();
	endfunction
	
	function void connect_phase(uvm_phase phase);
	  if(!uvm_config_db#(virtual m2_intf)::get(this,"","m2_vif", m2_vif)) 
        `uvm_fatal("GETVIF","cannot get m2_vif handle from config DB")	
	endfunction
	
	task run_phase(uvm_phase phase);
	  this.do_output_sample();
	endtask
	
	task do_output_sample();
	  forever begin
	    @(posedge m2_vif.sclk iff m2_vif.rstn);
		outdata.sample();		
	  end
	endtask:do_output_sample	
  endclass: dt_coverage


  
  class dt_checker extends uvm_scoreboard;
	dt_refmod refmod;
	dt_coverage covrge;
    local int err_count;
    local int total_count;	
	
    `uvm_component_utils(dt_checker)
	
	uvm_tlm_analysis_fifo #(m1_mon_trans) m1_tlm_fifo;//connect with refmod(input)
	uvm_tlm_analysis_fifo #(m2_trans) m2_tlm_fifo;//connect with compare
	uvm_blocking_get_port #(m2_trans) exp_bg_port;//connect with refmod(output)
	
    function new(string name = "dt_checker", uvm_component parent);
	  super.new(name, parent);
	  m1_tlm_fifo = new("m1_tlm_fifo",this);
	  m2_tlm_fifo = new("m2_tlm_fifo",this);
	  exp_bg_port = new("exp_bg_port",this);
	  this.err_count = 0;
      this.total_count = 0;
	endfunction
	
	function void build_phase(uvm_phase phase);
      super.build_phase(phase);
	  refmod = dt_refmod::type_id::create("refmod",this);
	  this.covrge = dt_coverage::type_id::create("covrge",this);
	endfunction
	
	function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
	  refmod.in_bgpk_port.connect(m1_tlm_fifo.blocking_get_peek_export);
	  exp_bg_port.connect(refmod.out_tlm_fifo.blocking_get_export);
	endfunction
	
	task run_phase(uvm_phase phase);
	  do_data_compare();
	endtask
	
	extern task do_data_compare();	
	
	function void report_phase(uvm_phase phase);	
	endfunction
  endclass: dt_checker

  task dt_checker::do_data_compare();
    m2_trans expt, mont;
	bit cmp;
	forever begin
	  this.m2_tlm_fifo.get(mont);
	  this.exp_bg_port.get(expt);
	  cmp = mont.compare(expt);  
	  this.total_count++;
        if(cmp == 0) begin
          this.err_count++; #1ns;
          `uvm_info("[CMPERR]", $sformatf("monitored m2 data :\n %h", mont.data_16b), UVM_MEDIUM)
          `uvm_info("[CMPERR]", $sformatf("expected m2 data :\n %h", expt.data_16b), UVM_MEDIUM)
          `uvm_error("[CMPERR]", $sformatf("%0dth times comparing but failed! DT monitored output packet is different with reference model output", this.total_count))
        end
        else begin
		  `uvm_info("[CMPSUC]", $sformatf("monitored m2 data :\n %h", mont.data_16b), UVM_MEDIUM)
          `uvm_info("[CMPSUC]", $sformatf("expected m2 data :\n %h", expt.data_16b), UVM_MEDIUM)
          `uvm_info("[CMPSUC]",$sformatf("%0dth times comparing and succeeded! DT monitored output packet is the same with reference model output", this.total_count), UVM_LOW)
        end	  
	end 
  endtask: do_data_compare

  
  
  class top_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
    m1_sequencer m1_sqr;
	`uvm_component_utils(top_virtual_sequencer)
   
    function new (string name = "top_virtual_sequencer", uvm_component parent);
      super.new(name, parent);
    endfunction
    
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);		  
	endfunction
  endclass: top_virtual_sequencer



  class dt_env extends uvm_env;
    m1_agent m1_agt;
	m2_agent m2_agt;
	dt_checker chker;
	top_virtual_sequencer top_vir_sqr;
    `uvm_component_utils(dt_env)	
    function new(string name = "dt_env", uvm_component parent);
	  super.new(name,parent);	
	endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
	  this.m1_agt = m1_agent::type_id::create("m1_agt",this);
	  this.m2_agt = m2_agent::type_id::create("m2_agt",this);
	  this.chker = dt_checker::type_id::create("chker",this);
	  this.top_vir_sqr = top_virtual_sequencer::type_id::create("top_vir_sqr",this);
	endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);	 
	  this.top_vir_sqr.m1_sqr = this.m1_agt.sequencer;
	  m1_agt.monitor.mon_ana_port.connect(chker.m1_tlm_fifo.analysis_export);
	  m2_agt.monitor.mon_ana_port.connect(chker.m2_tlm_fifo.analysis_export);
	endfunction
  endclass: dt_env



  class dt_top_sequence extends uvm_sequence #(uvm_sequence_item);
    m1_data_sequence m1_data_seq;
	
    `uvm_object_utils(dt_top_sequence)
    `uvm_declare_p_sequencer(top_virtual_sequencer)

    function new (string name = "dt_top_sequence");
      super.new(name);
    endfunction    
 
    virtual task body();
      `uvm_info(get_type_name(), "=====================STARTED=====================", UVM_LOW)      
	  fork
		this.data_transform();
	  join
      `uvm_info(get_type_name(), "=====================FINISHED=====================", UVM_LOW)
    endtask

    virtual task data_transform();
      //User to implment the task in the child virtual sequence
    endtask	
  endclass: dt_top_sequence



  class dt_top_test extends uvm_test;
    dt_env env;
    `uvm_component_utils(dt_top_test)

    function new(string name = "dt_top_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = dt_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      uvm_root::get().set_report_verbosity_level_hier(UVM_HIGH);
      uvm_root::get().set_report_max_quit_count(1);
      uvm_root::get().set_timeout(10ms);
    endfunction

    task run_phase(uvm_phase phase);
      // NOTE:: raise objection to prevent simulation stopping
      phase.raise_objection(this);
      this.run_top_virtual_sequence();
      // NOTE:: drop objection to request simulation stopping
	  #300us
      phase.drop_objection(this);
    endtask

    virtual task run_top_virtual_sequence();
      // User to implement this task in the child tests
    endtask  
  endclass: dt_top_test



  class basic_data_transform_vir_sequence extends dt_top_sequence;
    `uvm_object_utils(basic_data_transform_vir_sequence)
    function new (string name = "basic_data_transform_vir_sequence");
      super.new(name);
    endfunction    
    task data_transform();
	  `uvm_do_on_with(m1_data_seq,p_sequencer.m1_sqr,
						{data_size == 32;data_ud_dly == 2;} )	
	endtask
  endclass: basic_data_transform_vir_sequence



  class basic_data_transform_test extends dt_top_test;
    `uvm_component_utils(basic_data_transform_test)

    function new(string name = "basic_data_transform_test", uvm_component parent);
      super.new(name, parent);
    endfunction

    task run_top_virtual_sequence();
      basic_data_transform_vir_sequence top_seq = new();
      top_seq.start(env.top_vir_sqr);
    endtask     
  endclass: basic_data_transform_test


endpackage