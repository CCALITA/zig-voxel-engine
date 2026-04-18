/// Music disc, jukebox, and note block system.
/// Provides disc definitions with duration/item-id lookup, a jukebox state
/// machine that tracks insertion/ejection/play-timer, and a note block that
/// selects instrument by the block below and cycles pitch 0-24.

const std = @import("std");

// ──────────────────────────────────────────────────────────────────────────────
// Block constants (mirrored from world/block.zig to avoid cross-module import)
// ──────────────────────────────────────────────────────────────────────────────

const BlockId = u8;

const STONE: BlockId = 1;
const DIRT: BlockId = 2;
const OAK_PLANKS: BlockId = 5;
const SAND: BlockId = 6;
const OAK_LOG: BlockId = 8;
const GOLD_ORE: BlockId = 14;
const GLASS: BlockId = 17;
const ICE: BlockId = 23;
const CLAY: BlockId = 25;

// ──────────────────────────────────────────────────────────────────────────────
// Music Discs
// ──────────────────────────────────────────────────────────────────────────────

pub const DiscType = enum {
    disc_13,
    cat,
    blocks,
    chirp,
    far,
    mall,
    mellohi,
    stal,
    strad,
    ward,
    disc_11,
    wait,
    pigstep,
};

pub const DiscDef = struct {
    name: []const u8,
    duration_seconds: f32,
    item_id: u16,
};

/// Non-block item IDs for music discs (starting at 400 to avoid collision).
const DISC_ITEM_BASE: u16 = 400;

