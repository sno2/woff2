const std = @import("std");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    defer _ = arena_state.deinit();

    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    const compress_path, const decompress_path, const info_path, const ttf_path = args[1..][0..4].*;

    {
        var run_compress = std.process.Child.init(&.{ compress_path, ttf_path }, arena);
        run_compress.stderr_behavior = .Inherit;
        run_compress.stdout_behavior = .Inherit;
        const term = try run_compress.spawnAndWait();
        if (term != .Exited or term.Exited != 0) {
            std.process.fatal("compress failed for {s}", .{ttf_path});
        }
    }

    {
        const woff2_path = try std.fmt.allocPrint(arena, "{s}.woff2", .{ttf_path[0 .. ttf_path.len - ".ttf".len]});

        var run_info = std.process.Child.init(&.{ info_path, woff2_path }, arena);
        try run_info.spawn();

        var run_decompress = std.process.Child.init(&.{ decompress_path, woff2_path }, arena);
        try run_decompress.spawn();

        const info_term = try run_info.wait();
        if (info_term != .Exited or info_term.Exited != 0) {
            std.process.fatal("info failed for {s}", .{woff2_path});
        }

        const decompress_term = try run_decompress.wait();
        if (decompress_term != .Exited or decompress_term.Exited != 0) {
            std.process.fatal("decompress failed for {s}", .{woff2_path});
        }
    }
}
