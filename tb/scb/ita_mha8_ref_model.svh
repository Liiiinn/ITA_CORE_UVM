`ifndef ITA_MHA8_REF_MODEL_SVH
`define ITA_MHA8_REF_MODEL_SVH

class ita_mha8_ref_model extends uvm_component;
    `uvm_component_utils(ita_mha8_ref_model)

    uvm_analysis_imp_ctrl #(ita_ctrl_item, ita_mha8_ref_model) ctrl_imp;
    uvm_analysis_imp_stream #(ita_stream_item, ita_mha8_ref_model) stream_imp;
    uvm_analysis_port #(ita_stream_item) expected_ap;
    // TODO Stage 11: define ref-model inputs and expected output publication after smoke scoreboard exists.

    function new(string name = "ita_mha8_ref_model", uvm_component parent = null);
        super.new(name, parent);
        ctrl_imp = new("ctrl_imp", this);
        stream_imp = new("stream_imp", this);
        expected_ap = new("expected_ap", this);
    endfunction : new

    function void write_ctrl(ita_ctrl_item tr);
        // TODO Stage 11: consume shared MHA8 ctrl transaction for golden-model setup.
    endfunction : write_ctrl

    function void write_stream(ita_stream_item tr);
        // TODO Stage 11: consume input/weight/bias payloads and publish expected outputs.
    endfunction : write_stream

endclass : ita_mha8_ref_model

`endif // ITA_MHA8_REF_MODEL_SVH
