const std = @import("std");
const seizer = @import("./seizer.zig");
const Texture = seizer.Texture;
const SpriteBatch = seizer.batch.SpriteBatch;
const Rect = seizer.batch.Rect;
const Quad = seizer.batch.Quad;
const geom = @import("geometry.zig");

pub const NinePatch = struct {
    tex: Texture,
    texPos1: [2]f32,
    texPos2: [2]f32,
    tile_size: [2]f32,

    pub fn initv(tex: Texture, aabb: geom.AABB, tile_size: [2]f32) @This() {
        const rect = geom.aabb.as_rect(aabb);
        return @This(){
            .tex = tex,
            .texPos1 = tex.pix2uv(geom.rect.top_left(rect)),
            .texPos2 = tex.pix2uv(geom.rect.bottom_right(rect)),
            .tile_size = tile_size,
        };
    }

    pub fn init(texPos1: [2]f32, texPos2: [2]f32, tile_size: [2]f32) @This() {
        return @This(){
            .texPos1 = texPos1,
            .texPos2 = texPos2,
            .tile_size = tile_size,
        };
    }

    pub fn draw(this: @This(), renderer: *SpriteBatch, rect: geom.Rectf, scale: f32) void {
        const rects = this.getRects();
        const tl = geom.rect.top_leftf(rect);
        const size = geom.rect.sizef(rect);
        const quads = this.getQuads(tl, size, scale);
        for (quads, 0..) |quad, i| {
            renderer.drawTexture(this.tex, quad.pos, .{ .size = quad.size, .rect = rects[i] });
        }
    }

    fn getQuads(this: @This(), pos: [2]f32, size: [2]f32, scale: f32) [9]Quad {
        const ts = .{
            this.tile_size[0] * scale,
            this.tile_size[1] * scale,
        };
        const inner_size = .{ size[0] - ts[0] * 2, size[1] - ts[1] * 2 };

        const x1 = pos[0];
        const x2 = pos[0] + ts[0];
        const x3 = pos[0] + size[0] - ts[0];

        const y1 = pos[1];
        const y2 = pos[1] + ts[1];
        const y3 = pos[1] + size[1] - ts[1];

        return [9]Quad{
            // Inside first
            .{ .pos = .{ x2, y2 }, .size = inner_size }, // center
            // Edges second
            .{ .pos = .{ x2, y1 }, .size = .{ inner_size[0], ts[1] } }, // top
            .{ .pos = .{ x1, y2 }, .size = .{ ts[0], inner_size[1] } }, // left
            .{ .pos = .{ x3, y2 }, .size = .{ ts[0], inner_size[1] } }, // right
            .{ .pos = .{ x2, y3 }, .size = .{ inner_size[0], ts[1] } }, // bottom
            // Corners third
            .{ .pos = .{ x1, y1 }, .size = ts }, // tl
            .{ .pos = .{ x3, y1 }, .size = ts }, // tr
            .{ .pos = .{ x1, y3 }, .size = ts }, // bl
            .{ .pos = .{ x3, y3 }, .size = ts }, // br
        };
    }

    fn getRects(this: @This()) [9]Rect {
        const pos1 = this.texPos1;
        const pos2 = this.texPos2;
        const w = pos2[0] - pos1[0];
        const h = pos2[1] - pos1[1];
        const h1 = pos1[0];
        const h2 = pos1[0] + w / 3;
        const h3 = pos1[0] + 2 * w / 3;
        const h4 = pos2[0];
        const v1 = pos1[1];
        const v2 = pos1[1] + h / 3;
        const v3 = pos1[1] + 2 * h / 3;
        const v4 = pos2[1];
        return [9]Rect{
            // Inside first
            .{ .min = .{ h2, v2 }, .max = .{ h3, v3 } },
            // Edges second
            .{ .min = .{ h2, v1 }, .max = .{ h3, v2 } }, // top
            .{ .min = .{ h1, v2 }, .max = .{ h2, v3 } }, // left
            .{ .min = .{ h3, v2 }, .max = .{ h4, v3 } }, // right
            .{ .min = .{ h2, v3 }, .max = .{ h3, v4 } }, // bottom
            // Corners third
            .{ .min = .{ h1, v1 }, .max = .{ h2, v2 } }, // tl
            .{ .min = .{ h3, v1 }, .max = .{ h4, v2 } }, // tr
            .{ .min = .{ h1, v3 }, .max = .{ h2, v4 } }, // bl
            .{ .min = .{ h3, v3 }, .max = .{ h4, v4 } }, // br
        };
    }
};
