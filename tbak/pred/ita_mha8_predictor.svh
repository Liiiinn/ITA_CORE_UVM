`ifndef ITA_MHA8_PREDICTOR_SVH
`define ITA_MHA8_PREDICTOR_SVH

class ita_mha8_predictor extends uvm_component;
    `uvm_component_utils(ita_mha8_predictor)
    `uvm_analysis_imp_decl(_ctrl)

    uvm_analysis_imp_ctrl #(ita_ctrl_item, ita_mha8_predictor) ctrl_export;

    bit          has_ctrl;
    layer_e      active_layer;
    activation_e active_activation;
    int unsigned tile_s;
    int unsigned tile_e;
    int unsigned tile_p;
    int unsigned tile_f;

    function new(string name = "ita_mha8_predictor", uvm_component parent = null);
        super.new(name, parent);
        ctrl_export = new("ctrl_export", this);
        has_ctrl = 1'b0;
        active_layer = Attention;
        active_activation = Identity;
        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
    endfunction : new

    function void write_ctrl(ita_ctrl_item ctrl);
        build_expected_from_ctrl(ctrl);
    endfunction : write_ctrl

    function void build_expected_from_ctrl(ita_ctrl_item ctrl);
        has_ctrl = 1'b1;
        active_layer = ctrl.ctrl.layer;
        active_activation = ctrl.ctrl.activation;
        tile_s = ctrl.ctrl.tile_s;
        tile_e = ctrl.ctrl.tile_e;
        tile_p = ctrl.ctrl.tile_p;
        tile_f = ctrl.ctrl.tile_f;

        `uvm_info("ITA_PRED_CTRL",
            $sformatf("Built structural expectations layer=%s activation=%s tile_s/e/p/f=%0d/%0d/%0d/%0d",
                active_layer.name(), active_activation.name(), tile_s, tile_e, tile_p, tile_f),
            UVM_LOW)
    endfunction : build_expected_from_ctrl

    function int unsigned expected_source_segments(step_e step);
        case (step)
            Q, K, V:
                return tile_s * tile_p * tile_e;
            QK:
                return tile_s * tile_s * tile_p;
            AV:
                return tile_s * tile_p * tile_s;
            OW:
                return tile_s * tile_e * tile_p;
            F1:
                return tile_s * tile_f * tile_e;
            F2:
                return tile_s * tile_e * tile_f;
            MatMul:
                return tile_s * tile_p * tile_e;
            default:
                return 0;
        endcase
    endfunction : expected_source_segments

    function int unsigned expected_output_segments(step_e step);
        case (step)
            Q, K, V:
                return tile_s * tile_p;
            QK:
                return tile_s * tile_s;
            AV:
                return tile_s * tile_p;
            OW:
                return tile_s * tile_e;
            F1:
                return tile_s * tile_f;
            F2:
                return tile_s * tile_e;
            MatMul:
                return tile_s * tile_p;
            default:
                return 0;
        endcase
    endfunction : expected_output_segments

    function int unsigned expected_output_segments_for_kind(step_e step, ita_stream_kind_e kind);
        case (kind)
            ITA_STREAM_HEAD_OUTPUT: begin
                case (step)
                    Q, K, V:
                        return tile_s * tile_p;
                    QK:
                        return tile_s * tile_s;
                    AV:
                        return tile_s * tile_p;
                    OW:
                        return tile_s * tile_e;
                    MatMul:
                        return tile_s * tile_p;
                    default:
                        return 0;
                endcase
            end

            ITA_STREAM_SUM_OUTPUT: begin
                if (step == OW)
                    return tile_s * tile_e;
                return 0;
            end

            ITA_STREAM_FF_OUTPUT: begin
                case (step)
                    F1:
                        return tile_s * tile_f;
                    F2:
                        return tile_s * tile_e;
                    default:
                        return 0;
                endcase
            end

            default:
                return 0;
        endcase
    endfunction : expected_output_segments_for_kind

    function int unsigned expected_beats_per_segment(step_e step, ita_stream_kind_e kind);
        case (kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_INPUT,
            ITA_STREAM_FF_WEIGHT,
            ITA_STREAM_FF_BIAS: begin
                if (expected_source_segments(step) != 0)
                    return M * M / N;
                return 0;
            end

            ITA_STREAM_HEAD_OUTPUT,
            ITA_STREAM_SUM_OUTPUT,
            ITA_STREAM_FF_OUTPUT: begin
                if (expected_output_segments_for_kind(step, kind) != 0)
                    return M * M / N;
                return 0;
            end

            default:
                return 0;
        endcase
    endfunction : expected_beats_per_segment

    function bit is_output_inner_legal(step_e step, int unsigned inner_id);
        case (step)
            Q, K, V:
                return inner_id == ((tile_e == 0) ? 0 : tile_e - 1);
            QK:
                return inner_id == ((tile_p == 0) ? 0 : tile_p - 1);
            AV:
                return inner_id == ((tile_s == 0) ? 0 : tile_s - 1);
            OW:
                return inner_id == ((tile_p == 0) ? 0 : tile_p - 1);
            F1:
                return inner_id == ((tile_e == 0) ? 0 : tile_e - 1);
            F2:
                return inner_id == ((tile_f == 0) ? 0 : tile_f - 1);
            MatMul:
                return 1'b1;
            default:
                return 1'b0;
        endcase
    endfunction : is_output_inner_legal

    function bit is_output_metadata_legal(
        step_e step,
        ita_stream_kind_e kind,
        int unsigned tile_id,
        int unsigned inner_id
    );
        if (!is_output_inner_legal(step, inner_id))
            return 1'b0;

        case (kind)
            ITA_STREAM_HEAD_OUTPUT: begin
                case (step)
                    Q, K, V:
                        return tile_id < tile_s * tile_p;
                    QK:
                        return tile_id < tile_s * tile_s;
                    AV:
                        return tile_id < tile_s * tile_p;
                    OW:
                        return tile_id < tile_s * tile_e;
                    MatMul:
                        return tile_id < tile_s * tile_p;
                    default:
                        return 1'b0;
                endcase
            end

            ITA_STREAM_SUM_OUTPUT:
                return step == OW && tile_id < tile_s * tile_e;

            ITA_STREAM_FF_OUTPUT: begin
                case (step)
                    F1:
                        return tile_id < tile_s * tile_f;
                    F2:
                        return tile_id < tile_s * tile_e;
                    default:
                        return 1'b0;
                endcase
            end

            default:
                return 1'b0;
        endcase
    endfunction : is_output_metadata_legal

    function bit is_ff_active_phase(step_e step, activation_e activation);
        case (step)
            F1:
                return activation inside {Identity, Gelu, Relu};
            F2:
                return activation == Identity;
            default:
                return 1'b0;
        endcase
    endfunction : is_ff_active_phase

endclass : ita_mha8_predictor

`endif // ITA_MHA8_PREDICTOR_SVH
