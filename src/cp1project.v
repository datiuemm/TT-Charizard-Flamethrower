/*
 * Project: Zizard & Fire (Balanced Logic)
 * Features: Normal state (Zizard), Input[0] active (Fire), Rain, Fixed Ground/Sky
 */
`default_nettype none

module tt_um_datdt_charizard(
    input  wire [7:0] ui_in,    // [0] Chuyển đổi: 0 = Zizard, 1 = Phun lửa
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

    // --- STATE CONTROL ---
    wire is_firing = ui_in[0]; 

    // --- ROMS & PALETTE ---
    // Giữ cả 2 ROM nhưng dùng chung logic đọc để giảm diện tích logic
    reg [2:0] rom_zizard[0:16383];
    reg [2:0] rom_fire[0:16383];
    reg [3:0] pal_r[0:7], pal_g[0:7], pal_b[0:7];

    initial begin
        $readmemh("../data/zizard.hex",  rom_zizard);
        $readmemh("../data/fire.hex",    rom_fire);
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
    // Tính toán địa chỉ chung cho cả 2 sprite
    wire [13:0] addr = {nyanframe, (pix_y[7:3] - 5'd18), (pix_x[8:3] - 6'd8)};
    reg [2:0] idx;

    always @* begin
        // Kiểm tra vùng hiển thị (Box: 64x144 đến 512x400)
        if ((pix_x >= 64 && pix_x < 512) && (pix_y >= 144 && pix_y < 400)) begin
            // Swap ROM dựa trên input
            idx = is_firing ? rom_fire[addr] : rom_zizard[addr];
        end else begin
            idx = 0;
        end
    end

    // --- RAIN LOGIC ---
    wire [9:0] rain_y = pix_y - (frame_count << 1);
    wire rain = (idx == 0) && (pix_x[6:1] == line_lfsr[6:1]) && (rain_y[5:0] < 12);

    // --- MAIN CONTROL BLOCK ---
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            frame_count <= 0; 
            nyanframe <= 0; 
            line_lfsr <= 7'h5a;
        end else begin
            if (pix_x == 0 && pix_y == 0) begin
                frame_count <= frame_count + 1;
                // Tốc độ chuyển frame animation (mỗi 4 frame VGA chuyển 1 frame ROM)
                if (frame_count[1:0] == 0) 
                    nyanframe <= (nyanframe == 5) ? 0 : nyanframe + 1;
                line_lfsr <= 7'h5a;
            end else if (pix_x == 0 && pix_y[3:0] == 0) begin
                line_lfsr <= line_lfsr_next;
            end

            // --- COLOR OUTPUT ---
            if (video_active) begin
                if (idx != 0) begin
                    // Hiển thị Sprite (Zizard hoặc Fire)
                    R <= pal_r[idx][3:2]; 
                    G <= pal_g[idx][3:2]; 
                    B <= pal_b[idx][3:2];
                end else if (rain) begin
                    R <= 2'b10; G <= 2'b10; B <= 2'b11; // Màu mưa (Xanh nhạt)
                end else begin
                    // Phân chia nền Trời / Cỏ
                    if (pix_y < 350) begin
                        R <= 2'b00; G <= 2'b00; B <= 2'b01; // Sky
                    end else begin
                        R <= 2'b00; G <= 2'b01; B <= 2'b00; // Grass
                    end
                end
            end else begin
                {R, G, B} <= 6'b0;
            end
        end
    end

    // Unused
    assign uio_out = 8'b0; 
    assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in[7:1], uio_in};

endmodule
