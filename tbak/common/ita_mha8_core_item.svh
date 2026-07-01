`ifndef ITA_MHA8_CORE_ITEM_SVH
`define ITA_MHA8_CORE_ITEM_SVH

class ita_mha8_core_item extends uvm_sequence_item;
    `uvm_object_utils(ita_mha8_core_item)

    localparam int unsigned NumHeads = 8;

    layer_e      layer;
    activation_e activation;
    tile_t       tile_s;
    tile_t       tile_e;
    tile_t       tile_p;
    tile_t       tile_f;

    ita_mha8_step_payload payload_by_step[step_e];
    step_e step_order[$];
    // Stage 10/11: payload_by_step is the stimulus contract for step-aware MHA8 flows.

    requant_const_array_t head_eps_mult       [NumHeads];
    requant_const_array_t head_right_shift    [NumHeads];
    requant_array_t       head_add            [NumHeads];
    bit                   has_requant_config;
    string                requant_vector_path;
    // Stage 10: optional PyITA requant CSV lets Q/K/V compare use the same constants as the source vectors.

    string stream_vector_path;
    // Stage 10: post-simulation compare paths are owned by the manifest/Python flow.

    function new(string name = "ita_mha8_core_item");
        super.new(name);
        layer = Attention;
        activation = Identity;
        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        stream_vector_path = "";
        requant_vector_path = "";
        clear_payloads();
        clear_requant_config();
    endfunction : new

    function bit is_payload_step(step_e step);
        return step inside {
            Q, K, V, QK, AV, OW, F1, F2, MatMul
        };
    endfunction : is_payload_step

    function ita_mha8_step_payload get_payload(step_e step);
        if (!is_payload_step(step))
            `uvm_fatal("CORE STEP", $sformatf("Unsupported payload step: %0d", step))

        if (!payload_by_step.exists(step)) begin
            payload_by_step[step] = ita_mha8_step_payload::type_id::create($sformatf("payload_%s", step.name()));
            payload_by_step[step].step = step;
        end

        return payload_by_step[step];
    endfunction : get_payload

    function step_e first_payload_step();
        if (step_order.size() == 0) begin
            `uvm_fatal("CORE STEP", "No payload steps have been loaded")
            return Idle;
        end

        return step_order[0];
    endfunction : first_payload_step

    function step_e parse_step_name(string step_name);
        case (step_name)
            "Q", "q":           return Q;
            "K", "k":           return K;
            "V", "v":           return V;
            "QK", "qk":         return QK;
            "AV", "av":         return AV;
            "OW", "ow":         return OW;
            "F1", "f1":         return F1;
            "F2", "f2":         return F2;
            "MatMul", "matmul": return MatMul;
            default: begin
                `uvm_fatal("CORE STEP", $sformatf("Unsupported CSV step metadata: %s", step_name))
                return Idle;
            end
        endcase
    endfunction : parse_step_name

    function void add_step_to_order(step_e step);
        foreach (step_order[i]) begin
            if (step_order[i] == step)
                return;
        end
        step_order.push_back(step);
    endfunction : add_step_to_order

    function void clear_payloads();
        step_order.delete();
        payload_by_step.delete();
    endfunction : clear_payloads

    function void clear_requant_config();
        has_requant_config = 1'b0;
        for (int unsigned h = 0; h < NumHeads; h++) begin
            head_eps_mult[h]    = '0;
            head_right_shift[h] = '0;
            head_add[h]         = '0;
        end
    endfunction : clear_requant_config

    function int signed requant_index_from_step_name(string step_name);
        case (step_name)
            "Q":      return 0;
            "K":      return 1;
            "V":      return 2;
            "QK":     return 3;
            "AV":     return 4;
            "OW":     return 5;
            "F1":     return 6;
            "F2":     return 7;
            "MatMul": return 0;
            default:  return -1;
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
                    `uvm_warning("CORE RQCSV", $sformatf("Skipping malformed requant line %0d: %s", line_no, line))
                end
                continue;
            end

            if (head_id >= NumHeads) begin
                `uvm_warning("CORE RQCSV", $sformatf("Skipping illegal head row at line %0d: head_id=%0d", line_no, head_id))
                continue;
            end

            step_idx = requant_index_from_step_name(step_name);
            if (step_idx < 0 || step_idx >= N_REQUANT_CONSTS) begin
                `uvm_warning("CORE RQCSV", $sformatf("Skipping unsupported requant step at line %0d: %s", line_no, step_name))
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
            `uvm_error("CORE RQCSV", $sformatf("No requant rows loaded from %s", requant_vector_path))
        end else begin
            `uvm_info("CORE RQCSV",
                $sformatf("Loaded %0d requant rows from %s", loaded_rows, requant_vector_path),
                UVM_LOW)
        end
    endfunction : load_requant_csv

    function bit [511:0] parse_hex_payload_bits(string payload_text);
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
                `uvm_warning("CORE CSV", $sformatf("Payload is wider than 512 bits and will be truncated: %s", payload_text))
                break;
            end
            nibble_idx++;
        end

        return value;
    endfunction : parse_hex_payload_bits

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
        bit [511:0] payload_bits;
        step_e row_step;
        step_e first_step;
        ita_mha8_step_payload payload;
        ita_mha8_step_payload log_payload;
        bit warned_step_mismatch;

        layer = layer_value;
        activation = activation_value;
        tile_s = tile_s_value;
        tile_e = tile_e_value;
        tile_p = tile_p_value;
        tile_f = tile_f_value;
        this.stream_vector_path = stream_vector_path;
        warned_step_mismatch = 1'b0;
        clear_payloads();

        fd = $fopen(stream_vector_path, "r");
        if (fd == 0) begin
            `uvm_fatal("CORE CSV", $sformatf("Failed to open stream vector CSV: %s", stream_vector_path))
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
                    `uvm_warning("CORE CSV", $sformatf("Skipping malformed CSV line %0d: %s", line_no, line))
                end
                continue;
            end

            if (head_id >= NumHeads) begin
                `uvm_warning("CORE CSV", $sformatf("Skipping illegal head row at line %0d: head_id=%0d", line_no, head_id))
                continue;
            end

            if (step_name == "") begin
                `uvm_fatal("CORE CSV", $sformatf("CSV line %0d does not provide a step field", line_no))
            end

            row_step = parse_step_name(step_name);
            if (!warned_step_mismatch && stream_step_value != Idle && row_step != stream_step_value) begin
                `uvm_warning("CORE CSV",
                    $sformatf("Compatibility step argument %s differs from CSV step %s at line %0d; using CSV step",
                        stream_step_value.name(), row_step.name(), line_no))
                warned_step_mismatch = 1'b1;
            end
            payload = get_payload(row_step);
            payload.enabled = 1'b1;
            payload.step = row_step;
            add_step_to_order(row_step);

            if (payload_text.len() >= 2 &&
                (payload_text.substr(0, 1) == "0x" || payload_text.substr(0, 1) == "0X")) begin
                payload_hex = payload_text.substr(2, payload_text.len() - 1);
            end else begin
                payload_hex = payload_text;
            end
            payload_bits = parse_hex_payload_bits(payload_hex);

            case (kind)
                "head_input": begin
                    payload.input_payload_by_head[head_id].push_back(inp_t'(payload_bits));
                end
                "head_weight": begin
                    payload.weight_payload_by_head[head_id].push_back(inp_weight_t'(payload_bits));
                end
                "head_bias": begin
                    payload.bias_payload_by_head[head_id].push_back(bias_t'(payload_bits));
                end
                default: begin
                    `uvm_warning("CORE CSV", $sformatf("Skipping unsupported stream kind at line %0d: %s", line_no, kind))
                end
            endcase
        end

        $fclose(fd);

        foreach (step_order[i]) begin
            payload = get_payload(step_order[i]);
            payload.validate_complete();
        end

        first_step = first_payload_step();
        log_payload = get_payload(first_step);

        `uvm_info("CORE CSV",
            $sformatf("Loaded stream CSV %s: layer=%s first_step=%s steps=%0d head0 input=%0d weight=%0d bias=%0d",
                stream_vector_path, layer.name(), first_step.name(), step_order.size(),
                  (log_payload == null) ? 0 : log_payload.input_payload_by_head[0].size(),
                (log_payload == null) ? 0 : log_payload.weight_payload_by_head[0].size(),
                (log_payload == null) ? 0 : log_payload.bias_payload_by_head[0].size()),
            UVM_LOW)
    endfunction : load_stream_csv
endclass : ita_mha8_core_item

`endif // ITA_MHA8_CORE_ITEM_SVH
