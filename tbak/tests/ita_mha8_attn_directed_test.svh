`ifndef ITA_MHA8_ATTN_DIRECTED_TEST_SVH
`define ITA_MHA8_ATTN_DIRECTED_TEST_SVH

class ita_mha8_attn_directed_test extends ita_mha8_base_test;
    `uvm_component_utils(ita_mha8_attn_directed_test)

    string stream_path;
    string requant_path;

    function new(string name = "ita_mha8_attn_directed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        ita_mha8_vsequence vseq;
        ita_mha8_core_item core;
        int unsigned tile_s;
        int unsigned tile_e;
        int unsigned tile_p;
        int unsigned tile_f;
        string activation_name;
        activation_e activation_value;

        phase.raise_objection(this);

        core = ita_mha8_core_item::type_id::create("core");
        
        if (!$value$plusargs("ITA_STREAM_CSV=%s", stream_path))
            stream_path = "logger/uvm_pyita_attn_mha8_stream.csv";

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        void'($value$plusargs("ITA_TILE_S=%d", tile_s));
        void'($value$plusargs("ITA_TILE_E=%d", tile_e));
        void'($value$plusargs("ITA_TILE_P=%d", tile_p));
        void'($value$plusargs("ITA_TILE_F=%d", tile_f));

        activation_value = Identity;
        if ($value$plusargs("ITA_ACTIVATION=%s", activation_name)) begin
            case (activation_name)
                "Identity", "identity": activation_value = Identity;
                "Relu",     "relu":     activation_value = Relu;
                "Gelu",     "gelu":     activation_value = Gelu;
                default:
                    `uvm_fatal("ATTN_TEST", $sformatf("Unsupported ITA_ACTIVATION=%s", activation_name))
            endcase
        end

        core.load_stream_csv(stream_path, Attention, Idle, activation_value, tile_s, tile_e, tile_p, tile_f);
        if ($value$plusargs("ITA_REQUANT_CSV=%s", requant_path))
            core.load_requant_csv(requant_path);

        vseq = ita_mha8_vsequence::type_id::create("vseq");
        vseq.core = core;
        vseq.start(env.vsqr);

        // Stage 10: ATTN CSV step metadata owns Q -> K -> V ordering.
        // Manifest/Python owns expected/actual/compare paths.
        repeat (2000) @(posedge vif.clk_i);

        phase.drop_objection(this);
    endtask : run_phase
endclass

`endif // ITA_MHA8_ATTN_DIRECTED_TEST_SVH
