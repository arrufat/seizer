const std = @import("std");
const seizer = @import("../seizer.zig");

pub const SoundHandle = struct {
    id: u32,
};

pub const NodeHandle = struct {
    id: u32,
};

pub const BiquadOptions = struct {
    kind: enum(u4) {
        lowpass = 0,
        highpass,
        bandpass,
        lowshelf,
        highshelf,
        peaking,
        notch,
        allpass,
    },
    freq: f32,
    q: f32,
    gain: f32 = 1.0,
};

pub const MixerInput = struct {
    handle: NodeHandle,
    gain: f32,
};

pub const Engine = struct {
    pub fn init(this: *@This(), allocator: std.mem.Allocator) !void {
        _ = allocator;

        bindings.init();
        this.* = @This(){};
    }

    pub fn deinit(this: *@This()) void {
        _ = this;

        bindings.deinit();
    }

    // TODO: Remove allocator from function interface?
    pub fn load(this: *@This(), allocator: std.mem.Allocator, filename: [:0]const u8, max_size: usize) !SoundHandle {
        _ = this;
        _ = allocator;
        _ = max_size;

        var sound_id: i32 = undefined;
        suspend {
            bindings.load(@intFromPtr(@frame()), filename.ptr, filename.len, &sound_id);
        }
        return SoundHandle{ .id = try unwrapRetCode(sound_id) };
    }

    pub fn createSoundNode(this: *@This()) NodeHandle {
        _ = this;

        const ret = bindings.createSoundNode();
        const node_id = unwrapRetCode(ret) catch unreachable;
        return NodeHandle{ .id = node_id };
    }

    pub fn createBiquadNode(this: *@This(), inputNode: NodeHandle, options: BiquadOptions) NodeHandle {
        _ = this;

        const ret = bindings.createBiquadNode(
            inputNode.id,
            @intFromEnum(options.kind),
            options.freq,
            options.q,
            options.gain,
        );
        const node_id = unwrapRetCode(ret) catch unreachable;
        return NodeHandle{ .id = node_id };
    }

    pub fn createMixerNode(this: *@This(), inputs: []const MixerInput) !NodeHandle {
        _ = this;

        const ret = bindings.createMixerNode();
        const node_id = try unwrapRetCode(ret);
        for (inputs) |input| {
            _ = try unwrapRetCode(bindings.connectToMixer(node_id, input.handle.id, input.gain));
        }
        return NodeHandle{ .id = node_id };
    }

    pub fn createDelayOutputNode(this: *@This(), delaySeconds: f32) !NodeHandle {
        _ = this;

        const ret = bindings.createDelayOutputNode(delaySeconds);
        const node_id = try unwrapRetCode(ret);
        return NodeHandle{ .id = node_id };
    }

    pub fn createDelayInputNode(this: *@This(), inputNode: NodeHandle, delayOutputNode: NodeHandle) !void {
        _ = this;

        const ret = bindings.createDelayInputNode(inputNode.id, delayOutputNode.id);
        _ = try unwrapRetCode(ret);
    }

    pub fn connectToOutput(this: *@This(), nodeHandle: NodeHandle) void {
        _ = this;

        bindings.connectToOutput(nodeHandle.id);
    }

    pub fn play(this: *@This(), nodeHandle: NodeHandle, soundHandle: SoundHandle) void {
        _ = this;

        bindings.play(nodeHandle.id, soundHandle.id);
    }

    pub fn freeSound(_: *@This(), handle: SoundHandle) void {
        bindings.freeSound(handle.id);
    }

    fn unwrapRetCode(retCode: i32) !u32 {
        if (retCode >= 0) return @as(u32, @intCast(retCode));
        switch (retCode) {
            bindings.ERROR_UNKNOWN => return error.Unknown,
            else => unreachable,
        }
    }
};

export fn @"resume"(framePtr: usize) void {
    const frame = @as(anyframe, @ptrFromInt(framePtr));
    resume frame;
}

const bindings = struct {
    pub const ERROR_UNKNOWN = -1;

    pub extern "audio_engine" fn init() void;
    pub extern "audio_engine" fn deinit() void;
    pub extern "audio_engine" fn load(framePtr: usize, filenamePtr: [*]const u8, filenameLen: usize, idOut: *i32) void;
    pub extern "audio_engine" fn freeSound(soundId: u32) void;
    pub extern "audio_engine" fn createSoundNode() i32;
    pub extern "audio_engine" fn createBiquadNode(inputId: u32, filterKind: u32, filterFreq: f32, filterQ: f32, filterGain: f32) i32;
    pub extern "audio_engine" fn createMixerNode() i32;
    pub extern "audio_engine" fn connectToMixer(mixerId: u32, inputId: u32, gain: f32) i32;
    pub extern "audio_engine" fn createDelayOutputNode(delaySeconds: f32) i32;
    pub extern "audio_engine" fn createDelayInputNode(inputId: u32, delayOutputId: u32) i32;
    pub extern "audio_engine" fn connectToOutput(inputId: u32) void;
    pub extern "audio_engine" fn play(nodeId: u32, soundId: u32) void;
};
