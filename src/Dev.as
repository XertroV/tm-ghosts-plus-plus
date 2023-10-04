uint16 GetOffset(const string &in className, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::GetType(className);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}

uint16 GetOffset(CMwNod@ nod, const string &in memberName) {
    // throw exception when something goes wrong.
    auto ty = Reflection::TypeOf(nod);
    auto memberTy = ty.GetMember(memberName);
    return memberTy.Offset;
}
