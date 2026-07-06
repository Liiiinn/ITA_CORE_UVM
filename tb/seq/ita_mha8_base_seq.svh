`ifndef ITA_MHA8_BASE_SEQ_SVH
`define ITA_MHA8_BASE_SEQ_SVH

class ita_ctrl_single_seq extends uvm_sequence #(ita_ctrl_item);
    `uvm_object_utils(ita_ctrl_single_seq)

    ita_ctrl_item ctrl;

    function new(string name = "ita_ctrl_single_seq");
        super.new();
    endfunction : new

    task body();
        // Stage 2: create an ita_ctrl_item, set minimal ctrl fields, and call start_item/finish_item.
        if (ctrl == null)
            `uvm_fatal(get_type_name(), "ctrl item must be set before starting ita_ctrl_single_seq")
        
        start_item(ctrl);
        finish_item(ctrl);
    endtask : body
endclass : ita_ctrl_single_seq

class ita_stream_single_seq extends uvm_sequence #(ita_stream_item);
    `uvm_object_utils(ita_stream_single_seq)

    ita_stream_item stream;

    function new(string name = "ita_stream_single_seq");
        super.new(name);
    endfunction : new

    task body();
        if (stream == null)
            `uvm_fatal(get_type_name(), "stream item must be set before starting ita_stream_single_seq")
        
        start_item(stream);
        finish_item(stream);
    endtask : body

endclass : ita_stream_single_seq

// class ita_stream_single_seq extends uvm_sequence #(ita_stream_item);
//     `uvm_object_utils(ita_stream_single_seq)

//     ita_stream_item stream;

//     function new(string name = "ita_stream_single_seq");
//         super.new(name);
//     endfunction : new

//     task body();
//         // Stage 3: create and send one head0 input stream item.
//         // Stage 4: extend this sequence for head0 weight and bias items.
//         send_item(kind, head_id, beat_id);
//         // Stage 5: use output stream monitoring instead of source sequence items for output.
//     endtask : body

//     task send_item(
//         ita_stream_kind_e kind,
//         int unsigned head_id,
//         int unsigned beat_id
//     );
//         ita_stream_item tr;
//         tr = ita_stream_item::type_id::create($sformatf("tr_%0d", beat_id));
//         start_item(tr);

//         tr.kind = kind;
//         tr.head_id = head_id;
//         tr.beat_id = beat_id;

//         case (kind)
//             ITA_STREAM_HEAD_INPUT:  tr.inp    = '0;
//             ITA_STREAM_HEAD_WEIGHT: tr.weight = '0;
//             ITA_STREAM_HEAD_BIAS:   tr.bias   = '0;
//             default:
//                 `uvm_warning(get_type_name(), $sformatf("Unhandled stream kind: %0d", kind))
//         endcase

//         finish_item(tr);
//     endtask : send_item

// endclass : ita_stream_single_seq

`endif // ITA_MHA8_BASE_SEQ_SVH
