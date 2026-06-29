`ifndef ITA_MHA8_CORE_ITEM_SVH
`define ITA_MHA8_CORE_ITEM_SVH

class ita_mha8_core_item extends uvm_sequence_item;
    `uvm_object_utils(ita_mha8_core_item)

    layer_e      layer;
    activation_e activation;
    step_e       stream_step;
    tile_t       tile_s;
    tile_t       tile_e;
    tile_t       tile_p;
    tile_t       tile_f;
    int unsigned target_head_id;
    int unsigned num_active_heads;

    inp_t        input_payload[$];
    inp_weight_t weight_payload[$];
    bias_t       bias_payload[$];

    inp_t        input_payload_by_head       [8][$];
    inp_weight_t weight_payload_by_head      [8][$];
    bias_t       bias_payload_by_head        [8][$];
    // Stage 10: per-head queues are the UVM stimulus contract for Linear 8-head smoke.

    requant_const_array_t head_eps_mult       [8];
    requant_const_array_t head_right_shift    [8];
    requant_array_t       head_add            [8];
    bit                   has_requant_config;
    string                requant_vector_path;
    // Stage 10: optional PyITA requant CSV lets Q/K/V compare use the same constants as the source vectors.

    string       expected_path;
    string       actual_path;
    string       compare_path;
    string       stream_vector_path;
    // Stage 10: post-simulation compare paths are owned by the manifest/Python flow.
    // Future optional: populate these fields from a manifest plusarg if SV-side path awareness is needed.

    function new(string name = "ita_mha8_core_item");
        super.new(name);
        layer = Attention;
        activation = Identity;
        stream_step = MatMul;
        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        target_head_id = 0;
        num_active_heads = 1;
        expected_path = "";
        actual_path = "";
        compare_path = "";
        stream_vector_path = "";
        requant_vector_path = "";
        clear_payloads();
        clear_requant_config();
        // TODO Stage 9: seed a small manually checkable Linear transaction in the derived test.
    endfunction : new

    function void clear_payloads();
        input_payload.delete();
        weight_payload.delete();
        bias_payload.delete();
        for (int unsigned h = 0; h < 8; h++) begin
            input_payload_by_head[h].delete();
            weight_payload_by_head[h].delete();
            bias_payload_by_head[h].delete();
        end
    endfunction : clear_payloads

    function void clear_requant_config();
        has_requant_config = 1'b0;
        for (int unsigned h = 0; h < 8; h++) begin
            head_eps_mult[h]    = '0;
            head_right_shift[h] = '0;
            head_add[h]         = '0;
        end
    endfunction : clear_requant_config

    function int signed requant_index_from_step_name(string step_name);
        case (step_name)
            "Q": return 0;
            "K": return 1;
            "V": return 2;
            "QK": return 3;
            "AV": return 4;
            "OW": return 5;
            "F1": return 6;
            "F2": return 7;
            "MatMul": return 0;
            default: return -1;
        endcase
    endfunction : requant_index_from_step_name

    function void load_requant_csv(string requant_vector_path);
        int fd;
        int line_no;
        int code;
        int signed step_idx;
        int signed add_value;
        int unsigned head_id;
        int unsigned mult_value;
        int unsigned shift_value;
        int unsigned char_idx;
        int unsigned loaded_rows;
        string header;
        string line;
        string scan_line;
        string step_name;

        this.requant_vector_path = requant_vector_path;
        clear_requant_config();

        fd = $fopen(requant_vector_path, "r");
        if (fd == 0) begin
            `uvm_fatal("CORE_RQCSV", $sformatf("Failed to open requant CSV: %s", requant_vector_path))
        end

        void'($fgets(header, fd));
        line_no = 1;
        loaded_rows = 0;

        while ($fgets(line, fd)) begin
            line_no++;
            step_name = "";
            scan_line = line;
            for (char_idx = 0; char_idx < scan_line.len(); char_idx++) begin
                if (scan_line.getc(char_idx) == 8'h2c) begin
                    scan_line.putc(char_idx, 8'h20);
                end
            end

            code = $sscanf(scan_line, "%s %d %d %d %d",
                step_name, head_id, mult_value, shift_value, add_value);
            if (code != 5) begin
                if (line.len() != 0) begin
                    `uvm_warning("CORE_RQCSV", $sformatf("Skipping malformed requant line %0d: %s", line_no, line))
                end
                continue;
            end

            if (head_id >= 8) begin
                `uvm_warning("CORE_RQCSV", $sformatf("Skipping illegal head row at line %0d: head_id=%0d", line_no, head_id))
                continue;
            end

            step_idx = requant_index_from_step_name(step_name);
            if (step_idx < 0 || step_idx >= N_REQUANT_CONSTS) begin
                `uvm_warning("CORE_RQCSV", $sformatf("Skipping unsupported requant step at line %0d: %s", line_no, step_name))
                continue;
            end

            head_eps_mult[head_id][step_idx]    = requant_const_t'(mult_value);
            head_right_shift[head_id][step_idx] = requant_const_t'(shift_value);
            head_add[head_id][step_idx]         = requant_t'(add_value);
            loaded_rows++;
        end

        $fclose(fd);
        has_requant_config = (loaded_rows != 0);

        if (!has_requant_config) begin
            `uvm_error("CORE_RQCSV", $sformatf("No requant rows loaded from %s", requant_vector_path))
        end else begin
            `uvm_info("CORE_RQCSV",
                $sformatf("Loaded %0d requant rows from %s", loaded_rows, requant_vector_path),
                UVM_LOW)
        end
    endfunction : load_requant_csv

    function void sync_head0_compat_queues();
        input_payload = input_payload_by_head[0];
        weight_payload = weight_payload_by_head[0];
        bias_payload = bias_payload_by_head[0];
    endfunction : sync_head0_compat_queues

    function automatic bit [511:0] parse_hex_payload_bits(string payload_text);
        bit [511:0] value;
        int unsigned nibble_idx;
        int unsigned char_idx;
        byte c;
        bit [3:0] nibble;

        value = '0;
        nibble_idx = 0;

        for (int signed i = payload_text.len() - 1; i >= 0; i--) begin
            c = payload_text.getc(i);

            if (c == 8'h5f) begin
                continue;
            end

            if (c >= "0" && c <= "9") begin
                nibble = c - "0";
            end else if (c >= "a" && c <= "f") begin
                nibble = c - "a" + 10;
            end else if (c >= "A" && c <= "F") begin
                nibble = c - "A" + 10;
            end else begin
                continue;
            end

            char_idx = nibble_idx * 4;
            if (char_idx < 512) begin
                value[char_idx +: 4] = nibble;
            end else begin
                `uvm_warning("CORE_CSV", $sformatf("Payload is wider than 512 bits and will be truncated: %s", payload_text))
                break;
            end
            nibble_idx++;
        end

        return value;
    endfunction : parse_hex_payload_bits

    function int unsigned active_heads();
        if (num_active_heads == 0)
            return 1;
        if (num_active_heads > 8)
            return 8;
        return num_active_heads;
    endfunction : active_heads

    function void set_linear_directed_head0;
        layer = Linear;
        activation = Identity;
        stream_step = MatMul;

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;

        target_head_id = 0;
        num_active_heads = 1;
        clear_payloads();

        input_payload_by_head[0].push_back(2);
        for (int unsigned i = 0; i < N_WRITE_EN; i++) begin
            weight_payload_by_head[0].push_back(2);
        end
        bias_payload_by_head[0].push_back(4);
        sync_head0_compat_queues();
    endfunction : set_linear_directed_head0

    function void set_linear_head0_multibeat();
        layer = Linear;
        activation = Identity;
        stream_step = MatMul;

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        target_head_id = 0;
        num_active_heads = 1;
        clear_payloads();

        for (int unsigned i = 0; i < N_WRITE_EN; i++) begin
            weight_payload_by_head[0].push_back('0);
        end

        input_payload_by_head[0].push_back('0);
        bias_payload_by_head[0].push_back('0);
        sync_head0_compat_queues();

        expected_path = "logger/ita_mha8_expected.csv";
        actual_path   = "logger/ita_mha8_output.csv";
        compare_path  = "logger/ita_mha8_compare.txt";
    endfunction : set_linear_head0_multibeat

    function void load_linear_head0_stream_csv(string stream_vector_path);
        load_stream_csv(stream_vector_path, Linear, MatMul);
    endfunction : load_linear_head0_stream_csv

    function void load_linear_stream_csv(string stream_vector_path);
        load_stream_csv(stream_vector_path, Linear, MatMul);
    endfunction : load_linear_stream_csv

    function void load_stream_csv(
        string stream_vector_path,
        layer_e layer_value,
        step_e stream_step_value,
        activation_e activation_value = Identity,
        tile_t tile_s_value = 1,
        tile_t tile_e_value = 1,
        tile_t tile_p_value = 1,
        tile_t tile_f_value = 1
    );
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
        int unsigned max_head_seen;
        bit [511:0] payload_bits;
        bit warned_step_mismatch;

        layer = layer_value;
        activation = activation_value;
        stream_step = stream_step_value;
        tile_s = tile_s_value;
        tile_e = tile_e_value;
        tile_p = tile_p_value;
        tile_f = tile_f_value;
        target_head_id = 0;
        num_active_heads = 0;
        max_head_seen = 0;
        warned_step_mismatch = 1'b0;
        this.stream_vector_path = stream_vector_path;
        clear_payloads();

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

            if (head_id >= 8) begin
                `uvm_warning("CORE_CSV", $sformatf("Skipping illegal head row at line %0d: head_id=%0d", line_no, head_id))
                continue;
            end

            if (head_id > max_head_seen)
                max_head_seen = head_id;

            if (!warned_step_mismatch && step_name != "" && step_name != stream_step.name()) begin
                `uvm_warning("CORE_CSV",
                    $sformatf("CSV step metadata '%s' differs from requested stream_step '%s'; using requested stream_step",
                        step_name, stream_step.name()))
                warned_step_mismatch = 1'b1;
            end

            if (payload_text.len() >= 2 &&
                (payload_text.substr(0, 1) == "0x" || payload_text.substr(0, 1) == "0X")) begin
                payload_hex = payload_text.substr(2, payload_text.len() - 1);
            end else begin
                payload_hex = payload_text;
            end
            payload_bits = parse_hex_payload_bits(payload_hex);

            case (kind)
                "head_input": begin
                    input_payload_by_head[head_id].push_back(inp_t'(payload_bits));
                end
                "head_weight": begin
                    weight_payload_by_head[head_id].push_back(inp_weight_t'(payload_bits));
                end
                "head_bias": begin
                    bias_payload_by_head[head_id].push_back(bias_t'(payload_bits));
                end
                default: begin
                    `uvm_warning("CORE_CSV", $sformatf("Skipping unsupported stream kind at line %0d: %s", line_no, kind))
                end
            endcase
        end

        $fclose(fd);
        num_active_heads = max_head_seen + 1;
        sync_head0_compat_queues();

        for (int unsigned h = 0; h < active_heads(); h++) begin
            if (input_payload_by_head[h].size() == 0)
                `uvm_error("CORE_CSV", $sformatf("CSV did not provide any input payload for head%0d", h))
            if (weight_payload_by_head[h].size() == 0)
                `uvm_error("CORE_CSV", $sformatf("CSV did not provide any weight payload for head%0d", h))
            if (bias_payload_by_head[h].size() == 0)
                `uvm_error("CORE_CSV", $sformatf("CSV did not provide any bias payload for head%0d", h))
        end

        `uvm_info("CORE_CSV",
            $sformatf("Loaded stream CSV %s: layer=%s stream_step=%s active_heads=%0d head0 input=%0d weight=%0d bias=%0d",
                stream_vector_path, layer.name(), stream_step.name(), active_heads(), input_payload_by_head[0].size(),
                weight_payload_by_head[0].size(), bias_payload_by_head[0].size()),
            UVM_LOW)
    endfunction : load_stream_csv
endclass : ita_mha8_core_item

`endif // ITA_MHA8_CORE_ITEM_SVH