/// Returns the definition for a given disc type.
pub fn getDiscDef(disc: DiscType) DiscDef {
    return switch (disc) {
        .disc_13 => .{ .name = "13", .duration_seconds = 178.0, .item_id = DISC_ITEM_BASE },
        .cat => .{ .name = "cat", .duration_seconds = 185.0, .item_id = DISC_ITEM_BASE + 1 },
        .blocks => .{ .name = "blocks", .duration_seconds = 345.0, .item_id = DISC_ITEM_BASE + 2 },
        .chirp => .{ .name = "chirp", .duration_seconds = 185.0, .item_id = DISC_ITEM_BASE + 3 },
        .far => .{ .name = "far", .duration_seconds = 174.0, .item_id = DISC_ITEM_BASE + 4 },
        .mall => .{ .name = "mall", .duration_seconds = 197.0, .item_id = DISC_ITEM_BASE + 5 },
        .mellohi => .{ .name = "mellohi", .duration_seconds = 96.0, .item_id = DISC_ITEM_BASE + 6 },
        .stal => .{ .name = "stal", .duration_seconds = 150.0, .item_id = DISC_ITEM_BASE + 7 },
        .strad => .{ .name = "strad", .duration_seconds = 188.0, .item_id = DISC_ITEM_BASE + 8 },
        .ward => .{ .name = "ward", .duration_seconds = 251.0, .item_id = DISC_ITEM_BASE + 9 },
        .disc_11 => .{ .name = "11", .duration_seconds = 71.0, .item_id = DISC_ITEM_BASE + 10 },
        .wait => .{ .name = "wait", .duration_seconds = 238.0, .item_id = DISC_ITEM_BASE + 11 },
        .pigstep => .{ .name = "Pigstep", .duration_seconds = 149.0, .item_id = DISC_ITEM_BASE + 12 },
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Jukebox
// ──────────────────────────────────────────────────────────────────────────────

pub const JukeboxState = struct {
    current_disc: ?DiscType,
    play_timer: f32,
    playing: bool,

    pub fn init() JukeboxState {
        return .{
            .current_disc = null,
            .play_timer = 0.0,
            .playing = false,
        };
    }

    /// Insert a disc into the jukebox. If a disc is already present it is
    /// ejected first and returned. The new disc begins playing immediately.
    pub fn insertDisc(self: *JukeboxState, disc: DiscType) ?DiscType {
        const ejected = self.current_disc;
        self.current_disc = disc;
        self.play_timer = 0.0;
        self.playing = true;
        return ejected;
    }

    /// Eject the current disc. Returns the disc that was removed, or null if
    /// the jukebox was empty.
    pub fn ejectDisc(self: *JukeboxState) ?DiscType {
        const ejected = self.current_disc;
        self.current_disc = null;
        self.play_timer = 0.0;
        self.playing = false;
        return ejected;
    }

    /// Advance the play timer by `dt` seconds. Stops playback when the disc
    /// duration has elapsed.
    pub fn update(self: *JukeboxState, dt: f32) void {
        if (!self.playing) return;
        if (self.current_disc) |disc| {
            self.play_timer += dt;
            if (self.play_timer >= getDiscDef(disc).duration_seconds) {
                self.playing = false;
            }
        }
    }

    /// Returns true when a disc is actively playing.
    pub fn isPlaying(self: *const JukeboxState) bool {
        return self.playing;
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Note Block
// ──────────────────────────────────────────────────────────────────────────────

pub const Instrument = enum {
    piano,
    bass_guitar,
    bass_drum,
    snare,
    hat,
    bell,
    flute,
    chime,
    guitar,
    xylophone,
};

pub const NoteEvent = struct {
    pitch: u5,
    instrument: Instrument,
};

pub const NoteBlockState = struct {
    pitch: u5,
    instrument: Instrument,

    pub fn init() NoteBlockState {
        return .{
            .pitch = 0,
            .instrument = .piano,
        };
    }

    /// Set the instrument based on the block directly below the note block.
    pub fn setInstrumentFromBlock(self: *NoteBlockState, block_below: BlockId) void {
        self.instrument = instrumentForBlock(block_below);
    }

    /// Play the note block, returning the note event.
    pub fn play(self: *const NoteBlockState) NoteEvent {
        return .{
            .pitch = self.pitch,
            .instrument = self.instrument,
        };
    }

    /// Increment pitch by 1, wrapping around at 25 (0-24 range).
    pub fn tunePitch(self: *NoteBlockState) void {
        self.pitch = if (self.pitch >= 24) 0 else self.pitch + 1;
    }
};

/// Determine the instrument from the block type below the note block.
pub fn instrumentForBlock(block_id: BlockId) Instrument {
    return switch (block_id) {
        OAK_PLANKS, OAK_LOG => .bass_guitar, // wood family
        STONE => .bass_drum,
        SAND => .snare,
        GLASS => .hat,
        DIRT => .piano,
        GOLD_ORE => .bell, // gold family
        CLAY => .flute,
        ICE => .chime,
        else => .piano,
    };
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

test "getDiscDef returns correct definition for each disc" {
    const cat_def = getDiscDef(.cat);
    try std.testing.expectEqualStrings("cat", cat_def.name);
    try std.testing.expectApproxEqAbs(@as(f32, 185.0), cat_def.duration_seconds, 0.001);
    try std.testing.expectEqual(@as(u16, DISC_ITEM_BASE + 1), cat_def.item_id);
}

test "all discs have unique item IDs and positive duration" {
    const all = [_]DiscType{
        .disc_13, .cat,    .blocks,  .chirp,  .far,
        .mall,    .mellohi, .stal,   .strad,  .ward,
        .disc_11, .wait,   .pigstep,
    };
    for (all, 0..) |disc, i| {
        const def = getDiscDef(disc);
        try std.testing.expect(def.duration_seconds > 0);
        try std.testing.expectEqual(DISC_ITEM_BASE + @as(u16, @intCast(i)), def.item_id);
    }
}

test "jukebox starts empty and not playing" {
    const jb = JukeboxState.init();
    try std.testing.expect(jb.current_disc == null);
    try std.testing.expect(!jb.isPlaying());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), jb.play_timer, 0.001);
}

test "insertDisc into empty jukebox returns null" {
    var jb = JukeboxState.init();
    const ejected = jb.insertDisc(.cat);
    try std.testing.expect(ejected == null);
    try std.testing.expect(jb.isPlaying());
    try std.testing.expectEqual(DiscType.cat, jb.current_disc.?);
}

test "insertDisc into occupied jukebox ejects previous disc" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.cat);
    const ejected = jb.insertDisc(.blocks);
    try std.testing.expectEqual(DiscType.cat, ejected.?);
    try std.testing.expectEqual(DiscType.blocks, jb.current_disc.?);
    try std.testing.expect(jb.isPlaying());
}

test "ejectDisc returns disc and stops playback" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.ward);
    const ejected = jb.ejectDisc();
    try std.testing.expectEqual(DiscType.ward, ejected.?);
    try std.testing.expect(jb.current_disc == null);
    try std.testing.expect(!jb.isPlaying());
}

