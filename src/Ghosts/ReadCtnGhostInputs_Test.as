// Dev-only. build.sh omits *_Test.as from prerelease, unittest, and release.

namespace Tests {
    TmInputChange@ Sample(uint64 states, int8 steer, uint16 mouseX, bool gas, bool brake, bool horn, uint8 characterStates) {
        return TmInputChange(15, states, mouseX, 0, steer, gas, brake, horn, characterStates);
    }

    [Test]
    void GhostInput_SteerGasBrakeFloats(Tests::Context@ ctx) {
        auto fullRight = Sample(0, 127, 0, true, false, false, 0);
        ctx.AssertSame(fullRight.SteerF, 1.0f, "full right steer is +1");
        ctx.AssertSame(fullRight.GasF, 1.0f, "gas on is 1");
        ctx.AssertSame(fullRight.BrakeF, 0.0f, "brake off is 0");

        auto fullLeft = Sample(0, int8(-127), 0, false, true, false, 0);
        ctx.AssertSame(fullLeft.SteerF, -1.0f, "full left steer is -1");
        ctx.AssertSame(fullLeft.BrakeF, 1.0f, "brake on is 1");
        ctx.AssertSame(Sample(0, 0, 0, false, false, false, 0).SteerF, 0.0f, "center steer is 0");
    }

    [Test]
    void GhostInput_MouseIsSigned(Tests::Context@ ctx) {
        auto c = Sample(0, 0, 65535, false, false, false, 0);
        ctx.AssertSame(c.MouseX, int16(-1), "mouse accumulator 0xFFFF is -1");
        ctx.AssertSame(c.Time, int64(150), "tick 15 is 150 ms");
    }

    [Test]
    void GhostInput_HornRespawnLookBits(Tests::Context@ ctx) {
        auto horn = Sample(uint64(1) << 6, 0, 0, false, false, true, 0);
        ctx.AssertTrue(horn.Horn, "stored horn flag");
        ctx.AssertFalse(horn.Respawn, "horn bit is not respawn");
        ctx.AssertFalse(horn.SecondaryRespawn, "horn bit is not standing respawn");

        auto respawn = Sample(uint64(1) << 31, 0, 0, false, false, false, 0);
        ctx.AssertTrue(respawn.Respawn, "checkpoint respawn is packed bit 31");
        ctx.AssertFalse(respawn.Horn, "respawn bit does not set horn");

        auto hornBit0 = Sample(uint64(1) << 5, 0, 0, false, false, true, 0);
        ctx.AssertTrue(hornBit0.Horn, "dwButtons bit 0 is the other horn bit");
        ctx.AssertFalse(hornBit0.Respawn, "horn bit 0 is not checkpoint respawn");
        ctx.AssertTrue(Sample(uint64(1) << 17, 0, 0, false, false, false, 0).ActionSlot6, "slot 6 is packed bit 17");
        ctx.AssertTrue(Sample(uint64(1) << 19, 0, 0, false, false, false, 0).ActionSlot8, "slot 8 is packed bit 19");
        ctx.AssertTrue(Sample(uint64(1) << 21, 0, 0, false, false, false, 0).ActionSlot0, "slot 0 is packed bit 21");

        uint64 pulsed = (uint64(1) << 6) | (uint64(1) << 31) | (uint64(1) << 33);
        uint64 kept = GhostInputWithoutPulse(pulsed);
        ctx.AssertSame(kept, uint64(1) << 6, "pulse bits 27-33 clear and horn bit 6 stays");

        auto standing = Sample(uint64(1) << 33, 0, 0, false, false, false, 0);
        ctx.AssertTrue(standing.SecondaryRespawn, "standing respawn is packed bit 33");
        ctx.AssertFalse(standing.Respawn, "standing respawn is not checkpoint respawn");

        auto look = Sample(uint64(1) << 24, 0, 0, false, false, false, 0);
        ctx.AssertTrue(look.RearView, "look-back is button bit 19, packed bit 24");
        ctx.AssertFalse(look.FreeLook, "rear view is not the free-look flag");
        ctx.AssertTrue(Sample(uint64(1) << 4, 0, 0, false, false, false, 0).FreeLook, "free look is packed bit 4");
    }

    [Test]
    void GhostInput_CharacterTernary(Tests::Context@ ctx) {
        // Low pair is code 1 (+1), next pair is code 3 (-1).
        auto c = Sample(0, 0, 0, false, false, false, uint8(1 | (3 << 2)));
        ctx.AssertSame(c.CharF0, 1.0f, "first ternary code is +1");
        ctx.AssertSame(c.CharF1, -1.0f, "second ternary code is -1");
        ctx.AssertSame(c.CharF2, 0.0f, "unset ternary code is 0");
        ctx.AssertSame(c.CharF3, 0.0f, "unset high ternary code is 0");
    }
}
