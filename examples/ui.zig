//! This example loads a texture from a file (using the Texture struct from seizer which uses image
//! parsing from zigimg), and then renders it to the screen. It avoids using the SpriteBatcher to
//! demonstrate how to render a textured rectangle to the screen at a low level.
const std = @import("std");
const seizer = @import("seizer");
const gl = seizer.gl;
const builtin = @import("builtin");
const store = seizer.ui.store;
const math = seizer.math;
const geom = seizer.geometry;
const Texture = seizer.Texture;
const SpriteBatch = seizer.batch.SpriteBatch;
const BitmapFont = seizer.font.Bitmap;
const NinePatch = seizer.ninepatch.NinePatch;
const UIStage = seizer.ui.Stage;
const Stage = UIStage(NodeStyle);

/// All of the possible frame styles for nodes
const NodeStyle = enum {
    None,
    Frame,
    Nameplate,
    Label,
    Keyrest,
    Keyup,
    Keydown,

    pub fn frame(style: NodeStyle) Stage.Node {
        return Stage.Node{ .style = style, .padding = style.get_padding() };
    }

    pub fn get_padding(style: NodeStyle) geom.Rect {
        switch (style) {
            .None => return geom.Rect{ 0, 0, 0, 0 },
            .Frame => return geom.Rect{ 16, 16, 16, 16 },
            .Nameplate => return geom.Rect{ 16, 16, 16, 16 },
            .Label => return geom.Rect{ 4, 4, 4, 4 },
            .Keyup => return geom.Rect{ 8, 7, 8, 9 },
            .Keyrest => return geom.Rect{ 8, 8, 8, 8 },
            .Keydown => return geom.Rect{ 8, 9, 8, 7 },
        }
    }
};

const Painter = struct {
    batch: *SpriteBatch,
    store: store.Store,
    font: *BitmapFont,
    ninepatch: std.EnumMap(NodeStyle, NinePatch),
    scale: f32,

    pub fn deinit(painter: *Painter) void {
        painter.store.deinit();
    }

    pub fn size(painter: *Painter, node: Stage.Node) geom.Vec2 {
        if (node.data) |data| {
            const value = painter.store.get(data);
            switch (value) {
                .Bytes => |string| {
                    const width = painter.font.calcTextWidth(string, painter.scale);
                    const height = painter.font.lineHeight * painter.scale;
                    return geom.vec.ftoi(geom.Vec2f{ width, height });
                },
                .Int => |int| {
                    var buf: [32]u8 = undefined;
                    const string = std.fmt.bufPrint(&buf, "{}", .{int}) catch buf[0..];
                    const width = painter.font.calcTextWidth(string, painter.scale);
                    const height = painter.font.lineHeight * painter.scale;
                    return geom.vec.ftoi(geom.Vec2f{ width, height });
                },
                else => {},
            }
        }
        return geom.Vec2{ 0, 0 };
    }

    pub fn padding(painter: *Painter, node: Stage.Node) geom.Rect {
        _ = painter;
        const scale = @splat(4, @floatToInt(i32, painter.scale));
        switch (node.style) {
            .None => return geom.Rect{ 0, 0, 0, 0 } * scale,
            .Frame => return geom.Rect{ 16, 16, 16, 16 } * scale,
            .Nameplate => return geom.Rect{ 16, 16, 16, 16 } * scale,
            .Label => return geom.Rect{ 4, 4, 4, 4 } * scale,
            .Keyup => return geom.Rect{ 8, 7, 8, 9 } * scale,
            .Keyrest => return geom.Rect{ 8, 8, 8, 8 } * scale,
            .Keydown => return geom.Rect{ 8, 9, 8, 7 } * scale,
        }
    }

    pub fn paint(painter: *Painter, node: Stage.Node) void {
        if (painter.ninepatch.get(node.style)) |ninepatch| {
            ninepatch.draw(painter.batch, geom.rect.itof(node.bounds), painter.scale);
        }
        if (node.data) |data| {
            const value = painter.store.get(data);
            const vec2 = math.Vec2f.init;
            const area = node.bounds + (painter.padding(node) * geom.Rect{ 1, 1, -1, -1 });
            const top_left = vec2(@intToFloat(f32, area[0]), @intToFloat(f32, area[1]));
            switch (value) {
                .Bytes => |string| {
                    painter.font.drawText(painter.batch, string, top_left, .{
                        .textBaseline = .Top,
                        .scale = painter.scale,
                        .color = seizer.batch.Color.BLACK,
                        .area = geom.rect.itof(node.bounds),
                    });
                },
                .Int => |int| {
                    var buf: [32]u8 = undefined;
                    const string = std.fmt.bufPrint(&buf, "{}", .{int}) catch buf[0..];
                    painter.font.drawText(painter.batch, string, top_left, .{
                        .textBaseline = .Top,
                        .scale = painter.scale,
                        .color = seizer.batch.Color.BLACK,
                        .area = geom.rect.itof(node.bounds),
                    });
                },
                else => {},
            }
        }
    }
};

