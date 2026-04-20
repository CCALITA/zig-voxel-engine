const std = @import("std");

pub const Profession = enum(u8) {
    none,
    armorer,
    butcher,
    cartographer,
    cleric,
    farmer,
    fisherman,
    fletcher,
    leatherworker,
    librarian,
    mason,
    shepherd,
    toolsmith,
    weaponsmith,
};

pub const WorkstationBlock = struct {
    profession: Profession,
    block_id: u8,
};

/// Block IDs for workstation blocks.
const BlockId = struct {
    const barrel: u8 = 0x01;
    const blast_furnace: u8 = 0x02;
    const brewing_stand: u8 = 0x03;
    const cartography_table: u8 = 0x04;
    const cauldron: u8 = 0x05;
    const composter: u8 = 0x06;
    const fletching_table: u8 = 0x07;
    const grindstone: u8 = 0x08;
    const lectern: u8 = 0x09;
    const loom: u8 = 0x0A;
    const smithing_table: u8 = 0x0B;
    const smoker: u8 = 0x0C;
    const stonecutter: u8 = 0x0D;
};

pub const WORKSTATION_MAP: [13]WorkstationBlock = .{
    .{ .profession = .fisherman, .block_id = BlockId.barrel },
    .{ .profession = .armorer, .block_id = BlockId.blast_furnace },
    .{ .profession = .cleric, .block_id = BlockId.brewing_stand },
    .{ .profession = .cartographer, .block_id = BlockId.cartography_table },
    .{ .profession = .leatherworker, .block_id = BlockId.cauldron },
    .{ .profession = .farmer, .block_id = BlockId.composter },
    .{ .profession = .fletcher, .block_id = BlockId.fletching_table },
    .{ .profession = .weaponsmith, .block_id = BlockId.grindstone },
    .{ .profession = .librarian, .block_id = BlockId.lectern },
    .{ .profession = .shepherd, .block_id = BlockId.loom },
    .{ .profession = .toolsmith, .block_id = BlockId.smithing_table },
    .{ .profession = .butcher, .block_id = BlockId.smoker },
    .{ .profession = .mason, .block_id = BlockId.stonecutter },
};

pub fn getProfessionForBlock(block_id: u8) ?Profession {
    for (WORKSTATION_MAP) |entry| {
        if (entry.block_id == block_id) {
            return entry.profession;
        }
    }
    return null;
}

pub fn getWorkstationBlock(profession: Profession) ?u8 {
    if (profession == .none) return null;
    for (WORKSTATION_MAP) |entry| {
        if (entry.profession == profession) {
            return entry.block_id;
        }
    }
    return null;
}

pub const WorkSchedule = struct {
    work_start: u32 = 2000,
    work_end: u32 = 9000,

    pub fn isWorkTime(self: WorkSchedule, tick: u32) bool {
        return tick >= self.work_start and tick < self.work_end;
    }
};

pub const WorkstationClaim = struct {
    villager_id: u32,
    station_x: i32,
    station_y: i32,
    station_z: i32,
    claimed: bool,
};

pub fn claimWorkstation(villager_id: u32, station_x: i32, station_y: i32, station_z: i32) WorkstationClaim {
    return WorkstationClaim{
        .villager_id = villager_id,
        .station_x = station_x,
        .station_y = station_y,
        .station_z = station_z,
        .claimed = true,
    };
}

pub fn releaseWorkstation(claim: WorkstationClaim) WorkstationClaim {
    var released = claim;
    released.claimed = false;
    return released;
}

test "barrel maps to fisherman" {
    try std.testing.expectEqual(Profession.fisherman, getProfessionForBlock(BlockId.barrel).?);
}

test "blast_furnace maps to armorer" {
    try std.testing.expectEqual(Profession.armorer, getProfessionForBlock(BlockId.blast_furnace).?);
}

test "brewing_stand maps to cleric" {
    try std.testing.expectEqual(Profession.cleric, getProfessionForBlock(BlockId.brewing_stand).?);
}

test "cartography_table maps to cartographer" {
    try std.testing.expectEqual(Profession.cartographer, getProfessionForBlock(BlockId.cartography_table).?);
}

test "cauldron maps to leatherworker" {
    try std.testing.expectEqual(Profession.leatherworker, getProfessionForBlock(BlockId.cauldron).?);
}

test "composter maps to farmer" {
    try std.testing.expectEqual(Profession.farmer, getProfessionForBlock(BlockId.composter).?);
}

test "fletching_table maps to fletcher" {
    try std.testing.expectEqual(Profession.fletcher, getProfessionForBlock(BlockId.fletching_table).?);
}

test "grindstone maps to weaponsmith" {
    try std.testing.expectEqual(Profession.weaponsmith, getProfessionForBlock(BlockId.grindstone).?);
}

test "lectern maps to librarian" {
    try std.testing.expectEqual(Profession.librarian, getProfessionForBlock(BlockId.lectern).?);
}

test "loom maps to shepherd" {
    try std.testing.expectEqual(Profession.shepherd, getProfessionForBlock(BlockId.loom).?);
}

test "smithing_table maps to toolsmith" {
    try std.testing.expectEqual(Profession.toolsmith, getProfessionForBlock(BlockId.smithing_table).?);
}

test "smoker maps to butcher" {
    try std.testing.expectEqual(Profession.butcher, getProfessionForBlock(BlockId.smoker).?);
}

test "stonecutter maps to mason" {
    try std.testing.expectEqual(Profession.mason, getProfessionForBlock(BlockId.stonecutter).?);
}

test "unknown block returns null" {
    try std.testing.expectEqual(@as(?Profession, null), getProfessionForBlock(0xFF));
}

test "getWorkstationBlock reverse lookup" {
    try std.testing.expectEqual(BlockId.barrel, getWorkstationBlock(.fisherman).?);
    try std.testing.expectEqual(BlockId.lectern, getWorkstationBlock(.librarian).?);
    try std.testing.expectEqual(@as(?u8, null), getWorkstationBlock(.none));
}

test "work schedule isWorkTime" {
    const schedule = WorkSchedule{};
    try std.testing.expect(!schedule.isWorkTime(1999));
    try std.testing.expect(schedule.isWorkTime(2000));
    try std.testing.expect(schedule.isWorkTime(5000));
    try std.testing.expect(schedule.isWorkTime(8999));
    try std.testing.expect(!schedule.isWorkTime(9000));
    try std.testing.expect(!schedule.isWorkTime(10000));
}

test "work schedule custom times" {
    const schedule = WorkSchedule{ .work_start = 1000, .work_end = 5000 };
    try std.testing.expect(!schedule.isWorkTime(999));
    try std.testing.expect(schedule.isWorkTime(1000));
    try std.testing.expect(!schedule.isWorkTime(5000));
}

test "claim and release workstation" {
    const claim = claimWorkstation(42, 100, 64, -200);
    try std.testing.expectEqual(@as(u32, 42), claim.villager_id);
    try std.testing.expectEqual(@as(i32, 100), claim.station_x);
    try std.testing.expectEqual(@as(i32, 64), claim.station_y);
    try std.testing.expectEqual(@as(i32, -200), claim.station_z);
    try std.testing.expect(claim.claimed);

    const released = releaseWorkstation(claim);
    try std.testing.expectEqual(@as(u32, 42), released.villager_id);
    try std.testing.expectEqual(@as(i32, 100), released.station_x);
    try std.testing.expect(!released.claimed);
}
