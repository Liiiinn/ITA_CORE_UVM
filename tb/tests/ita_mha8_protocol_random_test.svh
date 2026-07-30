`ifndef ITA_MHA8_PROTOCOL_RANDOM_TEST_SVH
`define ITA_MHA8_PROTOCOL_RANDOM_TEST_SVH

class ita_mha8_protocol_random_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_protocol_random_test)

    function new(string name = "ita_mha8_protocol_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function ita_mha8_vsequence create_vseq();
        ita_mha8_protocol_random_vsequence vseq;

        vseq = ita_mha8_protocol_random_vsequence::type_id::create("protocol_random_vseq");
        return vseq;
    endfunction : create_vseq

endclass : ita_mha8_protocol_random_test

`endif // ITA_MHA8_PROTOCOL_RANDOM_TEST_SVH
