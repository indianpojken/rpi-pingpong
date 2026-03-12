const rl = @import("raylib");

const Text = @import("text.zig").Text;

pub const Score = struct {
    points: u8 = 0,
    sets: u8 = 0,

    fn increasePoints(self: *Score) void {
        self.points +|= 1;
    }

    fn decreasePoints(self: *Score) void {
        self.points -|= 1;
    }

    fn resetPoints(self: *Score) void {
        self.points = 0;
    }

    fn increaseSets(self: *Score) void {
        self.sets +|= 1;
        self.points = 0;
    }

    fn decreaseSets(self: *Score) void {
        self.sets -|= 1;
        self.points = 0;
    }

    fn resetSets(self: *Score) void {
        self.sets = 0;
    }

    fn reset(self: *Score) void {
        self.resetPoints();
        self.resetSets();
    }
};

pub const Scoreboard = struct {
    scores: [2]Score,
    rectangle: rl.Rectangle,

    font_size: f32,

    const font_color = rl.Color.fromInt(0xfefefaff);

    pub const Player = enum {
        p1,
        p2,

        pub fn opponent(self: Player) Player {
            return if (self == .p1) .p2 else .p1;
        }
    };

    pub fn init(rectangle: rl.Rectangle) Scoreboard {
        return .{
            .scores = [_]Score{ Score{}, Score{} },
            .rectangle = rectangle,
            .font_size = rectangle.height * 0.3,
        };
    }

    pub fn resetPoints(self: *Scoreboard) void {
        for (&self.scores) |*scr| scr.resetPoints();
    }

    pub fn reset(self: *Scoreboard) void {
        for (&self.scores) |*scr| scr.reset();
    }

    pub fn score(self: *Scoreboard, player: Player) *Score {
        return &self.scores[@intFromEnum(player)];
    }

    pub fn decreaseSets(self: *Scoreboard, player: Scoreboard.Player) void {
        self.score(player).decreaseSets();
        self.score(player.opponent()).resetPoints();
    }

    pub fn increaseSets(self: *Scoreboard, player: Scoreboard.Player) void {
        self.score(player).increaseSets();
        self.score(player.opponent()).resetPoints();
    }

    pub fn decreasePoints(self: *Scoreboard, player: Scoreboard.Player) void {
        self.score(player).decreasePoints();
    }

    pub fn increasePoints(self: *Scoreboard, player: Scoreboard.Player) void {
        self.score(player).increasePoints();
    }

    pub fn render(self: *const Scoreboard) void {
        const width: f32 = self.rectangle.width / self.scores.len;
        const height: f32 = self.rectangle.height / 2;

        Text.drawTextRectangle(
            "vs",
            .{
                .height = self.rectangle.height,
                .width = self.rectangle.width,
                .x = 0,
                .y = (self.font_size * 0.6) / 2,
            },
            .{
                .font_size = @intFromFloat((self.font_size / 2) + 10),
                .horizontal_alignment = .center,
                .vertical_alignment = .middle,
            },
        );

        const margin_y = self.font_size / 2;

        for (self.scores, 0..) |scr, index| {
            const x: f32 = width * @as(f32, @floatFromInt(index));

            Text.drawTextRectangle(
                rl.textFormat("%d", .{scr.points}),
                .{ .height = height, .width = width, .x = x, .y = margin_y },
                .{
                    .font_size = @intFromFloat(self.font_size),
                    .horizontal_alignment = .center,
                    .vertical_alignment = .bottom,
                },
            );

            Text.drawTextRectangle(
                rl.textFormat("%d", .{scr.sets}),
                .{ .height = height, .width = width, .x = x, .y = height + margin_y },
                .{
                    .font_size = @intFromFloat(self.font_size * 0.5),
                    .horizontal_alignment = .center,
                    .vertical_alignment = .top,
                },
            );
        }
    }
};
