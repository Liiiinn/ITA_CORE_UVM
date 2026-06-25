`ifndef ITA_MHA8_LOGGER_SVH
`define ITA_MHA8_LOGGER_SVH

class ita_mha8_logger extends uvm_component;
    `uvm_component_utils(ita_mha8_logger)

    `uvm_analysis_imp_decl(_stream)
    `uvm_analysis_imp_decl(_output)

    uvm_analysis_imp_stream #(ita_stream_item, ita_mha8_logger) stream_imp;
    uvm_analysis_imp_output #(ita_stream_item, ita_mha8_logger) output_imp;
    // Stage 7: define which analysis imp receives monitor-issued source items.
    // Stage 7: define which analysis imp receives monitor-sampled accepted/output items.

    int unsigned stream_count;
    int unsigned output_count;
    // Stage 7: implement counters after deciding the first logger report format.
    int stream_fd;
    int output_fd;

    string stream_path;
    string output_path;
    // TODO Stage 10: pass actual_path from ita_mha8_core_item or test config before adding file output.

    function new(string name = "ita_mha8_logger", uvm_component parent = null);
        super.new(name, parent);
        stream_imp = new("stream_imp", this);
        output_imp = new("output_imp", this);
        // Stage 7: keep imps allocated; connect them from env only after agent ap forwarding is implemented.

        stream_count = 0;
        output_count = 0;
        stream_fd = 0;
        output_fd = 0;
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (stream_path == "")
            stream_path = "logger/ita_mha8_stream.csv";
        
        stream_fd = $fopen(stream_path, "w");
        if (stream_fd == 0)
            `uvm_error("LOGGER", $sformatf("failed to open stream csv: %s", stream_path))
        else
            $fwrite(stream_fd, "time,kind,head_id,tile_id,inner_tile_id,beat_id,step,is_lockstep,payload\n");

        if (output_path == "")
            output_path = "logger/ita_mha8_output.csv";

        output_fd = $fopen(output_path, "w");
        if (output_fd == 0)
            `uvm_error("LOGGER", $sformatf("failed to open output csv: %s", output_path))
        else
            $fwrite(output_fd, "time,kind,head_id,tile_id,inner_tile_id,beat_id,step,is_lockstep,payload\n");
    endfunction : build_phase

    function void write_stream(ita_stream_item tr);
        // Stage 7: implement optional input/weight/bias source logging for head0 debug.
        // Stage 7: update source_count only after the source log contract is defined.
        stream_count ++;

        if (stream_fd == 0) begin
            `uvm_warning("LOGGER", "stream csv file is not open")
            return;
        end

        case (tr.kind)
            ITA_STREAM_HEAD_INPUT:
                $fwrite(stream_fd, "%0t,%s,%0d,%0d,%0d,%0d,%s,%0d,%0h\n",
                    $time, stream_kind_name(tr.kind), tr.head_id, tr.tile_id,
                    tr.inner_tile_id, tr.beat_id, tr.step.name(), tr.is_lockstep, tr.inp);
            ITA_STREAM_HEAD_WEIGHT:
                $fwrite(stream_fd, "%0t,%s,%0d,%0d,%0d,%0d,%s,%0d,%0h\n",
                    $time, stream_kind_name(tr.kind), tr.head_id, tr.tile_id,
                    tr.inner_tile_id, tr.beat_id, tr.step.name(), tr.is_lockstep, tr.weight);
            ITA_STREAM_HEAD_BIAS:
                $fwrite(stream_fd, "%0t,%s,%0d,%0d,%0d,%0d,%s,%0d,%0h\n",
                    $time, stream_kind_name(tr.kind), tr.head_id, tr.tile_id,
                    tr.inner_tile_id, tr.beat_id, tr.step.name(), tr.is_lockstep, tr.bias);
            default:
                $fwrite(stream_fd, "%0t,%s,%0d,%0d,%0d,%0d,%s,%0d,\n",
                    $time, stream_kind_name(tr.kind), tr.head_id, tr.tile_id,
                    tr.inner_tile_id, tr.beat_id, tr.step.name(), tr.is_lockstep);
        endcase
        // TODO Stage 11: add per-head attribution once heads 1-7 are enabled.
    endfunction : write_stream

    function void write_output(ita_stream_item tr);
        // Stage 7: detect ITA_STREAM_HEAD_OUTPUT for head0 and dump tr.oup as actual output.
        // Stage 7: update stream_count/output_count only after output sampling is implemented.
        if (output_fd == 0) begin
            `uvm_warning("LOGGER", "output csv file is not open");
            return;
        end

        case(tr.kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_HEAD_BIAS: begin
                `uvm_warning("LOGGER", $sformatf("unexpected output kind: %s", stream_kind_name(tr.kind)))
                return;
            end
            ITA_STREAM_HEAD_OUTPUT: begin
                output_count ++;
                $fwrite(output_fd, "%0t,%s,%0d,%0d,%0d,%0d,%s,%0d,%0h\n",
                    $time, stream_kind_name(tr.kind), tr.head_id, tr.tile_id,
                    tr.inner_tile_id, tr.beat_id, tr.step.name(), tr.is_lockstep, tr.oup);
            end
            default: begin
                `uvm_warning("LOGGER", $sformatf("unsupported output kind: %s", stream_kind_name(tr.kind)))
                return;
            end
        endcase
        // TODO Stage 8: leave protocol/count checking to the smoke scoreboard, not the logger.
        // TODO Stage 10: write actual output to actual_path in the format expected by the Python compare flow.
    endfunction : write_output

    function string stream_kind_name(ita_stream_kind_e kind);
        // Stage 7: convert stream kind to a stable debug string for log messages or output files.
        case(kind)
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
        // Stage 7: print logger counters after actual-output logging is implemented.
        `uvm_info(
            "LOGGER",
            $sformatf("%0d stream items observed, %0d output items received", stream_count, output_count),
            UVM_LOW
        )
    endfunction : report_phase

    function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        
        if (stream_fd != 0) begin
            $fclose(stream_fd);
            stream_fd = 0;
        end

        if (output_fd != 0) begin
            $fclose(output_fd);
            output_fd = 0;
        end
    endfunction : final_phase

endclass : ita_mha8_logger

`endif // ITA_MHA8_LOGGER_SVH