test "ejectDisc on empty jukebox returns null" {
    var jb = JukeboxState.init();
    const ejected = jb.ejectDisc();
    try std.testing.expect(ejected == null);
    try std.testing.expect(!jb.isPlaying());
}

test "update advances play timer" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.mellohi); // 96s duration
    jb.update(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), jb.play_timer, 0.001);
    try std.testing.expect(jb.isPlaying());
}

test "update stops playback when disc finishes" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.mellohi); // 96s duration
    jb.update(100.0);
    try std.testing.expect(!jb.isPlaying());
}

test "update is no-op when not playing" {
    var jb = JukeboxState.init();
    jb.update(5.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), jb.play_timer, 0.001);
    try std.testing.expect(!jb.isPlaying());
}

test "note block starts at pitch 0 with piano" {
    const nb = NoteBlockState.init();
    try std.testing.expectEqual(@as(u5, 0), nb.pitch);
    try std.testing.expectEqual(Instrument.piano, nb.instrument);
}

test "tunePitch increments pitch" {
    var nb = NoteBlockState.init();
    nb.tunePitch();
    try std.testing.expectEqual(@as(u5, 1), nb.pitch);
    nb.tunePitch();
    try std.testing.expectEqual(@as(u5, 2), nb.pitch);
}

test "tunePitch wraps from 24 to 0" {
    var nb = NoteBlockState.init();
    nb.pitch = 24;
    nb.tunePitch();
    try std.testing.expectEqual(@as(u5, 0), nb.pitch);
}

test "tunePitch cycles through all 25 values" {
    var nb = NoteBlockState.init();
    var i: u32 = 0;
    while (i < 25) : (i += 1) {
        try std.testing.expectEqual(@as(u5, @intCast(i)), nb.pitch);
        nb.tunePitch();
    }
    try std.testing.expectEqual(@as(u5, 0), nb.pitch);
}

test "play returns current pitch and instrument" {
    var nb = NoteBlockState.init();
    nb.pitch = 12;
    nb.instrument = .bell;
    const event = nb.play();
    try std.testing.expectEqual(@as(u5, 12), event.pitch);
    try std.testing.expectEqual(Instrument.bell, event.instrument);
}

test "instrument determined by block below" {
    try std.testing.expectEqual(Instrument.bass_guitar, instrumentForBlock(OAK_PLANKS));
    try std.testing.expectEqual(Instrument.bass_guitar, instrumentForBlock(OAK_LOG));
    try std.testing.expectEqual(Instrument.bass_drum, instrumentForBlock(STONE));
    try std.testing.expectEqual(Instrument.snare, instrumentForBlock(SAND));
    try std.testing.expectEqual(Instrument.hat, instrumentForBlock(GLASS));
    try std.testing.expectEqual(Instrument.piano, instrumentForBlock(DIRT));
    try std.testing.expectEqual(Instrument.bell, instrumentForBlock(GOLD_ORE));
    try std.testing.expectEqual(Instrument.flute, instrumentForBlock(CLAY));
    try std.testing.expectEqual(Instrument.chime, instrumentForBlock(ICE));
}

test "unknown block defaults to piano" {
    try std.testing.expectEqual(Instrument.piano, instrumentForBlock(0)); // AIR
    try std.testing.expectEqual(Instrument.piano, instrumentForBlock(255)); // unknown
}

test "setInstrumentFromBlock updates instrument" {
    var nb = NoteBlockState.init();
    nb.setInstrumentFromBlock(SAND);
    try std.testing.expectEqual(Instrument.snare, nb.instrument);
    nb.setInstrumentFromBlock(GLASS);
    try std.testing.expectEqual(Instrument.hat, nb.instrument);
}
