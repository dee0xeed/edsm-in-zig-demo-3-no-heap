
const std = @import("std");
const mem = std.mem;
const os = std.os;
const mque = @import("engine/message-queue.zig");
const eque = @import("engine/event-capture.zig");
const DirMon = @import("state-machines/dirmon.zig").DirMon;

fn help() void {
    std.debug.print("Usage\n", .{});
    std.debug.print("{s} <directory-to-monitor>\n", .{std.os.argv[0]});
}

pub fn main() !void {

    if (2 != std.os.argv.len) {
        help();
        return;
    }

    var mq = mque.MessageQueue{};
    var eq = try eque.EventQueue.init(&mq);
    var md = mque.MessageDispatcher.init(&mq, &eq);
    var dm = DirMon.init(&md, mem.sliceTo(os.argv[1], 0));
    try dm.sm.run();

    try md.loop();
    md.eq.fini();
}
