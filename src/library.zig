const std = @import("std");
const Io = std.Io;
const scanner = @import("scanner.zig");
const photo_mod = @import("photo.zig");
const gallery = @import("gallery.zig");
const Photo = photo_mod.Photo;

/// 사진 목록을 소유하고, 지연 로딩/캐시 퇴출을 관리한다.
pub const Library = struct {
    allocator: std.mem.Allocator,
    photos: []Photo,

    /// 한 프레임에 새로 로드할 썸네일 최대 개수 (스크롤 끊김 방지).
    pub const loads_per_frame: usize = 8;

    /// 폴더를 스캔해 Photo 목록을 만든다. 경로는 raylib용 null 종료로 보관.
    pub fn init(io: Io, allocator: std.mem.Allocator, root: []const u8) !Library {
        const paths = try scanner.scan(io, allocator, root);
        defer {
            for (paths) |p| allocator.free(p);
            allocator.free(paths);
        }

        var photos = try allocator.alloc(Photo, paths.len);
        errdefer allocator.free(photos);

        var made: usize = 0;
        errdefer for (photos[0..made]) |*p| allocator.free(p.path);

        for (paths, 0..) |p, i| {
            photos[i] = .{ .path = try allocator.dupeZ(u8, p) };
            made += 1;
        }

        return .{ .allocator = allocator, .photos = photos };
    }

    pub fn deinit(self: *Library) void {
        for (self.photos) |*p| {
            p.unloadTexture();
            self.allocator.free(p.path);
        }
        self.allocator.free(self.photos);
    }

    pub fn count(self: *const Library) usize {
        return self.photos.len;
    }

    /// 보이는 범위 안에서 아직 안 올라온 썸네일을 프레임 예산만큼 로드한다.
    pub fn loadVisible(self: *Library, start: usize, end: usize) void {
        var budget: usize = loads_per_frame;
        var i = start;
        while (i < end and budget > 0) : (i += 1) {
            if (self.photos[i].state == .unloaded) {
                photo_mod.loadThumbnail(&self.photos[i], gallery.thumb_px);
                budget -= 1;
            }
        }
    }

    /// 보이는 범위에서 멀리 떨어진 텍스처를 GPU에서 내려 VRAM을 보호한다.
    /// keep 범위는 [start-margin, end+margin]로 잡는다.
    pub fn evictFarFrom(self: *Library, start: usize, end: usize, margin: usize) void {
        const lo = if (start > margin) start - margin else 0;
        const hi = @min(self.photos.len, end + margin);
        for (self.photos, 0..) |*p, i| {
            if (p.state == .loaded and (i < lo or i >= hi)) {
                p.unloadTexture();
            }
        }
    }
};
