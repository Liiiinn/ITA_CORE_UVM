`ifndef ITA_MHA8_BASE_SEQ_SVH
`define ITA_MHA8_BASE_SEQ_SVH

class ita_mha8_base_seq extends uvm_sequence #(ita_ctrl_item);
    `uvm_object_utils(ita_mha8_base_seq)

    function new(string name = "ita_mha8_base_seq");
        super.new(name);
    endfunction : new

    task body();
        // TODO Stage 2: create an ita_ctrl_item, set minimal ctrl fields, and call start_item/finish_item.
    endtask : body

endclass : ita_mha8_base_seq

class ita_mha8_stream_smoke_seq extends uvm_sequence #(ita_stream_item);
    `uvm_object_utils(ita_mha8_stream_smoke_seq)

    ita_stream_kind_e kind;
    int unsigned head_id;
    step_e step;
    int unsigned tile_id;
    int unsigned inner_tile_id;
    int unsigned beat_id;

    function new(string name = "ita_mha8_stream_smoke_seq");
        super.new(name);
    endfunction : new

    task body();
        // TODO Stage 3: create and send one head0 input stream item.
        // TODO Stage 4: extend this sequence for head0 weight and bias items.
        // TODO Stage 5: use output stream monitoring instead of source sequence items for output.
    endtask : body

endclass : ita_mha8_stream_smoke_seq

`endif // ITA_MHA8_BASE_SEQ_SVH
