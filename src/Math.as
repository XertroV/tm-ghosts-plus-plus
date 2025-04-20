// decayRate in [1, 25]; higher = snappier
// use like: a = SmoothFollow(a, b, dt, 8.0);
float SmoothFollow(float current, float target, float dt, float decayRate = 8.0) {
    return target + (current - target) * Math::Clamp(Math::Exp(decayRate * dt * -1.0), 0.0, 1.0);
}
