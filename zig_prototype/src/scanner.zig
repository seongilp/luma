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

/// 한 폴더(디렉터리)에 속한 이미지 묶음. 사이드바 항목 1개에 대응.
pub const Group = struct {
    /// root 기준 상대 디렉터리 경로 ("" = root 직속). gpa 소유.
    rel: []u8,
    /// 해당 폴더 안 이미지들의 전체 경로. gpa 소유.
    paths: [][]u8,
};

fn lessThanGroup(_: void, a: Group, b: Group) bool {
    return std.mem.lessThan(u8, a.rel, b.rel);
}

/// 폴더를 재귀 스캔하되, 이미지를 **직속 디렉터리별로 묶어** 반환한다.
/// 결과는 상대 경로 사전순 정렬. 호출자가 전체를 해제해야 한다 (freeGroups 사용).
pub fn scanGrouped(io: Io, allocator: std.mem.Allocator, root: []const u8) ![]Group {
    var map = std.StringHashMap(std.ArrayList([]u8)).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |e| {
            allocator.free(e.key_ptr.*);
            for (e.value_ptr.items) |p| allocator.free(p);
            e.value_ptr.deinit(allocator);
        }
        map.deinit();
    }

    var dir = Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| {
        std.log.err("폴더 열기 실패 '{s}': {s}", .{ root, @errorName(err) });
        return err;
    };
    defer dir.close(io);

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (walker.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!isSupportedImage(entry.basename)) continue;

        const reldir = std.fs.path.dirname(entry.path) orelse "";
        const gop = try map.getOrPut(reldir);
        if (!gop.found_existing) {
            gop.key_ptr.* = try allocator.dupe(u8, reldir);
            gop.value_ptr.* = .empty;
        }
        const full = try std.fs.path.join(allocator, &.{ root, entry.path });
        try gop.value_ptr.append(allocator, full);
    }

    // 맵 → 정렬된 슬라이스로 옮긴다 (소유권 이전).
    var groups = try allocator.alloc(Group, map.count());
    var i: usize = 0;
    var it = map.iterator();
    while (it.next()) |e| {
        groups[i] = .{ .rel = e.key_ptr.*, .paths = try e.value_ptr.toOwnedSlice(allocator) };
        e.key_ptr.* = ""; // defer가 다시 free 못 하도록 비움
        i += 1;
    }
    std.mem.sort(Group, groups, {}, lessThanGroup);
    return groups;
}

pub fn freeGroups(allocator: std.mem.Allocator, groups: []Group) void {
    for (groups) |g| {
        allocator.free(g.rel);
        for (g.paths) |p| allocator.free(p);
        allocator.free(g.paths);
    }
    allocator.free(groups);
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
