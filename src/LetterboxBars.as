AnimMgr@ lbAnimMgr;

void UpdateDrawLetterboxBars() {
    if (lbAnimMgr is null) @lbAnimMgr = AnimMgr(false, 250.);
    if (lbAnimMgr.Update(IsSpectatingGhost())) {
        nvg_DrawLetterbox(lbAnimMgr.Progress);
    }
}

const float lbPctFromEdge = 0.10;

void nvg_DrawLetterbox(float t) {
    float screenH = Draw::GetHeight();
    float screenW = Draw::GetWidth();
    float lbHeight = lbPctFromEdge * screenH;
    float lbTopPos = Math::Lerp(-lbHeight, 0, t);
    float lbBottomPos = Math::Lerp(screenH, screenH - lbHeight, t);
    nvg::Reset();

    nvg::BeginPath();
    nvg::FillColor(vec4(0, 0, 0, 1));
    nvg::Rect(vec2(0, lbTopPos), vec2(screenW, lbHeight));
    nvg::Fill();
    nvg::ClosePath();

    nvg::BeginPath();
    nvg::FillColor(vec4(0, 0, 0, 1));
    nvg::Rect(vec2(0, lbBottomPos), vec2(screenW, lbHeight));
    nvg::Fill();
    nvg::ClosePath();

    nvg::BeginPath();
    nvg::Rect(vec2(-100), vec2(0));
    nvg::ClosePath();
}

class AnimMgr {
    float t = 0.0;
    float animOut = 0.0;
    float animDuration;
    bool lastGrowing = false;
    uint lastGrowingChange = 0;
    uint lastGrowingCheck = 0;

    AnimMgr(bool startOpen = false, float duration = 250.0) {
        t = startOpen ? 1.0 : 0.0;
        animOut = t;
        animDuration = duration;
    }

    void SetAt(float newT) {
        t = newT;
        lastGrowingChange = Time::Now;
    }

    // return true if
    bool Update(bool growing, float clampMax = 1.0) {
        if (lastGrowingChange == 0) lastGrowingChange = Time::Now;
        if (lastGrowingCheck == 0) lastGrowingCheck = Time::Now;

        float delta = float(int(Time::Now) - int(lastGrowingCheck)) / animDuration;
        delta = Math::Min(delta, 0.2);
        lastGrowingCheck = Time::Now;

        float sign = growing ? 1.0 : -1.0;
        t = Math::Clamp(t + sign * delta, 0.0, 1.0);
        if (lastGrowing != growing) {
            lastGrowing = growing;
            lastGrowingChange = Time::Now;
        }

        // QuadOut
        animOut = -(t * (t - 2.));
        animOut = Math::Min(clampMax, animOut);
        return animOut > 0.;
    }

    float Progress {
        get {
            return animOut;
        }
    }

    bool IsDone {
        get {
            return animOut >= 1.0;
        }
    }
}
