`ifndef ITA_MHA8_TRANSACTION_LOGGER_SVH
`define ITA_MHA8_TRANSACTION_LOGGER_SVH

class ita_mha8_transaction_logger extends uvm_component;
    `uvm_component_utils(ita_mha8_transaction_logger)

    uvm_analysis_imp_source #(ita_stream_item, ita_mha8_transaction_logger) source_imp;
    uvm_analysis_imp_stream #(ita_stream_item, ita_mha8_transaction_logger) stream_imp;

    bit [2:0] source_mask_by_key[string];
    int unsigned complete_lockstep_count;
    int unsigned source_count;
    int unsigned accepted_count;
    int unsigned output_count;

    function new(string name = "ita_mha8_transaction_logger", uvm_component parent = null);
        super.new(name, parent);
        source_imp = new("source_imp", this);
        stream_imp = new("stream_imp", this);
    endfunction : new

    function void write_source(ita_stream_item tr);
        string key;

        source_count++;
        if (is_head_source(tr.kind) || is_ff_source(tr.kind)) begin
            key = beat_key(tr);
            if (!source_mask_by_key.exists(key)) begin
                source_mask_by_key[key] = 3'b000;
            end
            source_mask_by_key[key] |= source_mask(tr.kind);
            if (source_mask_by_key[key] == 3'b111) begin
                complete_lockstep_count++;
                `uvm_info("ITA_TXN_LOG", $sformatf(
                    "Complete lockstep input/weight/bias beat key=%s",
                    key
                ), UVM_LOW)
            end
        end
    endfunction : write_source

    function void write_stream(ita_stream_item tr);
        accepted_count++;
        if (tr.kind inside {ITA_STREAM_HEAD_OUTPUT, ITA_STREAM_SUM_OUTPUT, ITA_STREAM_FF_OUTPUT}) begin
            output_count++;
            `uvm_info("ITA_TXN_LOG", $sformatf(
                "Observed output kind=%s head=%0d step=%0d beat=%0d",
                stream_kind_name(tr.kind), tr.head_id, tr.step, tr.beat_id
            ), UVM_MEDIUM)
        end
    endfunction : write_stream

    function bit is_head_source(ita_stream_kind_e kind);
        return kind inside {
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_HEAD_BIAS
        };
    endfunction : is_head_source

    function bit is_ff_source(ita_stream_kind_e kind);
        return kind inside {
            ITA_STREAM_FF_INPUT,
            ITA_STREAM_FF_WEIGHT,
            ITA_STREAM_FF_BIAS
        };
    endfunction : is_ff_source

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
        return $sformatf("head=%0d step=%0d tile=%0d inner=%0d beat=%0d lockstep=%0d",
            tr.head_id, tr.step, tr.tile_id, tr.inner_tile_id, tr.beat_id, tr.is_lockstep);
    endfunction : beat_key

    function string stream_kind_name(ita_stream_kind_e kind);
        case (kind)
            ITA_STREAM_HEAD_INPUT:  return "head_input";
            ITA_STREAM_HEAD_WEIGHT: return "head_weight";
            ITA_STREAM_HEAD_BIAS:   return "head_bias";
            ITA_STREAM_HEAD_OUTPUT: return "head_output";
            ITA_STREAM_SUM_OUTPUT:  return "sum_output";
            ITA_STREAM_FF_INPUT:    return "ff_input";
            ITA_STREAM_FF_WEIGHT:   return "ff_weight";
            ITA_STREAM_FF_BIAS:     return "ff_bias";
            ITA_STREAM_FF_OUTPUT:   return "ff_output";
            default:                return "unknown";
        endcase
    endfunction : stream_kind_name

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("ITA_TXN_LOG", $sformatf(
            "source_issued=%0d accepted=%0d outputs=%0d complete_lockstep_beats=%0d",
            source_count, accepted_count, output_count, complete_lockstep_count
        ), UVM_LOW)
    endfunction : report_phase

endclass : ita_mha8_transaction_logger

`endif // ITA_MHA8_TRANSACTION_LOGGER_SVH
