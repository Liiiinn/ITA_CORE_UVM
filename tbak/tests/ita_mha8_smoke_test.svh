`ifndef ITA_MHA8_SMOKE_TEST_SVH
`define ITA_MHA8_SMOKE_TEST_SVH

class ita_mha8_smoke_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_smoke_test)

    function new(string name = "ita_mha8_smoke_test", uvm_component parent = null);
        super.new(name, parent);       
    endfunction

    task run_phase(uvm_phase phase);
        ita_mha8_base_seq ctrl_seq;
        ita_mha8_stream_smoke_seq inp_seq;
    
        phase.raise_objection(this);

        ctrl_seq = ita_mha8_base_seq::type_id::create("ctrl_seq");
        inp_seq = ita_mha8_stream_smoke_seq::type_id::create("seq");
        ctrl_seq.start(env.ctrl_agt.sqr);
        inp_seq.start(env.input_agt[0].sqr);
        repeat (5) @(posedge vif.clk_i);
        
        phase.drop_objection(this);
    endtask : run_phase
endclass

`endif // ITA_MHA8_SMOKE_TEST_SVH