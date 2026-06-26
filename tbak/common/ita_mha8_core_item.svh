`ifndef ITA_MHA8_CORE_ITEM_SVH
`define ITA_MHA8_CORE_ITEM_SVH

class ita_mha8_core_item extends uvm_sequence_item;
    `uvm_object_utils(ita_mha8_core_item)

    layer_e      layer;
    activation_e activation;
    tile_t       tile_s;
    tile_t       tile_e;
    tile_t       tile_p;
    tile_t       tile_f;
    // Stage 6: choose testcase intent fields before splitting into ctrl and stream items.
    int unsigned target_head_id;

    inp_t        input_payload[$];
    inp_weight_t weight_payload[$];
    bias_t       bias_payload[$];
    // Stage 6: define head0 payload ordering before adding random or full-head payloads.

    string       expected_path;
    string       actual_path;
    string       compare_path;
    string       stream_vector_path;
    // TODO Stage 10: pass these paths to logger and post-simulation Python compare flow.

    function new(string name = "ita_mha8_core_item");
        super.new(name);
        layer = Attention;
        activation = Identity;
        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        target_head_id = 0;
        expected_path = "";
        actual_path = "";
        compare_path = "";
        // TODO Stage 9: seed a small manually checkable Linear transaction in the derived test.
    endfunction : new

    function void set_linear_directed_head0;
        layer = Linear;
        activation = Identity;

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;

        target_head_id = 0;

        input_payload.delete();
        weight_payload.delete();
        bias_payload.delete();

        input_payload.push_back(2);
        for (int unsigned i = 0; i < N_WRITE_EN; i++) begin
            weight_payload.push_back(2);
        end
        bias_payload.push_back(4);
    endfunction : set_linear_directed_head0

    function void set_linear_head0_multibeat();
        layer = Linear;
        activation = Identity;

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        target_head_id = 0;

        input_payload.delete();
        weight_payload.delete();
        bias_payload.delete();

        // weight controller 需要先收满 N_WRITE_EN，默认就是 64。
        for (int unsigned i = 0; i < N_WRITE_EN; i++) begin
            weight_payload.push_back('0);
        end

        // 先做 1 个 compute beat。
        input_payload.push_back('0);
        bias_payload.push_back('0);

        expected_path = "logger/ita_mha8_expected.csv";
        actual_path   = "logger/ita_mha8_output.csv";
        compare_path  = "logger/ita_mha8_compare.txt";
    endfunction

    function void load_linear_head0_stream_csv(string stream_vector_path);
        int fd;
        int line_no;
        int code;
        string header;
        string line;
        string scan_line;
        string kind;
        string step_name;
        string payload_text;
        string payload_hex;
        int unsigned head_id;
        int unsigned tile_id;
        int unsigned inner_tile_id;
        int unsigned beat_id;
        int unsigned is_lockstep;
        int unsigned char_idx;
        longint unsigned payload;

        layer = Linear;
        activation = Identity;
        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        target_head_id = 0;
        this.stream_vector_path = stream_vector_path;

        input_payload.delete();
        weight_payload.delete();
        bias_payload.delete();

        fd = $fopen(stream_vector_path, "r");
        if (fd == 0) begin
            `uvm_fatal("CORE_CSV", $sformatf("Failed to open stream vector CSV: %s", stream_vector_path))
        end

        void'($fgets(header, fd));
        line_no = 1;

        while ($fgets(line, fd)) begin
            line_no++;
            kind = "";
            step_name = "";
            payload_text = "";
            payload_hex = "";

            scan_line = line;
            for (char_idx = 0; char_idx < scan_line.len(); char_idx++) begin
                if (scan_line.getc(char_idx) == 8'h2c) begin
                    scan_line.putc(char_idx, 8'h20);
                end
            end

            code = $sscanf(scan_line, "%s %d %d %d %d %s %d %s",
                kind, head_id, tile_id, inner_tile_id, beat_id,
                step_name, is_lockstep, payload_text);

            if (code != 8) begin
                if (line.len() != 0) begin
                    `uvm_warning("CORE_CSV", $sformatf("Skipping malformed CSV line %0d: %s", line_no, line))
                end
                continue;
            end

            if (head_id != 0) begin
                `uvm_warning("CORE_CSV", $sformatf("Skipping non-head0 row at line %0d: head_id=%0d", line_no, head_id))
                continue;
            end

            if (payload_text.len() >= 2 &&
                (payload_text.substr(0, 1) == "0x" || payload_text.substr(0, 1) == "0X")) begin
                payload_hex = payload_text.substr(2, payload_text.len() - 1);
            end else begin
                payload_hex = payload_text;
            end
            payload = payload_hex.atohex();

            case (kind)
                "head_input": begin
                    input_payload.push_back(inp_t'(payload));
                end
                "head_weight": begin
                    weight_payload.push_back(inp_weight_t'(payload));
                end
                "head_bias": begin
                    bias_payload.push_back(bias_t'(payload));
                end
                default: begin
                    `uvm_warning("CORE_CSV", $sformatf("Skipping unsupported stream kind at line %0d: %s", line_no, kind))
                end
            endcase
        end

        $fclose(fd);

        if (input_payload.size() == 0)
            `uvm_error("CORE_CSV", "CSV did not provide any head0 input payload")
        if (weight_payload.size() == 0)
            `uvm_error("CORE_CSV", "CSV did not provide any head0 weight payload")
        if (bias_payload.size() == 0)
            `uvm_error("CORE_CSV", "CSV did not provide any head0 bias payload")

        `uvm_info("CORE_CSV",
            $sformatf("Loaded Linear head0 CSV %s: input=%0d weight=%0d bias=%0d",
                stream_vector_path, input_payload.size(), weight_payload.size(), bias_payload.size()),
            UVM_LOW)
    endfunction : load_linear_head0_stream_csv
endclass : ita_mha8_core_item

`endif // ITA_MHA8_CORE_ITEM_SVH
