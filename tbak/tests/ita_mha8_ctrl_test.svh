`ifndef ITA_MHA8_CTRL_TEST_SVH
`define ITA_MHA8_CTRL_TEST_SVH

class ita_mha8_ctrl_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_ctrl_test)

    function new(string name = "ita_mha8_ctrl_test", uvm_component parent = null);
        super.new(name, parent);       
    endfunction

    task run_phase(uvm_phase phase);
        ita_mha8_base_seq seq;
    
        phase.raise_objection(this);
        seq = ita_mha8_base_seq::type_id::create("seq");
        seq.start(env.ctrl_agt.sqr);
        repeat (5) @(posedge vif.clk_i);
        phase.drop_objection(this);
    endtask : run_phase
endclass

`endif // ITA_MHA8_CTRL_TEST_SVH