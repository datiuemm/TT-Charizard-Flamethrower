/*
 * Copyright (c) 2024 Andy Sloane
 * SPDX-License-Identifier: Apache-2.0
 * Edited by Dat Dinh Trong
 */
`default_nettype none

module tt_um_datdt_charizard(
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena, clk, rst_n
);

    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    reg [1:0] R, G, B;
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    hvsync_generator hvsync_gen(
        .clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync),
        .display_on(video_active), .hpos(pix_x), .vpos(pix_y)
    );

    wire is_firing = 1; 

    reg [2:0] rom_fire[0:16383];
    reg [3:0] pal_r[0:7], pal_g[0:7], pal_b[0:7];

    initial begin
        $readmemh("../data/fire.hex",     rom_fire);
        $readmemh("../data/palette_r.hex", pal_r);
        $readmemh("../data/palette_g.hex", pal_g);
        $readmemh("../data/palette_b.hex", pal_b);
    end

    reg [7:0] frame_count;
    reg [2:0] nyanframe;
    reg [6:0] line_lfsr;
    wire [6:0] line_lfsr_next = {line_lfsr[0], line_lfsr[0]^line_lfsr[6], line_lfsr[5:1]};

    wire [13:0] addr = {nyanframe, (pix_y[7:3] - 5'd18), (pix_x[8:3] - 6'd8)};
    reg [2:0] idx;

    always @* begin
        if (is_firing && (pix_x >= 64 && pix_x < 512) && (pix_y >= 144 && pix_y < 400)) begin
            idx = rom_fire[addr];
        end else begin
            idx = 0;
        end
    end

    wire [9:0] rain_y = pix_y - (frame_count << 1);
    wire rain = (idx == 0) && (pix_x[6:1] == line_lfsr[6:1]) && (rain_y[5:0] < 12);

    wire bi = pix_x[0] ^ frame_count[0];
    wire bj = pix_y[0] ^ frame_count[0];
    wire [1:0] bayer = { (bi ^ bj), bi };

    reg [3:0] raw_r, raw_g, raw_b;
    always @* begin
        if (idx != 0) begin
            raw_r = pal_r[idx]; raw_g = pal_g[idx]; raw_b = pal_b[idx];
        end else if (rain) begin
            raw_r = 4'hA; raw_g = 4'hA; raw_b = 4'hF;
        end else begin
            if (pix_y < 350) begin
                raw_r = 4'h0; raw_g = 4'h0; raw_b = 4'h4;
            end else begin
                raw_r = 4'h0; raw_g = 4'h5; raw_b = 4'h0;
            end
        end
    end

    wire [3:0] dr = raw_r + {2'b0, bayer};
    wire [3:0] dg = raw_g + {2'b0, bayer};
    wire [3:0] db = raw_b + {2'b0, bayer};

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            frame_count <= 0; nyanframe <= 0; line_lfsr <= 7'h5a;
            R <= 0; G <= 0; B <= 0;
        end else begin
            if (pix_x == 0 && pix_y == 0) begin
                frame_count <= frame_count + 1;
                if (frame_count[1:0] == 0) 
                    nyanframe <= (nyanframe == 5) ? 0 : nyanframe + 1;
                line_lfsr <= 7'h5a;
            end else if (pix_x == 0 && pix_y[3:0] == 0) begin
                line_lfsr <= line_lfsr_next;
            end

            if (video_active) begin
                R <= dr[3:2]; 
                G <= dg[3:2]; 
                B <= db[3:2];
            end else begin
                {R, G, B} <= 6'b0;
            end
        end
    end

    assign uio_out = 8'b0; 
    assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in, uio_in};
endmodule