// Call the comptime function `seizer.run`, which will ensure that everything is
// set up for the platform we are targeting.
pub usingnamespace seizer.run(.{
    .init = init,
    .event = event,
    .deinit = deinit,
    .render = render,
});

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var batch: SpriteBatch = undefined;
var stage: Stage = undefined;
var painter_global: Painter = undefined;

// Assets
var font: BitmapFont = undefined;
var uitexture: Texture = undefined;

var last_focused_node: ?Stage.Node = null;
var increment: usize = undefined;
var decrement: usize = undefined;
var counter_label: usize = undefined;
var counter_ref: store.Ref = undefined;
var text_ref: store.Ref = undefined;
var textinput: usize = undefined;
var is_typing = false;
var cursor: f32 = 0;

fn init() !void {
    font = try BitmapFont.initFromFile(gpa.allocator(), "PressStart2P_8.fnt");
    errdefer font.deinit();

    uitexture = try Texture.initFromFile(gpa.allocator(), "ui.png", .{});
    errdefer uitexture.deinit();

    batch = try SpriteBatch.init(gpa.allocator(), .{ .x = 1, .y = 1 });

    painter_global = Painter{
        .batch = &batch,
        .store = store.Store.init(gpa.allocator()),
        .font = &font,
        .ninepatch = std.EnumMap(NodeStyle, NinePatch).init(.{
            .Frame = NinePatch.initv(uitexture, .{ 0, 0, 48, 48 }, .{ 16, 16 }),
            .Nameplate = NinePatch.initv(uitexture, .{ 48, 0, 48, 48 }, .{ 16, 16 }),
            .Label = NinePatch.initv(uitexture, .{ 96, 24, 12, 12 }, .{ 4, 4 }),
            .Keyrest = NinePatch.initv(uitexture, .{ 96, 0, 24, 24 }, .{ 8, 8 }),
            .Keyup = NinePatch.initv(uitexture, .{ 120, 24, 24, 24 }, .{ 8, 8 }),
            .Keydown = NinePatch.initv(uitexture, .{ 120, 0, 24, 24 }, .{ 8, 8 }),
        }),
        .scale = 2,
    };
    stage = try Stage.init(gpa.allocator());

    // Create values in the store to be used by the UI
    const name_ref = try painter_global.store.new(.{ .Bytes = "Hello, World!" });
    counter_ref = try painter_global.store.new(.{ .Int = 0 });
    const dec_label_ref = try painter_global.store.new(.{ .Bytes = "<" });
    const inc_label_ref = try painter_global.store.new(.{ .Bytes = ">" });
    text_ref = try painter_global.store.new(.{ .Bytes = "" });

    // Create the layout for the UI
    const center = try stage.insert(null, NodeStyle.frame(.None).container(.Center));
    const frame = try stage.insert(center, NodeStyle.frame(.Frame).container(.VList));
    const nameplate = try stage.insert(frame, NodeStyle.frame(.Nameplate).dataValue(name_ref));
    const counter_center = try stage.insert(frame, NodeStyle.frame(.None).container(.Center));
    const counter = try stage.insert(counter_center, NodeStyle.frame(.None).container(.HList));
    decrement = try stage.insert(counter, NodeStyle.frame(.Keyrest).dataValue(dec_label_ref));
    const label_center = try stage.insert(counter, NodeStyle.frame(.None).container(.Center));
    counter_label = try stage.insert(label_center, NodeStyle.frame(.Label).dataValue(counter_ref));
    increment = try stage.insert(counter, NodeStyle.frame(.Keyrest).dataValue(inc_label_ref));
    textinput = try stage.insert(frame, NodeStyle.frame(.Label).dataValue(text_ref));
    _ = nameplate;

    for (stage.nodes.items) |*node| {
        node.min_size = painter_global.size(node.*);
        node.padding = painter_global.padding(node.*);
    }
}

fn deinit() void {
    stage.deinit();
    painter_global.deinit();
    font.deinit();
    batch.deinit();
    _ = gpa.deinit();
}

