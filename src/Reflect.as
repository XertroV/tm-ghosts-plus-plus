// Safe reflection lookups.
//
// Upstream's GetOffset() throws when a class or member is missing. That is fatal here,
// because almost every offset in this plugin is declared as a *global* constant:
//
//     const uint16 O_CTNGHOST_PRESTIGE = GetOffset("CGameCtnGhost", "LightTrailColor") - 0x10;
//
// Global initialisers run at module load, before Main(). One renamed member after a game
// update would therefore take the entire plugin down before any capability check could
// run. The helpers here never throw: they return a fallback, and the owning capability's
// probe re-runs the same lookup later (from Main(), where reporting is safe) to explain
// exactly what went missing.

namespace Compat {
    bool HasType(const string &in className) {
        return Reflection::GetType(className) !is null;
    }

    // Members are inherited, so walk the base-type chain rather than trusting a single
    // lookup. Iterating Members is used instead of GetMember because GetMember's
    // behaviour for a missing name is unspecified, and this must never throw.
    const Reflection::MwMemberInfo@ FindMember(const string &in className, const string &in memberName) {
        auto ty = Reflection::GetType(className);
        while (ty !is null) {
            auto members = ty.Members;
            for (uint i = 0; i < members.Length; i++) {
                if (members[i].Name == memberName) return members[i];
            }
            @ty = ty.BaseType;
        }
        return null;
    }

    bool HasMember(const string &in className, const string &in memberName) {
        return FindMember(className, memberName) !is null;
    }

    // Reports every missing member of a class in one string, for probe failure messages.
    // Returns an empty string when they are all present.
    string MissingMembers(const string &in className, string[]@ memberNames) {
        if (!HasType(className)) return "class '" + className + "' no longer exists";
        string[] missing;
        for (uint i = 0; i < memberNames.Length; i++) {
            if (!HasMember(className, memberNames[i])) missing.InsertLast(memberNames[i]);
        }
        if (missing.IsEmpty()) return "";
        return className + " is missing: " + string::Join(missing, ", ");
    }

    uint16 OffsetOf(const string &in className, const string &in memberName, uint16 fallback = 0) {
        auto m = FindMember(className, memberName);
        return m is null ? fallback : m.Offset;
    }

    // Struct size, or 0 if unknown. Useful as a bounds sanity check before reading at a
    // hardcoded delta from a reflected anchor.
    uint SizeOf(const string &in className) {
        auto ty = Reflection::GetType(className);
        return ty is null ? 0 : ty.Size;
    }
}

/**
 * Drop-in replacement for GetOffset() that is safe to call from a global initialiser.
 * Returns `fallback` instead of throwing when the class or member is gone; the value is
 * never read, because the capability guarding that read will have failed its probe.
 */
uint16 GetOffsetSafe(const string &in className, const string &in memberName, uint16 fallback = 0) {
    return Compat::OffsetOf(className, memberName, fallback);
}
