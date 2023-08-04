
const std = @import("std");
const os = std.os;
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

const timerFd = os.timerfd_create;
const timerFdSetTime = os.timerfd_settime;
const TimeSpec = os.linux.timespec;
const ITimerSpec = os.linux.itimerspec;

const signalFd = os.signalfd;
//const sigProcMask = os.sigprocmask;
const SigSet = os.sigset_t;
const SIG = os.SIG;
const SigInfo = os.linux.signalfd_siginfo;

const fsysFd = os.inotify_init1;
const FsysEvent = os.linux.inotify_event;
const fsysAddWatch = os.inotify_add_watch;

const edsm = @import("edsm.zig");
const StageMachine = edsm.StageMachine;
const ecap = @import("event-capture.zig");
const Message = @import("message-queue.zig").Message;

pub const EventSource = struct {

    id: i32 = -1, // fd in most cases, but not always
    owner: *StageMachine,
    eq: *ecap.EventQueue,

    // "virtual method"
    getMessageCodeImpl: *const fn(es: *EventSource, event_mask: u32) anyerror!u8,
    pub fn getMessageCode(es: *EventSource, event_mask: u32) !u8 {
        return try es.getMessageCodeImpl(es, event_mask);
    }

    pub fn enable(es: *EventSource) !void {
        try es.eq.enableCanRead(es);
    }

    pub fn disable(es: *EventSource) !void {
        try es.eq.disableEventSource(es);
    }
};

pub const Signal = struct {
    es: EventSource,
    code: u8,
    info: SigInfo = undefined,

    pub fn init(sm: *StageMachine, signo: u6, code: u8) !Signal {
        return Signal {
            .es = .{
                .id = try getSignalId(signo),
                .owner = sm,
                .getMessageCodeImpl = &readInfo,
                .eq = sm.md.eq,
            },
            .code = code,
        };
    }

    fn getSignalId(signo: u6) !i32 {
        var sset: SigSet = os.empty_sigset;
        os.linux.sigaddset(&sset, signo);
        //sigProcMask(@intCast(c_int, SIG.BLOCK), &sset, null);
        _ = os.linux.sigprocmask(SIG.BLOCK, &sset, null);
        return signalFd(-1, &sset, 0);
    }

    fn readInfo(es: *EventSource, event_mask: u32) !u8 {
        // check event mask here...
        _ = event_mask;
        var self = @fieldParentPtr(Signal, "es", es);
        var p1 = &self.info;
        var p2: [*]u8 = @ptrCast(@alignCast(p1));
        _ = try os.read(es.id, p2[0..@sizeOf(SigInfo)]);
        return self.code;
    }
};

pub const Timer = struct {
    es: EventSource,
    code: u8,
    nexp: u64 = 0,

    pub fn init(sm: *StageMachine, code: u8) !Timer {
        return Timer {
            .es = .{
                .id = try timerFd(os.CLOCK.REALTIME, 0),
                .owner = sm,
                .getMessageCodeImpl = &readInfo,
                .eq = sm.md.eq,
            },
            .code = code,
        };
    }

    fn setValue(fd: i32, msec: u32) !void {
        const its = ITimerSpec {
            .it_interval = TimeSpec {
                .tv_sec = 0,
                .tv_nsec = 0,
            },
            .it_value = TimeSpec {
                .tv_sec = msec / 1000,
                .tv_nsec = (msec % 1000) * 1000 * 1000,
            },
        };
        try timerFdSetTime(fd, 0, &its, null);
    }

    pub fn start(tm: *Timer, msec: u32) !void {
        return try setValue(tm.es.id, msec);
    }

    pub fn stop(tm: *Timer) !void {
        return try setValue(tm.es.id, 0);
    }

    pub fn readInfo(es: *EventSource, event_mask: u32) !u8 {
        _ = event_mask;
        var self = @fieldParentPtr(Timer, "es", es);
        var p1 = &self.nexp;
        var p2: [*]u8 = @ptrCast(@alignCast(p1));
        var buf = p2[0..@sizeOf(u64)];
        _ = try os.read(es.id, buf[0..]);
        return self.code;
    }
};

pub const FileSystem = struct {
    es: EventSource,
    // const buf_len = 1024;
    buf: [1024]u8 = undefined,
    event: *FsysEvent = undefined, // points to .buf[0]
    fname: []u8 = undefined, // points to .buf[@sizeOf(FsysEvent)]

    pub fn init(sm: *StageMachine) !FileSystem {
        return FileSystem {
            .es = .{
                .id = try fsysFd(0),
                .owner = sm,
                .getMessageCodeImpl = &readInfo,
                .eq = sm.md.eq,
            },
        };
    }

    pub fn setupPointers(fs: *FileSystem) void {
        fs.event = @ptrCast(@alignCast(&fs.buf[0]));
        fs.fname = fs.buf[@sizeOf(FsysEvent)..];
    }

    // a little bit tricky function that reads
    // exactly *one* event from inotify system
    // regardless of weither it has file name or not
    fn readInfo(es: *EventSource, event_mask: u32) !u8 {
        _ = event_mask;
        var self = @fieldParentPtr(FileSystem, "es", es);
        @memset(self.buf[0..], 0);
        var len: usize = @sizeOf(FsysEvent);
        while (true) {
            const ret = os.system.read(es.id, &self.buf, len);
            if (os.system.getErrno(ret) == .SUCCESS) break;
            if (os.system.getErrno(ret) != .INVAL) unreachable;
            // EINVAL => buffer too small
            // increase len and try again
            len += @sizeOf(FsysEvent);
            // check len here
        }
        print("file system events = {b:0>32}\n", .{self.event.mask});
        const ctz: u8 = @ctz(self.event.mask);
        return Message.FROW | ctz;
    }

    pub fn addWatch(self: *FileSystem, path: []const u8, mask: u32) !void {
        var wd = try fsysAddWatch(self.es.id, path, mask);
        _ = wd;
    }
};

//    pub fn enableOut(self: *Self, eq: *ecap.EventQueue) !void {
//        if (self.kind != .io) unreachable;
//        try eq.enableCanWrite(self);
//    }
