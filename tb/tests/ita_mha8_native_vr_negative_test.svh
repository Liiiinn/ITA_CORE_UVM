`ifndef ITA_MHA8_NATIVE_VR_NEGATIVE_TEST_SVH
`define ITA_MHA8_NATIVE_VR_NEGATIVE_TEST_SVH

class ita_mha8_native_vr_negative_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_native_vr_negative_test)

    function new(string name = "ita_mha8_native_vr_negative_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        ita_mha8_protocol_random_vsequence vseq;

        phase.raise_objection(this);
        vif.native_vr_violation_seen = 1'b0;
        vseq = ita_mha8_protocol_random_vsequence::type_id::create("native_vr_negative_vseq");
        vseq.start(env.vsqr);
        phase.drop_objection(this);
    endtask : run_phase

endclass : ita_mha8_native_vr_negative_test

`endif // ITA_MHA8_NATIVE_VR_NEGATIVE_TEST_SVH
