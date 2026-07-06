`ifndef ITA_MHA8_Q_DIRECTED_TEST_SVH
`define ITA_MHA8_Q_DIRECTED_TEST_SVH

class ita_mha8_q_directed_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_q_directed_test)

    string stream_path;
    string requant_path;

    function new(string name = "ita_mha8_q_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function step_e parse_directed_step(string step_name);
        if (step_name == "Q" || step_name == "q")
            return Q;
        if (step_name == "K" || step_name == "k")
            return K;
        if (step_name == "V" || step_name == "v")
            return V;

        `uvm_fatal("ITA_STEP", $sformatf("Unsupported ITA_DIRECTED_STEP=%s; expected Q, K, or V", step_name))
        return Q;
    endfunction : parse_directed_step

    task run_phase(uvm_phase phase);
        ita_mha8_vsequence vseq;
        ita_mha8_core_item core;
        string directed_step_name;
        step_e directed_step;
        int unsigned tile_s;
        int unsigned tile_e;
        int unsigned tile_p;
        int unsigned tile_f;

        phase.raise_objection(this);

        core = ita_mha8_core_item::type_id::create("core");
        
        if (!$value$plusargs("ITA_STREAM_CSV=%s", stream_path))
            stream_path = "logger/uvm_pyita_q_mha8_stream.csv";
        if (!$value$plusargs("ITA_DIRECTED_STEP=%s", directed_step_name))
            directed_step_name = "Q";
        directed_step = parse_directed_step(directed_step_name);

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        void'($value$plusargs("ITA_TILE_S=%d", tile_s));
        void'($value$plusargs("ITA_TILE_E=%d", tile_e));
        void'($value$plusargs("ITA_TILE_P=%d", tile_p));
        void'($value$plusargs("ITA_TILE_F=%d", tile_f));

        core.load_stream_csv(stream_path, Attention, directed_step, Identity, tile_s, tile_e, tile_p, tile_f);
        if ($value$plusargs("ITA_REQUANT_CSV=%s", requant_path))
            core.load_requant_csv(requant_path);

        vseq = ita_mha8_vsequence::type_id::create("vseq");
        vseq.core = core;
        vseq.start(env.vsqr);

        // Stage 10: smoke.ps1 passes stream CSV; manifest/Python owns expected/actual/compare paths.
        repeat (200) @(posedge vif.clk_i);

        phase.drop_objection(this);
    endtask : run_phase
endclass

`endif // ITA_MHA8_Q_DIRECTED_TEST_SVH
