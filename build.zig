const std = @import("std");

const raylib_prefix = "/opt/homebrew/opt/raylib";

/// raylib + macOS 프레임워크 + tinyfiledialogs(폴더 선택) 링크 설정.
fn linkDeps(b: *std.Build, mod: *std.Build.Module) void {
    mod.addIncludePath(.{ .cwd_relative = raylib_prefix ++ "/include" });
    mod.addLibraryPath(.{ .cwd_relative = raylib_prefix ++ "/lib" });
    mod.linkSystemLibrary("raylib", .{});
    mod.linkFramework("Cocoa", .{});
    mod.linkFramework("IOKit", .{});
    mod.linkFramework("CoreVideo", .{});
    mod.linkFramework("CoreAudio", .{});
    mod.linkFramework("OpenGL", .{});

    // tinyfiledialogs: 네이티브 폴더 선택 다이얼로그
    mod.addIncludePath(b.path("vendor/tinyfiledialogs"));
    mod.addCSourceFile(.{
        .file = b.path("vendor/tinyfiledialogs/tinyfiledialogs.c"),
        .flags = &.{"-Wno-implicit-function-declaration"},
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    linkDeps(b, exe_mod);

    const exe = b.addExecutable(.{ .name = "zig_photo", .root_module = exe_mod });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run zig_photo");
    run_step.dependOn(&run_cmd.step);

    // 테스트
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    linkDeps(b, test_mod);
    const unit_tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}
