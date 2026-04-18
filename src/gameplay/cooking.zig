/// Cooking system: smoker, blast furnace, campfire.
const std = @import("std");

pub const CookingMethod = enum {
    smoker,
    blast_furnace,
    campfire,
};

pub const CookingDef = struct {
    name: []const u8,
    speed_multiplier: f32,
    xp_multiplier: f32,
};

pub fn getCookingDef(method: CookingMethod) CookingDef {
    return switch (method) {
        .smoker => .{ .name = "Smoker", .speed_multiplier = 2.0, .xp_multiplier = 1.0 },
        .blast_furnace => .{ .name = "Blast Furnace", .speed_multiplier = 2.0, .xp_multiplier = 1.0 },
        .campfire => .{ .name = "Campfire", .speed_multiplier = 0.33, .xp_multiplier = 1.0 },
    };
}

pub const CookingState = struct {
    method: CookingMethod,
    progress: f32,
    cook_time: f32,
    active: bool,

    pub fn init(method: CookingMethod) CookingState {
        return .{
            .method = method,
            .progress = 0.0,
            .cook_time = 10.0,
            .active = false,
        };
    }

    pub fn update(self: *CookingState, dt: f32) bool {
        if (!self.active) return false;
        const def = getCookingDef(self.method);
        self.progress += dt * def.speed_multiplier;
        if (self.progress >= self.cook_time) {
            self.progress = 0.0;
            self.active = false;
            return true; // item cooked
        }
        return false;
    }

    pub fn start(self: *CookingState) void {
        self.progress = 0.0;
        self.active = true;
    }
};

test "smoker cooks at 2x speed" {
    const def = getCookingDef(.smoker);
    try std.testing.expectEqual(@as(f32, 2.0), def.speed_multiplier);
}

test "campfire cooks slowly" {
    const def = getCookingDef(.campfire);
    try std.testing.expect(def.speed_multiplier < 1.0);
}

test "cooking state update" {
    var state = CookingState.init(.blast_furnace);
    state.start();
    try std.testing.expect(state.active);
    // Blast furnace at 2x speed, 10s cook time => 5s effective
    const done = state.update(5.1);
    try std.testing.expect(done);
    try std.testing.expect(!state.active);
}
