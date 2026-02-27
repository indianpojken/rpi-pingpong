const std = @import("std");
const time = std.time;

const gpio = @import("gpio");

fn Debouncer(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        unstable_value: T,

        timer: time.Timer,
        duration_ms: u64 = 0,

        threshold_ms: u8,

        fn init(value: T, threshold_ms: u8) !Self {
            return .{
                .value = value,
                .unstable_value = value,
                .timer = try time.Timer.start(),
                .threshold_ms = threshold_ms,
            };
        }

        fn set(self: *Self, value: T) void {
            if (self.unstable_value != value) {
                self.reset();
            }

            if (self.duration_ms >= self.threshold_ms) {
                self.value = self.unstable_value;
                self.reset();
            }

            if (self.value == self.unstable_value and
                self.unstable_value == value)
            {
                self.reset();
            }

            self.unstable_value = value;
            self.sync();
        }

        fn sync(self: *Self) void {
            self.duration_ms += self.timer.read() / time.ns_per_ms;
        }

        fn reset(self: *Self) void {
            self.duration_ms = 0;
            self.timer.reset();
        }
    };
}

const Button = struct {
    line: gpio.Line,

    activated: Debouncer(bool),

    state: State = .idle,
    event: ?Event = null,
    previous_event: ?Event = null,

    press_timer: std.time.Timer,
    hold_timer: ?std.time.Timer = null,

    const State = enum {
        idle,
        active,
    };

    const Event = enum {
        pressed,
        held,
        released,
    };

    const debounce_threshold_ms = 5; // QMK default - https://docs.qmk.fm/feature_debounce_type#supported-debounce-algorithms
    const tap_period_ms = 200; // QMK default - https://docs.qmk.fm/tap_hold#tapping-term

    fn init(chip: *gpio.Chip, pin: u8) !Button {
        const line_options: gpio.uapi.LineFlags = .{
            .input = true,
            .active_low = true,
            .bias_pull_up = true,
        };

        const line = try chip.requestLine(pin, line_options);

        return .{
            .activated = try Debouncer(bool).init(false, debounce_threshold_ms),

            .line = line,
            .state = .idle,

            .press_timer = try std.time.Timer.start(),
        };
    }

    fn deinit(self: *Button) void {
        self.line.close();
    }

    fn setEvent(self: *Button, event: Event) void {
        self.previous_event = self.event;
        self.event = event;
    }

    fn process(self: *Button) !void {
        self.activated.set(try self.line.getValue());

        if (self.activated.value) {
            switch (self.state) {
                .idle => {
                    self.state = .active;
                    self.setEvent(.pressed);
                    self.press_timer.reset();
                },
                .active => {
                    const since_press_ms = self.press_timer.read() / std.time.ns_per_ms;

                    if (since_press_ms >= tap_period_ms) {
                        self.setEvent(.held);
                        if (self.hold_timer == null) self.hold_timer = try std.time.Timer.start();
                    }
                },
            }
        } else {
            switch (self.state) {
                .idle => {
                    self.event = null;
                },
                .active => {
                    self.state = .idle;
                    self.setEvent(.released);
                    self.hold_timer = null;
                },
            }
        }
    }

    fn holdDurationMs(self: *Button) u64 {
        return if (self.hold_timer) |*timer| timer.read() / std.time.ns_per_ms else 0;
    }

    pub fn resetHoldDuration(self: *Button) void {
        if (self.hold_timer) |*timer| timer.reset();
    }
};

fn Descriptor(comptime Action: type) type {
    return struct {
        action: Action,
        pin: u8,
    };
}

fn EventQueue(comptime Event: type) type {
    return struct {
        const Self = @This();

        items: [15]Event = undefined,
        count: usize = 0,

        fn push(self: *Self, event: Event) void {
            if (self.count < self.items.len) {
                self.items[self.count] = event;
                self.count += 1;
            }
        }

        pub fn next(self: *Self) ?Event {
            if (self.count == 0) return null;

            self.count -= 1;
            return self.items[self.count];
        }
    };
}

pub fn Input(
    comptime Action: type,
    comptime descriptors: []const Descriptor(Action),
) type {
    return struct {
        chip: gpio.Chip,
        items: [descriptors.len]Item,
        events: EventQueue(Event),

        const Self = @This();

        const Item = struct {
            id: Action,
            button: Button,
        };

        const Device = struct {
            chip: []const u8,
            consumer: []const u8,
        };

        const Event = union(enum) {
            pressed: struct { action: Action, button: *Button },
            released: struct { action: Action, button: *Button },
            held: struct { action: Action, button: *Button, duration_ms: u64 },
            tapped: struct { action: Action, button: *Button },
        };

        pub fn init(device: Device) !Self {
            var chip = try gpio.getChip(device.chip);
            try chip.setConsumer(device.consumer);

            var items: [descriptors.len]Item = undefined;

            for (descriptors, 0..) |descriptor, index| {
                items[index] = .{
                    .id = descriptor.action,
                    .button = try Button.init(&chip, descriptor.pin),
                };
            }

            return .{
                .chip = chip,
                .items = items,
                .events = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.chip.close();
        }

        pub fn poll(self: *Self) !void {
            for (&self.items) |*item| {
                try item.button.process();
                if (item.button.event == null) continue;

                switch (item.button.event.?) {
                    .pressed => self.events.push(.{
                        .pressed = .{ .action = item.id, .button = &item.button },
                    }),
                    .released => {
                        const event = if (item.button.previous_event != .held)
                            Event{ .tapped = .{ .action = item.id, .button = &item.button } }
                        else
                            Event{ .released = .{ .action = item.id, .button = &item.button } };

                        self.events.push(event);
                    },
                    .held => self.events.push(.{
                        .held = .{
                            .action = item.id,
                            .button = &item.button,
                            .duration_ms = item.button.holdDurationMs(),
                        },
                    }),
                }
            }
        }
    };
}
