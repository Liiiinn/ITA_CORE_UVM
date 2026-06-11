`ifndef ITA_MHA8_REF_MODEL_SVH
`define ITA_MHA8_REF_MODEL_SVH

class ita_mha8_ref_model extends uvm_component;
    `uvm_component_utils(ita_mha8_ref_model)

    uvm_analysis_imp_ctrl #(ita_ctrl_item, ita_mha8_ref_model) ctrl_imp;
    uvm_analysis_imp_stream #(ita_stream_item, ita_mha8_ref_model) stream_imp;
    uvm_analysis_port #(ita_stream_item) expected_ap;

    function new(string name = "ita_mha8_ref_model", uvm_component parent = null);
        super.new(name, parent);
        ctrl_imp = new("ctrl_imp", this);
        stream_imp = new("stream_imp", this);
        expected_ap = new("expected_ap", this);
    endfunction : new

    function void write_ctrl(ita_ctrl_item tr);
        `uvm_info("ITA_REF", $sformatf("Observed ctrl start layer=%0d activation=%0d", tr.ctrl.layer, tr.ctrl.activation), UVM_LOW)
    endfunction : write_ctrl

    function void write_stream(ita_stream_item tr);
        if (tr.kind inside {
                ITA_STREAM_HEAD_INPUT,
                ITA_STREAM_HEAD_WEIGHT,
                ITA_STREAM_HEAD_BIAS,
                ITA_STREAM_FF_INPUT,
                ITA_STREAM_FF_WEIGHT,
                ITA_STREAM_FF_BIAS
            }) begin
            `uvm_info("ITA_REF", $sformatf("Observed source stream kind=%0d head=%0d", tr.kind, tr.head_id), UVM_HIGH)
        end
    endfunction : write_stream

endclass : ita_mha8_ref_model

`endif // ITA_MHA8_REF_MODEL_SVH
