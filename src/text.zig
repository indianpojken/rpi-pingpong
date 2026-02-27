const rl = @import("raylib");

inline fn enumToFloat(value: anytype) f32 {
    return @floatFromInt(@intFromEnum(value));
}

pub const Text = struct {
    const String = [:0]const u8;

    const VerticalAlignment = enum(u8) {
        top = 0,
        middle = 1,
        bottom = 2,
    };

    const HorizontalAlignment = enum(u8) {
        left = 0,
        center = 1,
        right = 2,
    };

    const Options = struct {
        font_size: i32,
        font_color: u32 = 0xfefefaff,

        vertical_alignment: VerticalAlignment = .top,
        horizontal_alignment: HorizontalAlignment = .left,
    };

    // taken from the RayLib example - https://www.raylib.com/examples/text/loader.html?name=text_words_alignment
    fn getPositionByAlignment(
        text: String,
        rectangle: rl.Rectangle,
        options: Options,
    ) rl.Vector2 {
        const text_width: f32 = @floatFromInt(rl.measureText(text, options.font_size));

        const position: rl.Vector2 = .{
            .x = rl.math.lerp(
                0.0,
                rectangle.width - text_width,
                enumToFloat(options.horizontal_alignment) * 0.5,
            ),

            .y = rl.math.lerp(
                0.0,
                rectangle.height - @as(f32, @floatFromInt(options.font_size)),
                enumToFloat(options.vertical_alignment) * 0.5,
            ),
        };

        return position;
    }

    pub fn drawTextRectangle(
        text: String,
        rectangle: rl.Rectangle,
        options: Options,
    ) void {
        const aligned_position = getPositionByAlignment(text, rectangle, options);
        const color = rl.Color.fromInt(options.font_color);

        rl.drawText(
            text,
            @intFromFloat(rectangle.x + aligned_position.x),
            @intFromFloat(rectangle.y + aligned_position.y),
            options.font_size,
            color,
        );
    }
};
