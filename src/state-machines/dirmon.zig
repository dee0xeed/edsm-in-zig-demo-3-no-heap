
const std = @import("std");
const os = std.os;
const print = std.debug.print;

const mq = @import("../engine/message-queue.zig");
const MessageDispatcher = mq.MessageDispatcher;
const MessageQueue = mq.MessageQueue;
const Message = mq.Message;

const esrc = @import("../engine//event-sources.zig");
const EventSource = esrc.EventSource;
const Signal = esrc.Signal;
const Timer = esrc.Timer;
const FileSystem = esrc.FileSystem;

const edsm = @import("../engine/edsm.zig");
const StageMachine = edsm.StageMachine;
const Stage = StageMachine.Stage;
const util = @import("../util.zig");

pub const DirMon = struct {

    const M0_WORK = Message.M0;

    sm: StageMachine,
    sg0: Signal = undefined,
    sg1: Signal = undefined,
    fs0: FileSystem = undefined,
    dir: []const u8,

    pub fn init(md: *MessageDispatcher, dir: []const u8) DirMon {

        var ctor = Stage{.name = "INIT", .enter = &initEnter, .leave = null};
        var work = Stage{.name = "WORK", .enter = &workEnter, .leave = &workLeave};

        ctor.setReflex(0, Message.M0, .{.transition = 1});

        work.setReflex(4, Message.F00, .{.action = &workF00});
        work.setReflex(4, Message.F01, .{.action = &workF01});
        work.setReflex(4, Message.F02, .{.action = &workF02});
        work.setReflex(4, Message.F03, .{.action = &workF03});
        work.setReflex(4, Message.F04, .{.action = &workF04});
        work.setReflex(4, Message.F05, .{.action = &workF05});
        work.setReflex(4, Message.F06, .{.action = &workF06});
        work.setReflex(4, Message.F07, .{.action = &workF07});
        work.setReflex(4, Message.F08, .{.action = &workF08});
        work.setReflex(4, Message.F09, .{.action = &workF09});
        work.setReflex(4, Message.F10, .{.action = &workF10});
        work.setReflex(4, Message.F11, .{.action = &workF11});
        work.setReflex(4, Message.F12, .{.action = &workF12});
        work.setReflex(4, Message.F13, .{.action = &workF13});
        work.setReflex(4, Message.F14, .{.action = &workF14});
        work.setReflex(4, Message.F15, .{.action = &workF15});

        work.setReflex(2, Message.S0, .{.action = &workS0});
        work.setReflex(2, Message.S1, .{.action = &workS0});

        const sm = StageMachine.init (
            md, "DirMon",
            &.{ctor, work},
        );

        return DirMon {
            .sm = sm,
            .dir = dir,
        };
    }

    fn initEnter(sm: *StageMachine) void {
        var me = @fieldParentPtr(DirMon, "sm", sm);
        // NOTE: we can't do this in .init() since 
        // address of the machine is not known there yet
        me.sg0 = Signal.init(sm, os.SIG.INT, Message.S0) catch unreachable;
        me.sg1 = Signal.init(sm, os.SIG.TERM, Message.S1) catch unreachable;
        me.fs0 = FileSystem.init(sm) catch unreachable;
        me.fs0.setupPointers();
        print("sg0.id = {}, sg1.id = {}, fs0.id = {}\n", .{me.sg0.es.id, me.sg1.es.id, me.fs0.es.id});
        sm.msgTo(sm, M0_WORK, null);
    }

    fn workEnter(sm: *StageMachine) void {
        var me = @fieldParentPtr(DirMon, "sm", sm);
        const mask: u32 = 0xFFF; // get them all
        me.fs0.addWatch(me.dir, mask) catch unreachable;
        me.fs0.es.enable() catch unreachable;
        me.sg0.es.enable() catch unreachable;
        me.sg1.es.enable() catch unreachable;
    }

    fn workF00(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        if ((fs.event.mask & 0x40000000) == 0) {
            print("'{s}': accessed\n", .{fs.fname});
        } else {
            print("'{s}': accessed\n", .{me.dir});
        }
        es.enable() catch unreachable;
    }

    fn workF01(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        if ((fs.event.mask & 0x40000000) == 0) {
            print("'{s}': modifiled\n", .{fs.fname});
        } else {
            print("'{s}': modifiled\n", .{me.dir});
        }
        es.enable() catch unreachable;
    }

    fn workF02(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        if ((fs.event.mask & 0x40000000) == 0) {
            print("'{s}': metadata changed\n", .{fs.fname});
        } else {
            print("'{s}': metadata changed\n", .{me.dir});
        }
        es.enable() catch unreachable;
    }

    fn workF03(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        _ = me;
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        print("'{s}': closed (write)\n", .{fs.fname});
        es.enable() catch unreachable;
    }

    fn workF04(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);

        if ((fs.event.mask & 0x40000000) == 0) {
            print("'{s}': closed (read)\n", .{fs.fname});
        } else {
            print("'{s}': closed (read)\n", .{me.dir});
        }
        es.enable() catch unreachable;
    }

    fn workF05(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        if ((fs.event.mask & 0x40000000) == 0) {
            print("'{s}': opened\n", .{fs.fname});
        } else {
            print("'{s}': opened\n", .{me.dir});
        }
        es.enable() catch unreachable;
    }

    fn workF06(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        print("'{s}': moved from '{s}'\n", .{fs.fname, me.dir});
        es.enable() catch unreachable;
    }

    fn workF07(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        print("'{s}': moved to '{s}'\n", .{fs.fname, me.dir});
        es.enable() catch unreachable;
    }

    fn workF08(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        _ = me;
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        print("'{s}': created\n", .{fs.fname});
        es.enable() catch unreachable;
    }

    fn workF09(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        _ = me;
        var es = util.opaqPtrTo(dptr, *EventSource);
        var fs = @fieldParentPtr(FileSystem, "es", es);
        print("'{s}': deleted\n", .{fs.fname});
        es.enable() catch unreachable;
    }

    fn workF10(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
//        var fs = @fieldParentPtr(FileSystem, "es", es);
        print("'{s}': deleted\n", .{me.dir});
        es.enable() catch unreachable;
    }

    fn workF11(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        var es = util.opaqPtrTo(dptr, *EventSource);
//        var fs = @fieldParentPtr(FileSystem, "es", es);
        print("'{s}': moved somewhere\n", .{me.dir});
        es.enable() catch unreachable;
    }

    // unused
    fn workF12(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = sm;
        _ = src;
        _ = dptr;
    }

    fn workF13(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = sm;
        _ = src;
        _ = dptr;
        print("unmounted\n", .{});
    }

    fn workF14(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        _ = me;
        var es = util.opaqPtrTo(dptr, *EventSource);
  //      var fs = @fieldParentPtr(FileSystem, "es", es);
        print("event queue overflow occured\n", .{});
        es.enable() catch unreachable;
    }

    fn workF15(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        _ = dptr;
        var me = @fieldParentPtr(DirMon, "sm", sm);
        print("'{s}': ignored\n", .{me.dir});
        os.raise(os.SIG.TERM) catch unreachable;
    }

    fn workS0(sm: *StageMachine, src: ?*StageMachine, dptr: ?*anyopaque) void {
        _ = src;
        var es = util.opaqPtrTo(dptr, *EventSource);
        var sg = @fieldParentPtr(Signal, "es", es);
        print("got signal #{} from PID {}\n", .{sg.info.signo, sg.info.pid});
        sm.msgTo(null, Message.M0, null);
    }

    fn workLeave(sm: *StageMachine) void {
        var me = @fieldParentPtr(DirMon, "sm", sm);
        me.fs0.es.disable() catch unreachable;
        print("Bye!\n", .{});
    }
};
