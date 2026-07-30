`ifndef ITA_MHA8_COVERAGE_TARGET_TEST_SVH
`define ITA_MHA8_COVERAGE_TARGET_TEST_SVH

class ita_mha8_coverage_target_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_coverage_target_test)

    function new(string name = "ita_mha8_coverage_target_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function ita_mha8_vsequence create_vseq();
        ita_mha8_coverage_target_vsequence vseq;

        vseq = ita_mha8_coverage_target_vsequence::type_id::create("coverage_target_vseq");
        return vseq;
    endfunction : create_vseq

endclass : ita_mha8_coverage_target_test

`endif // ITA_MHA8_COVERAGE_TARGET_TEST_SVH
