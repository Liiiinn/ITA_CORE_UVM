`ifndef ITA_MHA8_TRANSACTION_LOGGER_SVH
`define ITA_MHA8_TRANSACTION_LOGGER_SVH

class ita_mha8_transaction_logger extends uvm_component;
    `uvm_component_utils(ita_mha8_transaction_logger)

    uvm_analysis_imp_source #(ita_stream_item, ita_mha8_transaction_logger) source_imp;
    uvm_analysis_imp_stream #(ita_stream_item, ita_mha8_transaction_logger) stream_imp;
    // TODO Stage 7: define which analysis imp receives driver-issued source items.
    // TODO Stage 7: define which analysis imp receives monitor-sampled accepted/output items.

    int unsigned source_count;
    int unsigned stream_count;
    int unsigned output_count;
    // TODO Stage 7: implement counters after deciding the first logger report format.

    string actual_path;
    // TODO Stage 10: pass actual_path from ita_mha8_core_item or test config before adding file output.

    function new(string name = "ita_mha8_transaction_logger", uvm_component parent = null);
        super.new(name, parent);
        source_imp = new("source_imp", this);
        stream_imp = new("stream_imp", this);
        // TODO Stage 7: keep imps allocated; connect them from env only after agent ap forwarding is implemented.
    endfunction : new

    function void write_source(ita_stream_item tr);
        // TODO Stage 7: implement optional input/weight/bias source logging for head0 debug.
        // TODO Stage 7: update source_count only after the source log contract is defined.
        // TODO Stage 11: add per-head attribution once heads 1-7 are enabled.
    endfunction : write_source

    function void write_stream(ita_stream_item tr);
        // TODO Stage 7: detect ITA_STREAM_HEAD_OUTPUT for head0 and dump tr.oup as actual output.
        // TODO Stage 7: update stream_count/output_count only after output sampling is implemented.
        // TODO Stage 8: leave protocol/count checking to the smoke scoreboard, not the logger.
        // TODO Stage 10: write actual output to actual_path in the format expected by the Python compare flow.
    endfunction : write_stream

    function bit is_output_stream(ita_stream_kind_e kind);
        // TODO Stage 7: return true for ITA_STREAM_HEAD_OUTPUT first; add sum/ff outputs in Stage 11.
        return 1'b0;
    endfunction : is_output_stream

    function string stream_kind_name(ita_stream_kind_e kind);
        // TODO Stage 7: convert stream kind to a stable debug string for log messages or output files.
        return "unimplemented";
    endfunction : stream_kind_name

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        // TODO Stage 7: print logger counters after actual-output logging is implemented.
    endfunction : report_phase

endclass : ita_mha8_transaction_logger

`endif // ITA_MHA8_TRANSACTION_LOGGER_SVH
