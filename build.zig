const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_prefix = "/opt/homebrew/opt/raylib";

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    mod.addIncludePath(.{ .cwd_relative = raylib_prefix ++ "/include" });
    mod.addLibraryPath(.{ .cwd_relative = raylib_prefix ++ "/lib" });
    mod.linkSystemLibrary("raylib", .{});

    // macOS frameworks required by raylib
    mod.linkFramework("Cocoa", .{});
    mod.linkFramework("IOKit", .{});
    mod.linkFramework("CoreVideo", .{});
    mod.linkFramework("CoreAudio", .{});
    mod.linkFramework("OpenGL", .{});

    const exe = b.addExecutable(.{
        .name = "zig_photo",
        .root_module = mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run zig_photo");
    run_step.dependOn(&run_cmd.step);
}
