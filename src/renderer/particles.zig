const std = @import("std");

pub const Particle = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    lifetime: f32,
    max_lifetime: f32,
    size: f32,
    active: bool,
};

pub const ParticleManager = struct {
    particles: [MAX_PARTICLES]Particle,
    count: u32,
    next_slot: u32,

    pub const MAX_PARTICLES: u32 = 1024;

    const inactive_particle = std.mem.zeroes(Particle);

    pub fn init() ParticleManager {
        return ParticleManager{
            .particles = [_]Particle{inactive_particle} ** MAX_PARTICLES,
            .count = 0,
            .next_slot = 0,
        };
    }

    /// Emit particles for a block break effect.
    /// Spawns 8 particles with random velocity spread, the given block color,
    /// lifetime between 0.5 and 1.0 seconds, and size 0.1.
    pub fn emitBlockBreak(self: *ParticleManager, x: f32, y: f32, z: f32, r: f32, g: f32, b: f32) void {
        var prng = std.Random.DefaultPrng.init(blk: {
            const seed_a: u32 = @bitCast(x);
            const seed_b: u32 = @bitCast(y);
            const seed_c: u32 = @bitCast(z);
            break :blk @as(u64, seed_a) ^ (@as(u64, seed_b) << 16) ^ (@as(u64, seed_c) << 32);
        });
        const rng = prng.random();

        for (0..8) |_| {
            const vx = rng.float(f32) * 4.0 - 2.0;
            const vy = rng.float(f32) * 4.0;
            const vz = rng.float(f32) * 4.0 - 2.0;
            const lifetime = 0.5 + rng.float(f32) * 0.5;

            self.emit(Particle{
                .x = x,
                .y = y,
                .z = z,
                .vx = vx,
                .vy = vy,
                .vz = vz,
                .r = r,
                .g = g,
                .b = b,
                .a = 1.0,
                .lifetime = lifetime,
                .max_lifetime = lifetime,
                .size = 0.1,
                .active = true,
            });
        }
    }

    /// Emit a single particle with custom properties.
    /// Uses circular reuse: when the buffer is full, the oldest slot is overwritten.
    pub fn emit(self: *ParticleManager, particle: Particle) void {
        const was_active = self.particles[self.next_slot].active;
        self.particles[self.next_slot] = particle;

        if (particle.active and !was_active) {
            self.count += 1;
        } else if (!particle.active and was_active) {
            self.count -= 1;
        }

        self.next_slot = (self.next_slot + 1) % MAX_PARTICLES;
    }

    /// Update all particles: apply gravity, reduce lifetime, fade alpha.
    /// Deactivates particles whose lifetime has expired.
    pub fn update(self: *ParticleManager, dt: f32) void {
        var active: u32 = 0;
        for (&self.particles) |*p| {
            if (!p.active) continue;

            p.lifetime -= dt;
            if (p.lifetime <= 0) {
                p.active = false;
                continue;
            }

            p.vy -= 10.0 * dt;
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.z += p.vz * dt;

            p.a = p.lifetime / p.max_lifetime;

            active += 1;
        }
        self.count = active;
    }

    /// Return a slice of all particles (caller filters by .active).
    pub fn activeParticles(self: *const ParticleManager) []const Particle {
        return self.particles[0..];
    }

    /// Return the number of currently active particles.
    pub fn activeCount(self: *const ParticleManager) u32 {
        return self.count;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "emitBlockBreak creates 8 particles" {
    var mgr = ParticleManager.init();
    try std.testing.expectEqual(@as(u32, 0), mgr.activeCount());

    mgr.emitBlockBreak(5.0, 10.0, 5.0, 0.6, 0.3, 0.1);
    try std.testing.expectEqual(@as(u32, 8), mgr.activeCount());

    // Verify color and size on every emitted particle
    var found: u32 = 0;
    for (mgr.activeParticles()) |p| {
        if (p.active) {
            try std.testing.expectApproxEqAbs(@as(f32, 0.6), p.r, 0.001);
            try std.testing.expectApproxEqAbs(@as(f32, 0.3), p.g, 0.001);
            try std.testing.expectApproxEqAbs(@as(f32, 0.1), p.b, 0.001);
            try std.testing.expectApproxEqAbs(@as(f32, 0.1), p.size, 0.001);
            try std.testing.expect(p.lifetime >= 0.5 and p.lifetime <= 1.0);
            found += 1;
        }
    }
    try std.testing.expectEqual(@as(u32, 8), found);
}

test "update reduces lifetime" {
    var mgr = ParticleManager.init();
    mgr.emit(Particle{
        .x = 0,
        .y = 0,
        .z = 0,
        .vx = 0,
        .vy = 0,
        .vz = 0,
        .r = 1,
        .g = 1,
        .b = 1,
        .a = 1.0,
        .lifetime = 1.0,
        .max_lifetime = 1.0,
        .size = 0.1,
        .active = true,
    });

    const before = mgr.particles[0].lifetime;
    mgr.update(0.2);
    const after = mgr.particles[0].lifetime;
    try std.testing.expect(after < before);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), after, 0.001);
}

