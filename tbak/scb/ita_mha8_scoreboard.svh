`ifndef ITA_MHA8_SCOREBOARD_SVH
`define ITA_MHA8_SCOREBOARD_SVH

class ita_mha8_scoreboard extends uvm_component;
    `uvm_component_utils(ita_mha8_scoreboard)

    uvm_analysis_export #(ita_stream_item) source_export;
    uvm_analysis_export #(ita_stream_item) output_export;

    uvm_tlm_analysis_fifo #(ita_stream_item) source_fifo;
    uvm_tlm_analysis_fifo #(ita_stream_item) output_fifo;

    // uvm_tlm_analysis_fifo #(ita_stream_item) expected_fifo;
    // uvm_tlm_analysis_fifo #(ita_stream_item) actual_fifo;
    // Stage 8: decide whether smoke scoreboard needs expected_fifo or only actual monitor input.

    int unsigned input_count;
    int unsigned weight_count;
    int unsigned bias_count;

    int unsigned actual_count;
    int unsigned expected_count;
    int unsigned compare_count;

    function new(string name = "ita_mha8_scoreboard", uvm_component parent = null);
        super.new(name, parent);

        source_export = new("source_export", this);
        output_export = new("output_export", this);

        source_fifo = new("source_fifo", this);
        output_fifo = new("output_fifo", this);
        // expected_fifo = new("expected_fifo", this);
        // actual_fifo = new("actual_fifo", this);
    endfunction : new

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        source_export.connect(source_fifo.analysis_export);
        output_export.connect(output_fifo.analysis_export);
    endfunction : connect_phase

    task run_phase(uvm_phase phase);
        // Stage 8: implement smoke checks for count, X/Z, timeout, and valid-ready protocol.
        fork
            process_source_fifo();
            process_output_fifo();
        join
        // ita_stream_item expected;
        // ita_stream_item actual;

        // forever begin
        //     actual_fifo.get(actual);
        //     actual_count++;
        //     sanity_check_actual(actual);

        //     if (expected_fifo.get(expected)) begin
        //         expected_count++;
        //         compare_metadata(expected, actual);
        //     end
        // end
        // Stage 10: numeric expected/actual compare is post-sim manifest flow, not this smoke scoreboard.
        // Future optional: reintroduce expected_fifo for online metadata/golden checks after S11 ref-model work.
    endtask : run_phase

    task process_source_fifo();
        ita_stream_item tr;

        forever begin
            source_fifo.get(tr);

            case(tr.kind)
                ITA_STREAM_HEAD_INPUT: input_count++;
                ITA_STREAM_FF_INPUT: input_count++;
                ITA_STREAM_HEAD_WEIGHT: weight_count++;
                ITA_STREAM_FF_WEIGHT: weight_count++;
                ITA_STREAM_HEAD_BIAS: bias_count++;
                ITA_STREAM_FF_BIAS: bias_count++;
                default:
                    `uvm_error("ITA_SCB_KIND",
                        $sformatf("Unexpected stream kind=%0d", tr.kind))
            endcase

            sanity_check_source(tr);
        end
    endtask : process_source_fifo

    task process_output_fifo();
        ita_stream_item tr;

        forever begin
            output_fifo.get(tr);
            actual_count++;
            sanity_check_actual(tr);
        end
    endtask : process_output_fifo

    function void sanity_check_source(ita_stream_item tr);
        if (!(tr.kind inside {
                ITA_STREAM_HEAD_INPUT,
                ITA_STREAM_HEAD_WEIGHT,
                ITA_STREAM_HEAD_BIAS,
                ITA_STREAM_FF_INPUT,
                ITA_STREAM_FF_WEIGHT,
                ITA_STREAM_FF_BIAS
            }))
            `uvm_error("ITA_SCB_KIND", $sformatf("Unexpected source kind=%0d", tr.kind))

        if (tr.kind inside {ITA_STREAM_HEAD_INPUT, ITA_STREAM_HEAD_WEIGHT, ITA_STREAM_HEAD_BIAS} && tr.head_id >= 8)
            `uvm_error("ITA_SCB_HEAD", $sformatf("Illegal source head_id=%0d", tr.head_id))

        case (tr.kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_FF_INPUT:
                if ($isunknown(tr.inp))
                    `uvm_error("ITA_SCB_XZ", "Input payload contains X/Z")

            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_FF_WEIGHT:
                if ($isunknown(tr.weight))
                    `uvm_error("ITA_SCB_XZ", "Weight payload contains X/Z")

            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_BIAS:
                if ($isunknown(tr.bias))
                    `uvm_error("ITA_SCB_XZ", "Bias payload contains X/Z")
        endcase
    endfunction : sanity_check_source

    function void sanity_check_actual(ita_stream_item actual);
        if (!(actual.kind inside {ITA_STREAM_HEAD_OUTPUT, ITA_STREAM_FF_OUTPUT, ITA_STREAM_SUM_OUTPUT}))
            `uvm_error("ITA_SCB_KIND", $sformatf("Unexpected actual stream kind=%0d", actual.kind)) 
        
        if (actual.kind == ITA_STREAM_HEAD_OUTPUT && actual.head_id >= 8)
            `uvm_error("ITA_SCB_HEAD", $sformatf("Illegal head_id=%0d", actual.head_id))
        
        if (!(actual.step inside {Q, K, V, QK, AV, OW, F1, F2, MatMul}))
            `uvm_error("ITA_SCB_STEP", $sformatf("Illegal output step=%0d", actual.step))
        
        if ($isunknown(actual.oup))
            `uvm_error("ITA_SCB_XZ", "Actual output contains X/Z")
    endfunction : sanity_check_actual

    // function void compare_metadata(ita_stream_item expected, ita_stream_item actual);
    //     compare_count++;

    //     if (expected.head_id != actual.head_id)
    //         `uvm_error("ITA_SCB_HEAD", $sformatf("Head mismatch: expected = %0d, actual = %0d", expected.head_id, actual.head_id))
        
    //     if (expected.step != actual.step)
    //         `uvm_error("ITA_SCB_STEP", $sformatf("Step mismatch: expected = %0d, actual = %0d", expected.head_id, actual.head_id))
        
    //     if (expected.beat_id != actual.beat_id)
    //         `uvm_info("ITA_SCB_BEAT", $sformatf("Beat mismatch: expected = %0d, actual = %0d", expected.head_id, actual.head_id))
    // endfunction : compare_metadata

endclass : ita_mha8_scoreboard

`endif // ITA_MHA8_SCOREBOARD_SVH
