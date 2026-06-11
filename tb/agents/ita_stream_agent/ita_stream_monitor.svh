`ifndef ITA_STREAM_MONITOR_SVH
`define ITA_STREAM_MONITOR_SVH

class ita_stream_monitor extends uvm_monitor;
    `uvm_component_utils(ita_stream_monitor)

    ita_stream_config cfg;
    uvm_analysis_port #(ita_stream_item) ap;

    function new(string name = "ita_stream_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
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
            if (cfg.vif.rst_ni && is_handshake()) begin
                sample_item();
            end
        end
    endtask : run_phase

    function bit is_handshake();
        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT:
                return cfg.vif.inp_valid_i[cfg.head_id] && cfg.vif.inp_ready_o[cfg.head_id];
            ITA_STREAM_HEAD_WEIGHT:
                return cfg.vif.inp_weight_valid_i[cfg.head_id] && cfg.vif.inp_weight_ready_o[cfg.head_id];
            ITA_STREAM_HEAD_BIAS:
                return cfg.vif.inp_bias_valid_i[cfg.head_id] && cfg.vif.inp_bias_ready_o[cfg.head_id];
            ITA_STREAM_HEAD_OUTPUT:
                return cfg.vif.per_head_valid_o[cfg.head_id] && cfg.vif.per_head_ready_i[cfg.head_id];
            ITA_STREAM_SUM_OUTPUT:
                return cfg.vif.sum_valid_o && cfg.vif.sum_ready_i;
            ITA_STREAM_FF_INPUT:
                return cfg.vif.ff_inp_valid_i && cfg.vif.ff_inp_ready_o;
            ITA_STREAM_FF_WEIGHT:
                return cfg.vif.ff_inp_weight_valid_i && cfg.vif.ff_inp_weight_ready_o;
            ITA_STREAM_FF_BIAS:
                return cfg.vif.ff_inp_bias_valid_i && cfg.vif.ff_inp_bias_ready_o;
            ITA_STREAM_FF_OUTPUT:
                return cfg.vif.ff_valid_o && cfg.vif.ff_ready_i;
            default:
                return 1'b0;
        endcase
    endfunction : is_handshake

    function void sample_item();
        ita_stream_item tr;

        tr = ita_stream_item::type_id::create("tr");
        tr.kind = cfg.kind;
        tr.head_id = cfg.head_id;

        case (cfg.kind)
            ITA_STREAM_HEAD_INPUT:  tr.inp = cfg.vif.inp_i[cfg.head_id];
            ITA_STREAM_HEAD_WEIGHT: tr.weight = cfg.vif.inp_weight_i[cfg.head_id];
            ITA_STREAM_HEAD_BIAS:   tr.bias = cfg.vif.inp_bias_i[cfg.head_id];
            ITA_STREAM_HEAD_OUTPUT: begin
                tr.oup = cfg.vif.per_head_oup_o[cfg.head_id];
                tr.step = cfg.vif.per_head_step_o[cfg.head_id];
            end
            ITA_STREAM_SUM_OUTPUT: begin
                tr.oup = cfg.vif.sum_oup_o;
                tr.step = OW;
            end
            ITA_STREAM_FF_INPUT:  tr.inp = cfg.vif.ff_inp_i;
            ITA_STREAM_FF_WEIGHT: tr.weight = cfg.vif.ff_inp_weight_i;
            ITA_STREAM_FF_BIAS:   tr.bias = cfg.vif.ff_inp_bias_i;
            ITA_STREAM_FF_OUTPUT: begin
                tr.oup = cfg.vif.ff_oup_o;
                tr.step = cfg.vif.ff_step_o;
            end
            default: ;
        endcase

        ap.write(tr);
    endfunction : sample_item

endclass : ita_stream_monitor

`endif // ITA_STREAM_MONITOR_SVH
