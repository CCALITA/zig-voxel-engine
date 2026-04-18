/// Mob variant definitions: different visual/behavioral variants of base mob types.
const std = @import("std");

pub const CatVariant = enum {
    tabby,
    tuxedo,
    red,
    siamese,
    british_shorthair,
    calico,
    persian,
    ragdoll,
    white,
    jellie,
    all_black,
};

pub const RabbitVariant = enum {
    brown,
    white,
    black,
    black_and_white,
    gold,
    salt_and_pepper,
    killer_bunny,
};

pub const FrogVariant = enum {
    temperate,
    warm,
    cold,
};

pub const MooshroomVariant = enum {
    red,
    brown,
};

pub const AxolotlVariant = enum {
    lucy,
    wild,
    gold,
    cyan,
    blue,
};

pub fn getCatVariantCount() usize {
    return std.meta.fields(CatVariant).len;
}

pub fn getRabbitVariantCount() usize {
    return std.meta.fields(RabbitVariant).len;
}

test "cat variant count" {
    try std.testing.expectEqual(@as(usize, 11), getCatVariantCount());
}

test "rabbit variant count" {
    try std.testing.expectEqual(@as(usize, 7), getRabbitVariantCount());
}

test "frog variants" {
    const v: FrogVariant = .temperate;
    try std.testing.expectEqual(FrogVariant.temperate, v);
}
