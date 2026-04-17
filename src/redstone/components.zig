/// Redstone component behaviors.
/// Each component type defines how it interacts with the redstone signal system.
const std = @import("std");

pub const ComponentType = enum {
    wire,
    torch,
    lever,
    button,
    repeater,
    piston,
};

pub const Component = struct {
    comp_type: ComponentType,
    x: u4,
    y: u4,
    z: u4,
    facing: u3,
    active: bool,
    delay: u8,

    /// Create a new component with default orientation (facing north), inactive,
    /// and a delay appropriate for the component type.
    pub fn init(comp_type: ComponentType, x: u4, y: u4, z: u4) Component {
        return .{
            .comp_type = comp_type,
            .x = x,
            .y = y,
            .z = z,
            .facing = 0,
            .active = false,
            .delay = switch (comp_type) {
                .repeater => 1,
                else => 0,
            },
        };
    }

    /// Toggle the active state. Only meaningful for levers and buttons.
    pub fn toggle(self: *Component) void {
        switch (self.comp_type) {
            .lever, .button => {
                self.active = !self.active;
            },
            else => {},
        }
    }

    /// Return the output power level for this component given an input power level.
    /// Torches always output 15 (inverted: output when input is 0, but we treat
    /// a standalone torch as a constant source here).
    /// Levers/buttons output 15 when active, 0 when inactive.
    /// Wire passes through with 1-level decay (min 0).
    /// Repeaters restore signal to 15 when input > 0, else 0.
    /// Pistons do not output power.
    pub fn getOutputPower(self: *const Component, input_power: u4) u4 {
        return switch (self.comp_type) {
            .torch => 15,
            .lever, .button => if (self.active) 15 else 0,
            .wire => if (input_power > 0) input_power - 1 else 0,
            .repeater => if (input_power > 0) 15 else 0,
            .piston => 0,
        };
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "component init defaults" {
    const wire = Component.init(.wire, 1, 2, 3);
    try std.testing.expectEqual(ComponentType.wire, wire.comp_type);
    try std.testing.expectEqual(@as(u4, 1), wire.x);
    try std.testing.expectEqual(@as(u4, 2), wire.y);
    try std.testing.expectEqual(@as(u4, 3), wire.z);
    try std.testing.expectEqual(@as(u3, 0), wire.facing);
    try std.testing.expect(!wire.active);
    try std.testing.expectEqual(@as(u8, 0), wire.delay);
}

test "repeater init has delay 1" {
    const rep = Component.init(.repeater, 0, 0, 0);
    try std.testing.expectEqual(@as(u8, 1), rep.delay);
}

test "lever toggle changes active state" {
    var lever = Component.init(.lever, 5, 5, 5);
    try std.testing.expect(!lever.active);
    lever.toggle();
    try std.testing.expect(lever.active);
    lever.toggle();
    try std.testing.expect(!lever.active);
}

test "button toggle changes active state" {
    var button = Component.init(.button, 0, 0, 0);
    try std.testing.expect(!button.active);
    button.toggle();
    try std.testing.expect(button.active);
}

test "toggle on non-toggleable component is no-op" {
    var wire = Component.init(.wire, 0, 0, 0);
    wire.toggle();
    try std.testing.expect(!wire.active);
}

test "torch outputs power 15 regardless of input" {
    const torch = Component.init(.torch, 0, 0, 0);
    try std.testing.expectEqual(@as(u4, 15), torch.getOutputPower(0));
    try std.testing.expectEqual(@as(u4, 15), torch.getOutputPower(15));
    try std.testing.expectEqual(@as(u4, 15), torch.getOutputPower(7));
}

test "lever outputs 15 when active, 0 when inactive" {
    var lever = Component.init(.lever, 0, 0, 0);
    try std.testing.expectEqual(@as(u4, 0), lever.getOutputPower(0));
    lever.toggle();
    try std.testing.expectEqual(@as(u4, 15), lever.getOutputPower(0));
}

test "wire decays signal by 1" {
    const wire = Component.init(.wire, 0, 0, 0);
    try std.testing.expectEqual(@as(u4, 14), wire.getOutputPower(15));
    try std.testing.expectEqual(@as(u4, 0), wire.getOutputPower(1));
    try std.testing.expectEqual(@as(u4, 0), wire.getOutputPower(0));
}

test "repeater restores signal to 15" {
    const rep = Component.init(.repeater, 0, 0, 0);
    try std.testing.expectEqual(@as(u4, 15), rep.getOutputPower(1));
    try std.testing.expectEqual(@as(u4, 15), rep.getOutputPower(7));
    try std.testing.expectEqual(@as(u4, 0), rep.getOutputPower(0));
}

test "piston outputs no power" {
    const piston = Component.init(.piston, 0, 0, 0);
    try std.testing.expectEqual(@as(u4, 0), piston.getOutputPower(15));
    try std.testing.expectEqual(@as(u4, 0), piston.getOutputPower(0));
}
