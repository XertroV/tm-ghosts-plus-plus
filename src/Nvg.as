
const double TAU = 6.28318530717958647692;
// this does not seem to be expensive
const float nTextStrokeCopies = 32;

void DrawTextWithStroke(const vec2 &in pos, const string &in text, vec4 textColor, float strokeWidth, vec4 strokeColor = vec4(0, 0, 0, 1)) {
    nvg::FillColor(strokeColor);
    for (float i = 0; i < nTextStrokeCopies; i++) {
        float angle = TAU * float(i) / nTextStrokeCopies;
        vec2 offs = vec2(Math::Sin(angle), Math::Cos(angle)) * strokeWidth;
        nvg::Text(pos + offs, text);
    }
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
}

// int g_nvgFont = nvg::LoadFont("DroidSans-Bold.ttf");
// const float TAU = 6.283185307179586;

const vec4 c_black = vec4(0, 0, 0, 1);
const vec4 c_transparent = vec4(0);
const vec4 c_half_transparent = vec4(1, 1, 1, .5);
const vec4 c_white = vec4(1);
const vec4 c_red = vec4(1, 0, 0, 1);
const vec4 c_green = vec4(0, 1, 0, 1);
const vec4 c_blue = vec4(0, 0, 1, 1);

void DrawDebugRect(vec2 pos, vec2 size, vec4 col = vec4(1, .5, 0, 1)) {
    nvg::BeginPath();
    nvg::Rect(pos, size);
    nvg::StrokeColor(col);
    nvg::Stroke();
    nvg::ClosePath();
}

void DrawDebugCircle(vec2 pos, vec2 size, vec4 col = vec4(1, .5, 0, 1)) {
    nvg::BeginPath();
    nvg::Ellipse(pos, size.x, size.y);
    nvg::StrokeColor(col);
    nvg::Stroke();
    nvg::FillColor(col * c_half_transparent);
    nvg::Fill();
    nvg::ClosePath();
}