fn event(e: seizer.event.Event) !void {
    switch (e) {
        .MouseMotion => |mouse| {
            const mouse_pos = geom.Vec2{ mouse.pos.x, mouse.pos.y };
            if (stage.get_node_at_point(mouse_pos)) |*node| hover: {
                if (last_focused_node) |*last_node| {
                    if (node.handle == last_node.handle) break :hover;
                    last_node.style = .Keyrest;
                    _ = stage.set_node(last_node.*);
                    last_focused_node = null;
                }
                if (node.style == .Keyrest) {
                    node.style = .Keyup;
                    _ = stage.set_node(node.*);
                    last_focused_node = node.*;
                }
            } else if (last_focused_node) |*last_node| {
                last_node.style = .Keyrest;
                _ = stage.set_node(last_node.*);
                last_focused_node = null;
            }
        },
        .MouseButtonDown => |mouse| {
            is_typing = false;
            const mouse_pos = geom.Vec2{ mouse.pos.x, mouse.pos.y };
            if (stage.get_node_at_point(mouse_pos)) |*node| {
                if (node.style == .Keyup) {
                    node.style = .Keydown;
                    _ = stage.set_node(node.*);
                    last_focused_node = node.*;
                }
                if (node.handle == textinput) {
                    is_typing = true;
                }
            }
        },
        .MouseButtonUp => |mouse| {
            const mouse_pos = geom.Vec2{ mouse.pos.x, mouse.pos.y };
            if (stage.get_node_at_point(mouse_pos)) |*node| click: {
                if (node.style == .Keydown) {
                    if (last_focused_node) |last| {
                        if (node.handle != last.handle) break :click;
                    } else break :click;
                    if (node.handle == increment) {
                        var count = painter_global.store.get(counter_ref);
                        count.Int += 1;
                        try painter_global.store.set(.Int, counter_ref, count.Int);
                        stage.modified = true;
                        if (stage.get_node(counter_label)) |label| {
                            const size = painter_global.size(label);
                            stage.update_min_size(counter_label, size);
                        }
                    } else if (node.handle == decrement) {
                        var count = painter_global.store.get(counter_ref);
                        count.Int -= 1;
                        try painter_global.store.set(.Int, counter_ref, count.Int);
                        stage.modified = true;
                        if (stage.get_node(counter_label)) |label| {
                            const size = painter_global.size(label);
                            stage.update_min_size(counter_label, size);
                        }
                    }
                    node.style = .Keyup;
                    _ = stage.set_node(node.*);
                    last_focused_node = node.*;
                }
            }
        },
        .TextInput => |input| {
            if (is_typing) {
                const string = painter_global.store.get(text_ref).Bytes;
                const new_string = try std.mem.concat(gpa.allocator(), u8, &.{ string, input.text() });
                defer gpa.allocator().free(new_string);
                cursor = font.calcTextWidth(new_string, painter_global.scale);
                try painter_global.store.set(.Bytes, text_ref, new_string);
            }
        },
        .KeyDown => |key| {
            if (key.key == .BACKSPACE and is_typing) {
                const string = painter_global.store.get(text_ref).Bytes;
                const len = string.len -| 1;
                const new_string = string[0..len];
                cursor = font.calcTextWidth(new_string, painter_global.scale);
                try painter_global.store.set(.Bytes, text_ref, new_string);
            }
        },
        .Quit => {
            seizer.backend.quit();
        },
        else => {},
    }
}

// Error
fn render(alpha: f64) !void {
    _ = alpha;

    // Resize gl viewport to match window
    const screen_size = seizer.getScreenSize();
    gl.viewport(0, 0, screen_size.x, screen_size.y);
    batch.setSize(screen_size);

    gl.clearColor(0.7, 0.5, 0.5, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    stage.layout(.{ 0, 0, screen_size.x, screen_size.y });
    for (stage.get_rects()) |node| {
        painter_global.paint(node);
    }

    if (is_typing) cursor: {
        const node = stage.get_node(textinput) orelse break :cursor;
        const rect = geom.rect.itof(node.bounds + node.padding * geom.Rect{ 1, 1, -1, -1 });
        font.drawText(&batch, "|", .{ .x = rect[0] + cursor, .y = rect[1] }, .{
            .textBaseline = .Top,
            .color = seizer.batch.Color.BLACK,
            .scale = painter_global.scale,
        });
    }

    font.drawText(&batch, "Hello, world!", .{ .x = 50, .y = 50 }, .{});
    batch.flush();
}
