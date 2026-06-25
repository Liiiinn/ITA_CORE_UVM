`ifndef ITA_STREAM_MONITOR_SVH
`define ITA_STREAM_MONITOR_SVH

class ita_stream_monitor extends uvm_monitor;
    `uvm_component_utils(ita_stream_monitor)

    ita_stream_config cfg;
    uvm_analysis_port #(ita_stream_item) ap;
    int unsigned sample_count;

    function new(string name = "ita_stream_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
        sample_count = 0;
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ita_stream_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("STR_MON_CFG", "ita_stream_config was not set")
        end
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge cfg.vif.clk_i);
            if (!cfg.vif.rst_ni)
                sample_count = 0;
            else if (is_handshake())
                sample_item();
        end
    endtask : run_phase

    function bit is_handshake();
        // Stage 3: return input valid/ready for head0 input stream.
        // Stage 4: add weight and bias valid/ready checks.
        // Stage 5: add head0 output valid/ready check.
        // TODO Stage 11: add heads 1-7, sum, and feed-forward handshake checks.
        case(cfg.kind)
            ITA_STREAM_HEAD_INPUT:
                return cfg.vif.inp_valid_i[cfg.head_id] && cfg.vif.inp_ready_o[cfg.head_id];
            ITA_STREAM_HEAD_WEIGHT:
                return cfg.vif.inp_weight_valid_i[cfg.head_id] && cfg.vif.inp_weight_ready_o[cfg.head_id];
            ITA_STREAM_HEAD_BIAS:
                return cfg.vif.inp_bias_valid_i[cfg.head_id] && cfg.vif.inp_bias_ready_o[cfg.head_id];
            ITA_STREAM_HEAD_OUTPUT:
                return cfg.vif.per_head_valid_o[cfg.head_id] && cfg.vif.per_head_ready_i[cfg.head_id];
        endcase
        return 1'b0;
    endfunction : is_handshake

    function void sample_item();
        ita_stream_item tr;

        tr = ita_stream_item::type_id::create("tr");
        tr.kind = cfg.kind;
        tr.head_id = cfg.head_id;
        tr.beat_id = sample_count;
        // Stage 3-5: sample the payload selected by cfg.kind and cfg.head_id.
        case(cfg.kind)
            ITA_STREAM_HEAD_INPUT: begin
                tr.inp = cfg.vif.inp_i[cfg.head_id];
                tr.tile_id = cfg.vif.inp_tile_id_dbg[cfg.head_id];
                tr.inner_tile_id = cfg.vif.inp_inner_id_dbg[cfg.head_id];
                tr.is_lockstep = cfg.vif.inp_lockstep_dbg[cfg.head_id];
                tr.step = cfg.vif.inp_step_dbg[cfg.head_id];
            end
            ITA_STREAM_HEAD_WEIGHT: begin
                tr.weight = cfg.vif.inp_weight_i[cfg.head_id];
                tr.tile_id = cfg.vif.inp_tile_id_dbg[cfg.head_id];
                tr.inner_tile_id = cfg.vif.inp_inner_id_dbg[cfg.head_id];
                tr.is_lockstep = cfg.vif.inp_lockstep_dbg[cfg.head_id];
                tr.step = cfg.vif.inp_step_dbg[cfg.head_id];
            end
            ITA_STREAM_HEAD_BIAS: begin 
                tr.bias = cfg.vif.inp_bias_i[cfg.head_id];
                tr.tile_id = cfg.vif.inp_tile_id_dbg[cfg.head_id];
                tr.inner_tile_id = cfg.vif.inp_inner_id_dbg[cfg.head_id];
                tr.is_lockstep = cfg.vif.inp_lockstep_dbg[cfg.head_id];
                tr.step = cfg.vif.inp_step_dbg[cfg.head_id];
            end
            ITA_STREAM_HEAD_OUTPUT: begin
                tr.oup = cfg.vif.per_head_oup_o[cfg.head_id];
                tr.step = cfg.vif.per_head_step_o[cfg.head_id];
            end

        endcase
        // Stage 7: write sampled output transactions to logger through ap.
        // TODO Stage 8: send sampled transactions to the smoke scoreboard.
        ap.write(tr);
        sample_count++;
    endfunction : sample_item

endclass : ita_stream_monitor

`endif // ITA_STREAM_MONITOR_SVH
