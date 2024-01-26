const std = @import("std");

fn sisd_parse_unsigned(data: []const u8) i64 {
    var res: i64 = 0;
    for (data) |e| {
        res *= 10;
        res += @as(i64, e) - @as(i64, '0');
    }
    return res;
}

inline fn sisd_parse(data: []const u8) i64 {
    if (data[0] == '-') return -sisd_parse_unsigned(data[1..]);
    return sisd_parse_unsigned(data);
}

export fn sisd_parse_exp(data: [*]const u8, n: usize) i64 {
    return sisd_parse(data[0..n]);
}

test "sisd parsing" {
    try std.testing.expectEqual(@as(i64, 213), sisd_parse("213"));
    try std.testing.expectEqual(@as(i64, -213), sisd_parse("-213"));
}

fn simd_parse_unsigned(data: []const u8) i64 {
    const vec_size = 8;
    const vec = @Vector(vec_size, u8);
    const sub: vec = @splat('0');

    var a = data;
    var acc: @Vector(vec_size, i64) = @splat(0);

    var temp: [vec_size]i64 = undefined;
    var mul_after: i64 = 1;
    for (0..vec_size) |i| {
        temp[vec_size - i - 1] = mul_after;
        mul_after *= 10;
    }

    const mul: @Vector(vec_size, i64) = temp;
    if (a.len >= vec_size) {
        const cur: vec = a[0..vec_size].*;
        acc += (cur - sub) * mul;
        a = a[vec_size..];
    }
    if (a.len >= vec_size) {
        const cur: vec = a[0..vec_size].*;
        acc *= @splat(mul_after);
        acc += (cur - sub) * mul;
        a = a[vec_size..];
    }

    var res: i64 = @reduce(.Add, acc);
    for (a) |e| {
        res *= 10;
        res += @as(i64, e) - @as(i64, '0');
    }
    return res;
}

inline fn simd_parse(data: []const u8) i64 {
    if (data[0] == '-') return -simd_parse_unsigned(data[1..]);
    return simd_parse_unsigned(data);
}

test "simd parsing" {
    try std.testing.expectEqual(@as(i64, 213), simd_parse("213"));
    try std.testing.expectEqual(@as(i64, -213), simd_parse("-213"));

    try std.testing.expectEqual(@as(i64, 1234567812345678), simd_parse("1234567812345678"));
    try std.testing.expectEqual(@as(i64, -1234567812345678), simd_parse("-1234567812345678"));
}

export fn simd_parse_exp(data: [*]u8, n: usize) i64 {
    return simd_parse_unsigned(data[0..n]);
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    defer bw.flush() catch unreachable;

    var buf: [1 << 20]u8 = undefined;
    var lengths: [(1 << 20) / 20]usize = undefined;
    var bufs: [(1 << 20) / 20]([]u8) = undefined;
    {
        var state: usize = 1237211;
        for (0..(1 << 20)) |i| {
            state +%= 7;
            state *%= 31;
            buf[i] = @intCast(@as(usize, '0') + state % 10);
        }
        for (0..(1 << 20) / 20) |i| {
            bufs[i] = buf[(20 * i)..(20 * i + 20)];
            state +%= 7;
            state *%= 31;
            lengths[i] = 1 + state % 17;
            lengths[i] = 16;
        }
    }

    {
        var timer = try std.time.Timer.start();
        var sum: i64 = 0.0;
        for (0..(1 << 10)) |_| {
            for (bufs, lengths) |b, n| {
                sum +%= sisd_parse(b[0..n]);
            }
        }
        const elapsed = timer.read();
        try stdout.print("sisd parse {}\n", .{sum});
        try stdout.print("{}ms\n", .{elapsed / 1000000});
    }
    {
        var timer = try std.time.Timer.start();
        var sum: i64 = 0.0;
        for (0..(1 << 10)) |_| {
            for (bufs, lengths) |b, n| {
                sum +%= simd_parse(b[0..n]);
            }
        }
        const elapsed = timer.read();
        try stdout.print("simd parse {}\n", .{sum});
        try stdout.print("{}ms\n", .{elapsed / 1000000});
    }
}
