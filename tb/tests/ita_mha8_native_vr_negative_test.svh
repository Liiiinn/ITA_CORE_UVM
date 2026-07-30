`ifndef ITA_MHA8_NATIVE_VR_NEGATIVE_TEST_SVH
`define ITA_MHA8_NATIVE_VR_NEGATIVE_TEST_SVH

class ita_mha8_native_vr_negative_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_native_vr_negative_test)

    function new(string name = "ita_mha8_native_vr_negative_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function ita_mha8_vsequence create_vseq();
        ita_mha8_protocol_random_vsequence vseq;

        vseq = ita_mha8_protocol_random_vsequence::type_id::create("native_vr_negative_vseq");
        return vseq;
    endfunction : create_vseq

    virtual task pre_vseq_start();
        vif.native_vr_violation_seen = 1'b0;
    endtask : pre_vseq_start

endclass : ita_mha8_native_vr_negative_test

`endif // ITA_MHA8_NATIVE_VR_NEGATIVE_TEST_SVH
