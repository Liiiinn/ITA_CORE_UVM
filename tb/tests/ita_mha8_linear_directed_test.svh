`ifndef ITA_MHA8_LINEAR_DIRECTED_TEST_SVH
`define ITA_MHA8_LINEAR_DIRECTED_TEST_SVH

class ita_mha8_linear_directed_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_linear_directed_test)

    string stream_path;

    function new(string name = "ita_mha8_linear_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        ita_mha8_vsequence vseq;
        ita_mha8_core_item core;

        phase.raise_objection(this);

        core = ita_mha8_core_item::type_id::create("core");
        
        if (!$value$plusargs("ITA_STREAM_CSV=%s", stream_path))
            stream_path = "logger/uvm_linear_head0_stream.csv";

        core.load_stream_csv(stream_path, Linear, MatMul);

        vseq = ita_mha8_vsequence::type_id::create("vseq");
        vseq.core = core;
        vseq.start(env.vsqr);

        // Stage 10: smoke.ps1 passes stream CSV; manifest/Python owns expected/actual/compare paths.
        repeat (200) @(posedge vif.clk_i);

        phase.drop_objection(this);
    endtask : run_phase
endclass

`endif // ITA_MHA8_LINEAR_DIRECTED_TEST_SVH