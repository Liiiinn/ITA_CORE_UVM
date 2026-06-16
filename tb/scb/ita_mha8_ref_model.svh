`ifndef ITA_MHA8_REF_MODEL_SVH
`define ITA_MHA8_REF_MODEL_SVH

class ita_mha8_ref_model extends uvm_component;
    `uvm_component_utils(ita_mha8_ref_model)

    uvm_analysis_imp_ctrl #(ita_ctrl_item, ita_mha8_ref_model) ctrl_imp;
    uvm_analysis_imp_stream #(ita_stream_item, ita_mha8_ref_model) stream_imp;
    uvm_analysis_port #(ita_stream_item) expected_ap;
    bit [2:0] source_mask_by_key[string];
    int unsigned complete_source_beats;

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
            observe_source(tr);
        end
    endfunction : write_stream

    function void observe_source(ita_stream_item tr);
        string key;

        key = beat_key(tr);
        if (!source_mask_by_key.exists(key)) begin
            source_mask_by_key[key] = 3'b000;
        end
        source_mask_by_key[key] |= source_mask(tr.kind);
        `uvm_info("ITA_REF", $sformatf(
            "Observed source stream kind=%0d head=%0d step=%0d beat=%0d mask=%03b",
            tr.kind, tr.head_id, tr.step, tr.beat_id, source_mask_by_key[key]
        ), UVM_HIGH)

        if (source_mask_by_key[key] == 3'b111) begin
            emit_placeholder_expected(tr);
            complete_source_beats++;
        end
    endfunction : observe_source

    function void emit_placeholder_expected(ita_stream_item tr);
        ita_stream_item expected;

        expected = ita_stream_item::type_id::create("expected");
        expected.kind = (tr.kind inside {ITA_STREAM_FF_INPUT, ITA_STREAM_FF_WEIGHT, ITA_STREAM_FF_BIAS}) ?
            ITA_STREAM_FF_OUTPUT : ITA_STREAM_HEAD_OUTPUT;
        expected.head_id = tr.head_id;
        expected.step = tr.step;
        expected.tile_id = tr.tile_id;
        expected.inner_tile_id = tr.inner_tile_id;
        expected.beat_id = tr.beat_id;
        expected.is_lockstep = tr.is_lockstep;
        expected.oup = '0;
        expected_ap.write(expected);
        `uvm_info("ITA_REF", $sformatf("Emitted placeholder expected key=%s", beat_key(tr)), UVM_MEDIUM)
    endfunction : emit_placeholder_expected

    function bit [2:0] source_mask(ita_stream_kind_e kind);
        case (kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_FF_INPUT:  return 3'b001;
            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_FF_WEIGHT: return 3'b010;
            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_BIAS:   return 3'b100;
            default:              return 3'b000;
        endcase
    endfunction : source_mask

    function string beat_key(ita_stream_item tr);
        return $sformatf("head=%0d step=%0d tile=%0d inner=%0d beat=%0d",
            tr.head_id, tr.step, tr.tile_id, tr.inner_tile_id, tr.beat_id);
    endfunction : beat_key

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ITA_REF", $sformatf(
            "Observed %0d complete input/weight/bias source beats",
            complete_source_beats
        ), UVM_LOW)
    endfunction : report_phase

endclass : ita_mha8_ref_model

`endif // ITA_MHA8_REF_MODEL_SVH
