const std = @import("std");
const Builder = std.build.Builder;
const HTMLBundleStep = @import("tools/HTMLBundleStep.zig");

const Example = enum {
    clear,
    textures,
    bitmap_font,
    sprite_batch,
    ui,
    scene,
};

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Download git repositories
    const zigimg_dep = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.addModule("seizer", .{
        .source_file = .{ .path = "src/seizer.zig" },
        .dependencies = &.{
            .{ .name = "zigimg", .module = zigimg_dep.module("zigimg") },
        },
    });

    const library = b.addStaticLibrary(.{
        .name = "seizer",
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(library);
    library.linkLibC();
    library.linkSystemLibrary("sdl2");

    const example_option = b.option(Example, "example", "Specify which example to run/build/install");

    const example_fields = @typeInfo(Example).Enum.fields;
    inline for (example_fields) |tag| {
        if (target.getCpuArch() != .wasm32) {
            const tag_name = tag.name;
            const exe = b.addExecutable(.{
                .name = tag_name,
                .root_source_file = .{ .path = "examples/" ++ tag_name ++ ".zig" },
                .target = target,
                .optimize = optimize,
            });
            b.installArtifact(exe);
            exe.linkLibrary(library);
            exe.addModule("seizer", module);

            if (example_option != null and std.mem.eql(u8, tag_name, @tagName(example_option.?))) {
                const run_cmd = b.addRunArtifact(exe);
                run_cmd.step.dependOn(b.getInstallStep());

                if (b.args) |args| {
                    run_cmd.addArgs(args);
                }

                const run_step = b.step("run", "Run the example specified by -Dexample");
                run_step.dependOn(&run_cmd.step);
            }
        } else {
            const tag_name = tag.name;
            const exe = b.addSharedLibrary(.{
                .name = tag_name,
                .root_source_file = .{ .path = "examples/" ++ tag_name ++ ".zig" },
                .target = target,
                .optimize = optimize,
            });
            b.installArtifact(exe);
            exe.linkLibrary(library);
            exe.addModule("seizer", module);

            const seizerjs = std.build.FileSource{ .path = "src/web/seizer.js" };
            // const seizerjs = b.addInstallFile(.{ .path = "src/web/seizer.js" }, "www/seizer.js");

            const web_bundle = try HTMLBundleStep.create(b, .{
                .path = "www",
                .js_path = seizerjs,
                .wasm_path = exe.getOutputSource(),
                .output_name = b.fmt("{s}.html", .{tag_name}),
                .title = tag_name,
            });

            web_bundle.step.dependOn(b.getInstallStep());
            web_bundle.step.dependOn(&exe.step);

            const bundle_step = b.step("bundle", "Creates a static html page with scripts + assets included");
            bundle_step.dependOn(&web_bundle.step);
            // b.getInstallStep().dependOn(&web_bundle.step);
            // build_examples_web.dependOn(build_web);
        }
    }
}
