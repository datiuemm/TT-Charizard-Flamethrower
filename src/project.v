/*
 * Project: Nyan Cat Evolution (Mander -> Melon -> Zizard)
 * Features: Rain effect, Evolution Logic, Fixed Ground/Sky rendering
 */

`default_nettype none

module tt_um_datdt_charizard(
    input  wire [7:0] ui_in,    // Gamepad: [6]=Data, [5]=Clk, [4]=Latch
    output wire [7:0] uo_out,   // VGA: {hsync, B0, G0, R0, vsync, B1, G1, R1}
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena, clk, rst_n
);

    // --- VGA SIGNALS ---
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    reg [1:0] R, G, B;
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    hvsync_generator hvsync_gen(
        .clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync),
        .display_on(video_active), .hpos(pix_x), .vpos(pix_y)
    );

    // --- GAMEPAD ---
    wire g_up, g_down, g_start;
    gamepad_pmod_single gp(
        .rst_n(rst_n), .clk(clk), 
        .pmod_data(ui_in[6]), .pmod_clk(ui_in[5]), .pmod_latch(ui_in[4]), 
        .start(g_start), .up(g_up), .down(g_down)
    );

    // --- EVOLUTION & FLASH ---
    reg [1:0] evo_state; // 0: Mander, 1: Melon, 2: Zizard
    reg [5:0] pattern_cnt;
    reg [5:0] flash_tmr;
    reg is_firing;
    reg u_prev, d_prev;

    // --- ROMS & PALETTE ---
    reg [2:0] rom_mander[0:16383], rom_melon[0:16383], rom_zizard[0:16383], rom_fire[0:16383];
    reg [3:0] pal_r[0:7], pal_g[0:7], pal_b[0:7];

    initial begin
        $readmemh("../data/mander.hex", rom_mander);
        $readmemh("../data/melon.hex", rom_melon);
        $readmemh("../data/zizard.hex", rom_zizard); 
        $readmemh("../data/fire.hex",   rom_fire);
        $readmemh("../data/palette_r.hex", pal_r);
        $readmemh("../data/palette_g.hex", pal_g);
        $readmemh("../data/palette_b.hex", pal_b);
    end

    // --- ANIMATION & RAIN LFSR ---
    reg [7:0] frame_count;
    reg [2:0] nyanframe;
    reg [6:0] line_lfsr;
    wire [6:0] line_lfsr_next = {line_lfsr[0], line_lfsr[0]^line_lfsr[6], line_lfsr[5:1]};

    // --- RENDERING LOGIC ---
    wire [9:0] nx = pix_x - 64;
    reg [7:0] ny;
    
    always @* begin
        // Giữ offset 145 để nhân vật không bị mất phần trên (cổ)
        ny = (pix_y - 145) >> 3; 
    end

    wire [13:0] addr = {nyanframe, ny[4:0], nx[8:3]};
    reg [2:0] idx;

    always @* begin
        if ((nx < 512) && (ny < 32)) begin
            case(evo_state)
                2'd0: idx = rom_mander[addr];
                2'd1: idx = rom_melon[addr];
                2'd2: idx = is_firing ? rom_fire[addr] : rom_zizard[addr];
                default: idx = 0;
            endcase
        end else idx = 0;
    end

    // --- RAIN LOGIC ---
    wire [9:0] rain_y = pix_y - (frame_count << 1);
    wire rain = (idx == 0) && (pix_x[6:1] == line_lfsr[6:1]) && (rain_y[5:0] < 12);

    // --- MAIN CONTROL BLOCK ---
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            frame_count <= 0; nyanframe <= 0; evo_state <= 0;
            pattern_cnt <= 0; flash_tmr <= 0; line_lfsr <= 7'h5a;
        end else begin
            if (pix_x == 0 && pix_y == 0) begin
                u_prev <= g_up; d_prev <= g_down;
                if (flash_tmr > 0) flash_tmr <= flash_tmr - 1;
                is_firing <= (evo_state == 2'd2) && (g_up && g_down);

                // Pattern tiến hóa: Up 16 lần -> Cấp 1, Up tiếp 36 lần -> Cấp 2
                if (g_up && !u_prev) begin 
                    pattern_cnt <= pattern_cnt + 1;
                    if (evo_state==0 && pattern_cnt>=15) begin evo_state<=1; pattern_cnt<=0; flash_tmr<=45; end
                    if (evo_state==1 && pattern_cnt>=35) begin evo_state<=2; pattern_cnt<=0; flash_tmr<=45; end
                end else if (g_down && !d_prev) pattern_cnt <= 0;

                frame_count <= frame_count + 1;
                if (frame_count[1:0] == 0) nyanframe <= (nyanframe == 5) ? 0 : nyanframe + 1;
                line_lfsr <= 7'h5a;
            end else if (pix_x == 0 && pix_y[3:0] == 0) begin
                line_lfsr <= line_lfsr_next;
            end

            // --- XUẤT MÀU VÀ HIỂN THỊ NỀN ---
            if (flash_tmr > 0) begin
                {R, G, B} <= 6'b111111; // Chớp trắng khi tiến hóa
            end else if (video_active) begin
                if (idx != 0) begin
                    // Hiển thị nhân vật
                    R <= pal_r[idx][3:2]; G <= pal_g[idx][3:2]; B <= pal_b[idx][3:2];
                end else if (rain) begin
                    // Hiển thị hạt mưa
                    R <= 2'b10; G <= 2'b10; B <= 2'b11;
                end else begin
                    // HIỂN THỊ NỀN (TRỜI & CỎ)
                    if (pix_y < 350) begin
                        R <= 2'b00; G <= 2'b00; B <= 2'b01; // Trời tím than
                    end else begin
                        R <= 2'b00; G <= 2'b01; B <= 2'b00; // THẢM CỎ XANH LÁ
                    end
                end
            end else begin
                {R, G, B} <= 6'b000000;
            end
        end
    end

    assign uio_out = 8'b0; assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in[7], ui_in[3:0], uio_in, g_start};
endmodule


module gamepad_pmod_single (
    input wire rst_n, clk, pmod_data, pmod_clk, pmod_latch,
    output wire start, up, down
);
    reg [1:0] d_s, c_s, l_s;
    reg c_l, l_l;
    reg [11:0] s_reg;
    reg [2:0] btns;
    always @(posedge clk) begin
        d_s <= {d_s[0], pmod_data}; c_s <= {c_s[0], pmod_clk}; l_s <= {l_s[0], pmod_latch};
        c_l <= c_s[1]; l_l <= l_s[1];
        if (c_s[1] && !c_l) s_reg <= {s_reg[10:0], d_s[1]};
        if (l_s[1] && !l_l) btns <= (s_reg == 12'hfff) ? 3'b000 : s_reg[8:6];
    end
    assign {start, up, down} = btns;
endmodule
