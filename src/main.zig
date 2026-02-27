const std = @import("std");
const rl = @import("raylib");
const time = std.time;

const Scoreboard = @import("scoreboard.zig").Scoreboard;
const Input = @import("input.zig").Input;

const window = .{
    .title = "Ping-Pong",
    .resolution = .{ .width = 1280, .height = 720 },
    .fps = 60,
};

const Action = enum {
    p1_dec,
    p1_inc,
    p2_dec,
    p2_inc,
    reset,
};

pub fn main() !void {
    rl.initWindow(
        window.resolution.width,
        window.resolution.height,
        window.title,
    );
    defer rl.closeWindow();

    rl.setTargetFPS(window.fps);

    var input = try Input(Action, &.{
        .{ .action = .p1_dec, .pin = 22 },
        .{ .action = .p1_inc, .pin = 17 },
        .{ .action = .p2_dec, .pin = 3 },
        .{ .action = .p2_inc, .pin = 2 },
        .{ .action = .reset, .pin = 4 },
    }).init(.{
        .chip = "/dev/gpiochip0",
        .consumer = window.title,
    });
    defer input.deinit();

    var scoreboard = Scoreboard.init(.{
        .width = window.resolution.width,
        .height = window.resolution.height,
        .x = 0,
        .y = 0,
    });

    while (!rl.windowShouldClose()) {
        // Update
        try input.poll();

        while (input.events.next()) |event| handleEvent(event, &scoreboard);
        if (rl.isKeyPressed(.escape)) rl.closeWindow();

        // Render
        rl.beginDrawing();
        defer rl.endDrawing();

        scoreboard.render();
        rl.clearBackground(rl.Color.fromInt(0x0d0907));
    }
}

fn handleEvent(event: anytype, scoreboard: *Scoreboard) void {
    switch (event) {
        .tapped => |e| handleTap(e, scoreboard),
        .held => |e| handleHold(e, scoreboard),
        else => {},
    }
}

fn handleTap(event: anytype, scoreboard: *Scoreboard) void {
    switch (event.action) {
        .p1_dec => scoreboard.decreasePoints(.p1),
        .p1_inc => scoreboard.increasePoints(.p1),

        .p2_dec => scoreboard.decreasePoints(.p2),
        .p2_inc => scoreboard.increasePoints(.p2),

        .reset => scoreboard.reset(),
    }
}

fn handleHold(event: anytype, scoreboard: *Scoreboard) void {
    const required_ms_hold = 1500;

    if (event.duration_ms < required_ms_hold) return;

    switch (event.action) {
        .p1_dec => scoreboard.decreaseSets(.p1),
        .p1_inc => scoreboard.increaseSets(.p1),

        .p2_dec => scoreboard.decreaseSets(.p2),
        .p2_inc => scoreboard.increaseSets(.p2),

        else => {},
    }

    event.button.resetHoldDuration();
}
