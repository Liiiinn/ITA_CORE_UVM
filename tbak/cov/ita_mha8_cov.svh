`ifndef ITA_MHA8_COV_SVH
`define ITA_MHA8_COV_SVH

`uvm_analysis_imp_decl(_cov_stream)
`uvm_analysis_imp_decl(_cov_output)
`uvm_analysis_imp_decl(_cov_ctrl)

class ita_mha8_cov extends uvm_component;
    `uvm_component_utils(ita_mha8_cov)

    uvm_analysis_imp_cov_stream #(ita_stream_item, ita_mha8_cov) stream_imp;
    uvm_analysis_imp_cov_output #(ita_stream_item, ita_mha8_cov) output_imp;
    uvm_analysis_imp_cov_ctrl #(ita_ctrl_item, ita_mha8_cov) ctrl_imp;

    int unsigned tile_s;
    int unsigned tile_e;
    int unsigned tile_p;
    int unsigned tile_f;

    int unsigned stream_sample_count;
    int unsigned output_sample_count;
    int unsigned ctrl_sample_count;

    // Beat bucket is intentionally structural-light for v1 coverage.
    // TODO S13_STRUCT_PREDICTOR: replace nonfirst buckets with true first/middle/last using cfg-derived expected beats.
    localparam int unsigned BEAT_BUCKET_FIRST    = 0;
    localparam int unsigned BEAT_BUCKET_NONFIRST = 1;
    localparam int unsigned BEAT_BUCKET_HIGH     = 2;

    covergroup cfg_cg;
        option.per_instance = 1;

        cp_tile_s: coverpoint tile_s {
            bins s64  = {1};
            bins s128 = {2};
            bins s192 = {3};
            bins s256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cp_tile_e: coverpoint tile_e {
            bins e64  = {1};
            bins e128 = {2};
            bins e192 = {3};
            bins e256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cp_tile_p: coverpoint tile_p {
            bins p64  = {1};
            bins p128 = {2};
            bins p192 = {3};
            bins p256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cp_tile_f: coverpoint tile_f {
            bins f64  = {1};
            bins f128 = {2};
            bins f192 = {3};
            bins f256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cross_tile_cfg: cross cp_tile_s, cp_tile_e, cp_tile_p, cp_tile_f;
    endgroup : cfg_cg

    covergroup ctrl_item_cg with function sample(
        layer_e layer_value,
        activation_e activation_value,
        int unsigned tile_s_value,
        int unsigned tile_e_value,
        int unsigned tile_p_value,
        int unsigned tile_f_value,
        bit start_value
    );
        option.per_instance = 1;

        cp_layer: coverpoint layer_value {
            bins attention   = {Attention};
            bins linear      = {Linear};
            bins feedforward = {Feedforward};
        }

        cp_activation: coverpoint activation_value {
            bins identity = {Identity};
            bins relu     = {Relu};
            bins gelu     = {Gelu};
        }

        cp_tile_s: coverpoint tile_s_value {
            bins s64  = {1};
            bins s128 = {2};
            bins s192 = {3};
            bins s256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cp_tile_e: coverpoint tile_e_value {
            bins e64  = {1};
            bins e128 = {2};
            bins e192 = {3};
            bins e256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cp_tile_p: coverpoint tile_p_value {
            bins p64  = {1};
            bins p128 = {2};
            bins p192 = {3};
            bins p256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cp_tile_f: coverpoint tile_f_value {
            bins f64  = {1};
            bins f128 = {2};
            bins f192 = {3};
            bins f256 = {4};
            bins larger = {[5:$]};
            illegal_bins zero = {0};
        }

        cp_start: coverpoint start_value {
            bins asserted = {1};
            illegal_bins idle = {0};
        }

        cross_layer_activation: cross cp_layer, cp_activation;
        cross_layer_tile_cfg: cross cp_layer, cp_tile_s, cp_tile_e, cp_tile_p, cp_tile_f;
        cross_activation_tile_cfg: cross cp_activation, cp_tile_s, cp_tile_e, cp_tile_p, cp_tile_f;
    endgroup : ctrl_item_cg

    covergroup stream_item_cg with function sample(
        ita_stream_kind_e kind_value,
        step_e step_value,
        int unsigned head_id_value,
        int unsigned tile_id_value,
        int unsigned inner_tile_id_value,
        int unsigned beat_bucket_value,
        bit is_lockstep_value
    );
        option.per_instance = 1;

        cp_kind: coverpoint kind_value {
            bins head_input  = {ITA_STREAM_HEAD_INPUT};
            bins head_weight = {ITA_STREAM_HEAD_WEIGHT};
            bins head_bias   = {ITA_STREAM_HEAD_BIAS};
            bins ff_input    = {ITA_STREAM_FF_INPUT};
            bins ff_weight   = {ITA_STREAM_FF_WEIGHT};
            bins ff_bias     = {ITA_STREAM_FF_BIAS};
        }

        cp_step: coverpoint step_value {
            bins q      = {Q};
            bins k      = {K};
            bins v      = {V};
            bins qk     = {QK};
            bins av     = {AV};
            bins ow     = {OW};
            bins f1     = {F1};
            bins f2     = {F2};
            bins matmul = {MatMul};
            illegal_bins idle = {Idle};
        }

        cp_head: coverpoint head_id_value {
            bins heads[] = {[0:7]};
            illegal_bins illegal = {[8:$]};
        }

        cp_tile_id: coverpoint tile_id_value {
            bins first = {0};
            bins low[] = {[1:3]};
            bins high = {[4:$]};
        }

        cp_inner_tile_id: coverpoint inner_tile_id_value {
            bins first = {0};
            bins low[] = {[1:3]};
            bins high = {[4:$]};
        }

        cp_beat_bucket: coverpoint beat_bucket_value {
            bins first    = {BEAT_BUCKET_FIRST};
            bins nonfirst = {BEAT_BUCKET_NONFIRST};
            bins high     = {BEAT_BUCKET_HIGH};
        }

        cp_lockstep: coverpoint is_lockstep_value {
            bins unlocked = {0};
            bins locked   = {1};
        }

        cross_kind_step: cross cp_kind, cp_step;
        cross_step_head: cross cp_step, cp_head;
        cross_step_beat: cross cp_step, cp_beat_bucket;
    endgroup : stream_item_cg

    covergroup output_item_cg with function sample(
        ita_stream_kind_e kind_value,
        step_e step_value,
        int unsigned head_id_value,
        int unsigned tile_id_value,
        int unsigned inner_tile_id_value,
        int unsigned beat_bucket_value
    );
        option.per_instance = 1;

        cp_kind: coverpoint kind_value {
            bins head_output = {ITA_STREAM_HEAD_OUTPUT};
            bins sum_output  = {ITA_STREAM_SUM_OUTPUT};
            bins ff_output   = {ITA_STREAM_FF_OUTPUT};
        }

        cp_step: coverpoint step_value {
            bins q      = {Q};
            bins k      = {K};
            bins v      = {V};
            bins qk     = {QK};
            bins av     = {AV};
            bins ow     = {OW};
            bins f1     = {F1};
            bins f2     = {F2};
            bins matmul = {MatMul};
            illegal_bins idle = {Idle};
        }

        cp_head: coverpoint head_id_value {
            bins heads[] = {[0:7]};
            illegal_bins illegal = {[8:$]};
        }

        cp_tile_id: coverpoint tile_id_value {
            bins first = {0};
            bins low[] = {[1:3]};
            bins high = {[4:$]};
        }

        cp_inner_tile_id: coverpoint inner_tile_id_value {
            bins first = {0};
            bins low[] = {[1:3]};
            bins high = {[4:$]};
        }

        cp_beat_bucket: coverpoint beat_bucket_value {
            bins first    = {BEAT_BUCKET_FIRST};
            bins nonfirst = {BEAT_BUCKET_NONFIRST};
            bins high     = {BEAT_BUCKET_HIGH};
        }

        cross_kind_step: cross cp_kind, cp_step;
        cross_step_head: cross cp_step, cp_head;
        cross_step_beat: cross cp_step, cp_beat_bucket;
    endgroup : output_item_cg

    function new(string name = "ita_mha8_cov", uvm_component parent = null);
        super.new(name, parent);

        stream_imp = new("stream_imp", this);
        output_imp = new("output_imp", this);
        ctrl_imp = new("ctrl_imp", this);

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        stream_sample_count = 0;
        output_sample_count = 0;
        ctrl_sample_count = 0;

        cfg_cg = new();
        ctrl_item_cg = new();
        stream_item_cg = new();
        output_item_cg = new();
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_s", tile_s));
        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_e", tile_e));
        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_p", tile_p));
        void'(uvm_config_db#(int unsigned)::get(this, "", "tile_f", tile_f));
    endfunction : build_phase

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        cfg_cg.sample();
    endfunction : end_of_elaboration_phase

    function int unsigned beat_bucket(ita_stream_item tr);
        if (tr.beat_id == 0)
            return BEAT_BUCKET_FIRST;
        if (tr.beat_id >= 256)
            return BEAT_BUCKET_HIGH;
        return BEAT_BUCKET_NONFIRST;
    endfunction : beat_bucket

    function void write_cov_ctrl(ita_ctrl_item tr);
        ctrl_sample_count++;
        ctrl_item_cg.sample(
            tr.ctrl.layer,
            tr.ctrl.activation,
            tr.ctrl.tile_s,
            tr.ctrl.tile_e,
            tr.ctrl.tile_p,
            tr.ctrl.tile_f,
            tr.ctrl.start
        );
    endfunction : write_cov_ctrl

    function void write_cov_stream(ita_stream_item tr);
        stream_sample_count++;
        stream_item_cg.sample(
            tr.kind,
            tr.step,
            tr.head_id,
            tr.tile_id,
            tr.inner_tile_id,
            beat_bucket(tr),
            tr.is_lockstep
        );
    endfunction : write_cov_stream

    function void write_cov_output(ita_stream_item tr);
        output_sample_count++;
        output_item_cg.sample(
            tr.kind,
            tr.step,
            tr.head_id,
            tr.tile_id,
            tr.inner_tile_id,
            beat_bucket(tr)
        );
    endfunction : write_cov_output

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("ITA_MHA8_COV",
            $sformatf("coverage samples: ctrl=%0d stream=%0d output=%0d cfg=%0.2f%% ctrl=%0.2f%% stream=%0.2f%% output=%0.2f%%",
                ctrl_sample_count,
                stream_sample_count,
                output_sample_count,
                cfg_cg.get_inst_coverage(),
                ctrl_item_cg.get_inst_coverage(),
                stream_item_cg.get_inst_coverage(),
                output_item_cg.get_inst_coverage()),
            UVM_LOW)
    endfunction : report_phase

endclass : ita_mha8_cov

`endif // ITA_MHA8_COV_SVH