test "dead particles removed (activeCount decreases)" {
    var mgr = ParticleManager.init();
    mgr.emit(Particle{
        .x = 0,
        .y = 0,
        .z = 0,
        .vx = 0,
        .vy = 0,
        .vz = 0,
        .r = 1,
        .g = 1,
        .b = 1,
        .a = 1.0,
        .lifetime = 0.3,
        .max_lifetime = 0.3,
        .size = 0.1,
        .active = true,
    });
    try std.testing.expectEqual(@as(u32, 1), mgr.activeCount());

    // After 0.5s the particle (lifetime 0.3s) should be dead
    mgr.update(0.5);
    try std.testing.expectEqual(@as(u32, 0), mgr.activeCount());
}

test "alpha fades with lifetime" {
    var mgr = ParticleManager.init();
    mgr.emit(Particle{
        .x = 0,
        .y = 0,
        .z = 0,
        .vx = 0,
        .vy = 0,
        .vz = 0,
        .r = 1,
        .g = 1,
        .b = 1,
        .a = 1.0,
        .lifetime = 1.0,
        .max_lifetime = 1.0,
        .size = 0.1,
        .active = true,
    });

    mgr.update(0.5);

    // lifetime is now 0.5, max_lifetime is 1.0 => alpha should be 0.5
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), mgr.particles[0].a, 0.001);
}

test "circular reuse when buffer full" {
    var mgr = ParticleManager.init();

    // Fill all slots
    for (0..ParticleManager.MAX_PARTICLES) |_| {
        mgr.emit(Particle{
            .x = 0,
            .y = 0,
            .z = 0,
            .vx = 0,
            .vy = 0,
            .vz = 0,
            .r = 0,
            .g = 0,
            .b = 0,
            .a = 1.0,
            .lifetime = 5.0,
            .max_lifetime = 5.0,
            .size = 0.1,
            .active = true,
        });
    }
    try std.testing.expectEqual(ParticleManager.MAX_PARTICLES, mgr.activeCount());

    // Emit one more -- should overwrite slot 0 (circular)
    mgr.emit(Particle{
        .x = 99.0,
        .y = 99.0,
        .z = 99.0,
        .vx = 0,
        .vy = 0,
        .vz = 0,
        .r = 1,
        .g = 0,
        .b = 0,
        .a = 1.0,
        .lifetime = 2.0,
        .max_lifetime = 2.0,
        .size = 0.2,
        .active = true,
    });

    // Count should still be MAX_PARTICLES (overwrite, not grow)
    try std.testing.expectEqual(ParticleManager.MAX_PARTICLES, mgr.activeCount());

    // Slot 0 should have the new particle data
    try std.testing.expectApproxEqAbs(@as(f32, 99.0), mgr.particles[0].x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), mgr.particles[0].lifetime, 0.001);
}
