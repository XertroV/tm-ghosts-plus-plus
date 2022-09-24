// Most of this file is commented, but the code is left here in case it's useful in future.

// UI::Font@ headingFont = UI::LoadFont("DroidSans.ttf", 20, -1, -1, true, true);
// UI::Font@ subheadingFont = UI::LoadFont("DroidSans.ttf", 18, -1, -1, true, true);
// UI::Font@ stdBold = UI::LoadFont("DroidSans-Bold.ttf", 16, -1, -1, true, true);
// UI::Font@ boldSubHeading = UI::LoadFont("DroidSans-Bold.ttf", 18, -1, -1, true, true);
// UI::Font@ boldHeading = UI::LoadFont("DroidSans-Bold.ttf", 20, -1, -1, true, true);

/* tooltips */

void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::BeginTooltip();
        UI::Text(msg);
        UI::EndTooltip();
    }
}

// /* button */

void DisabledButton(const string &in text, const vec2 &in size = vec2 ( )) {
    UI::BeginDisabled();
    UI::Button(text, size);
    UI::EndDisabled();
}

bool MDisabledButton(bool disabled, const string &in text, const vec2 &in size = vec2 ( )) {
    if (disabled) {
        DisabledButton(text, size);
        return false;
    } else {
        return UI::Button(text, size);
    }
}

// bool ButtonVariant(bool useAlt, const string &in id, const string &in label1, const string &in label2, vec4 altColor) {
//     if (useAlt) {
//         UI::PushStyleColor(UI::Col::Button, altColor);
//         UI::PushStyleColor(UI::Col::ButtonHovered, altColor * 1.3);
//         UI::PushStyleColor(UI::Col::ButtonActive, altColor * .75);
//     }
//     bool ret = UI::Button((useAlt ? label2 : label1) + "##" + id);
//     if (useAlt) {
//         UI::PopStyleColor(3);
//     }
//     return ret;
// }

// // 16x16 button
// bool TinyButton(const string &in label) {
//     UI::PushStyleVar(UI::StyleVar::ButtonTextAlign, vec2(.5, .5));
//     UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(0, 0));
//     bool ret = UI::Button(label, vec2(16, 16));
//     UI::PopStyleVar(2);
//     return ret;
// }

// /* padding */

// void VPad() {
//     UI::Dummy(vec2(0, 2));
// }

// void PaddedSep() {
//     VPad();
//     UI::Separator();
//     VPad();
// }

// void SameLineWithDummyX(float dummyWidth = 20) {
//     UI::SameLine();
//     UI::Dummy(vec2(dummyWidth, 0));
//     UI::SameLine();
// }

// /* heading */

// void TextHeading(const string &in t) {
//     UI::PushFont(headingFont);
//     VPad();
//     UI::Text(t);
//     UI::Separator();
//     VPad();
//     UI::PopFont();
// }

// void Heading(const string &in t) {
//     UI::PushFont(boldHeading);
//     UI::Text(t);
//     VPad();
//     UI::PopFont();
// }

// void SubHeading(const string &in t) {
//     UI::PushFont(boldSubHeading);
//     UI::Text(t);
//     VPad();
//     UI::PopFont();
// }

// void ColHeading(const string &in t, bool padUnder = true) {
//     UI::PushFont(stdBold);
//     UI::Text(t);
//     if (padUnder) VPad();
//     UI::PopFont();
// }



// /* sorta functional way to draw elements dynamically as a list or row or other things. */

// funcdef void DrawUiElems();
// funcdef void DrawUiElemsWRef(ref@ r);
// funcdef void DrawUiElemsF(DrawUiElems@ f);

// void DrawAsRow(DrawUiElemsF@ f, const string &in id, int cols = 64) {
//     int flags = 0;
//     flags |= UI::TableFlags::SizingFixedFit;
//     flags |= UI::TableFlags::NoPadOuterX;
//     if (UI::BeginTable(id, cols, flags)) {
//         UI::TableNextRow();
//         f(DrawUiElems(_TableNextColumn));
//         UI::EndTable();
//     }
// }

// void _TableNextRow() {
//     UI::TableNextRow();
// }
// void _TableNextColumn() {
//     UI::TableNextColumn();
// }

// /* table column pair */

// void DrawAs2Cols(const string &in c1, const string &in c2) {
//     UI::TableNextColumn();
//     UI::Text(c1);
//     UI::TableNextColumn();
//     UI::Text(c2);
// }

// /* horiz centering */

// int TableFlagsFixed() {
//     return UI::TableFlags::SizingFixedFit;
// }
// int TableFlagsFixedSame() {
//     return UI::TableFlags::SizingFixedSame;
// }
// int TableFlagsStretch() {
//     return UI::TableFlags::SizingStretchProp;
// }
// int TableFlagsStretchSame() {
//     return UI::TableFlags::SizingStretchSame;
// }
// int TableFBorders() {
//     return UI::TableFlags::Borders;
// }

// void DrawCenteredInTable(const string &in tableId, DrawUiElems@ f) {
//     /* cast the function to a ref so we can delcare an anon function that casts it back to a normal function and then calls it. */
//     DrawCenteredInTable(tableId, function(ref@ _r){
//         DrawUiElems@ r = cast<DrawUiElems@>(_r);
//         r();
//     }, f);
// }

// void DrawCenteredInTable(const string &in tableId, DrawUiElemsWRef@ f, ref@ r) {
//     if (UI::BeginTable(tableId, 3, TableFlagsStretch())) { //  | TableFBorders()
//         /* CENTERING!!! */
//         UI::TableSetupColumn(tableId + "-left", UI::TableColumnFlags::WidthStretch);
//         UI::TableSetupColumn(tableId + "-content", UI::TableColumnFlags::WidthFixed);
//         UI::TableSetupColumn(tableId + "-right", UI::TableColumnFlags::WidthStretch);
//         UI::TableNextColumn();
//         UI::TableNextColumn();
//         f(r);
//         UI::TableNextColumn();
//         UI::EndTable();
//     }
// }
