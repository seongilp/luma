const std = @import("std");
const Io = std.Io;

/// MVP에서 지원하는 이미지 확장자 (소문자 비교).
const supported_exts = [_][]const u8{ ".jpg", ".jpeg", ".png" };

/// 확장자가 지원 이미지인지 판별. 대소문자 무시.
pub fn isSupportedImage(name: []const u8) bool {
    const dot = std.mem.lastIndexOfScalar(u8, name, '.') orelse return false;
    const ext = name[dot..];
    var buf: [8]u8 = undefined;
    if (ext.len > buf.len) return false;
    const lower = std.ascii.lowerString(buf[0..ext.len], ext);
    for (supported_exts) |se| {
        if (std.mem.eql(u8, lower, se)) return true;
    }
    return false;
}

/// 폴더를 재귀 스캔해 지원 이미지의 경로 목록을 반환한다.
/// 각 경로는 `root`를 앞에 붙인 형태이며, 슬라이스와 각 문자열은
/// 호출자가 allocator로 해제해야 한다.
/// 접근 불가한 하위 항목은 건너뛰고 로그만 남긴다 (크래시 금지).
pub fn scan(io: Io, allocator: std.mem.Allocator, root: []const u8) ![][]const u8 {
    var list: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (list.items) |p| allocator.free(p);
        list.deinit(allocator);
    }

    var dir = Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| {
        std.log.err("폴더 열기 실패 '{s}': {s}", .{ root, @errorName(err) });
        return err;
    };
    defer dir.close(io);

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (walker.next(io) catch |err| {
        std.log.warn("스캔 중 항목 건너뜀: {s}", .{@errorName(err)});
        return list.toOwnedSlice(allocator);
    }) |entry| {
        if (entry.kind != .file) continue;
        if (!isSupportedImage(entry.basename)) continue;
        const full = try std.fs.path.join(allocator, &.{ root, entry.path });
        try list.append(allocator, full);
    }

    return list.toOwnedSlice(allocator);
}

test "isSupportedImage: 확장자 판별" {
    try std.testing.expect(isSupportedImage("photo.jpg"));
    try std.testing.expect(isSupportedImage("photo.JPG"));
    try std.testing.expect(isSupportedImage("a.jpeg"));
    try std.testing.expect(isSupportedImage("a.PNG"));
    try std.testing.expect(!isSupportedImage("doc.txt"));
    try std.testing.expect(!isSupportedImage("noext"));
    try std.testing.expect(!isSupportedImage("photo.heic"));
}

test "scan: 재귀 스캔과 필터" {
    const a = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(io, .{ .sub_path = "a.jpg", .data = "x" });
    try tmp.dir.writeFile(io, .{ .sub_path = "b.txt", .data = "x" });
    try tmp.dir.createDirPath(io, "sub");
    try tmp.dir.writeFile(io, .{ .sub_path = "sub/c.png", .data = "x" });

    const root = try tmp.dir.realPathFileAlloc(io, ".", a);
    defer a.free(root);

    const paths = try scan(io, a, root);
    defer {
        for (paths) |p| a.free(p);
        a.free(paths);
    }

    try std.testing.expectEqual(@as(usize, 2), paths.len);
}
