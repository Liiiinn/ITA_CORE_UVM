`ifndef ITA_MHA8_COVERAGE_TARGET_TEST_SVH
`define ITA_MHA8_COVERAGE_TARGET_TEST_SVH

class ita_mha8_coverage_target_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_coverage_target_test)

    function new(string name = "ita_mha8_coverage_target_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        ita_mha8_coverage_target_vsequence vseq;

        phase.raise_objection(this);
        vseq = ita_mha8_coverage_target_vsequence::type_id::create("coverage_target_vseq");
        vseq.start(env.vsqr);
        phase.drop_objection(this);
    endtask : run_phase

endclass : ita_mha8_coverage_target_test

`endif // ITA_MHA8_COVERAGE_TARGET_TEST_SVH
