#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;

// Adds film grain to a negative, as Spectral Film LUT's documented grain
// workflow does: negative + noise x intensity, where the intensity comes
// from the stock's grain LUT (datasheet RMS granularity against density)
// and the noise is unit Gaussian scaled by pixels-per-mm x 0.001.
// The negative and intensity arrive colour-managed from sRGB colour cubes,
// so they are re-encoded to the cube values first and decoded back after.

namespace {
    float3 encode(float3 c) {
        float3 a = abs(c);
        float3 lo = 12.92 * a;
        float3 hi = 1.055 * pow(a, 1.0 / 2.4) - 0.055;
        return sign(c) * select(hi, lo, a <= 0.0031308);
    }
    float3 decode(float3 c) {
        float3 a = abs(c);
        float3 lo = a / 12.92;
        float3 hi = pow((a + 0.055) / 1.055, 2.4);
        return sign(c) * select(hi, lo, a <= 0.04045);
    }
}

extern "C" float4 filmGrain(coreimage::sample_t negative, coreimage::sample_t intensity,
                            coreimage::sample_t noise, float amount) {
    float3 n = encode(negative.rgb);
    float3 i = encode(intensity.rgb);
    float3 out = clamp(n + noise.rgb * amount * i, 0.0, 1.0);
    return float4(decode(out), negative.a);
}

// Natural lens falloff (cos^4 law) in linear light, applied to the scene
// before the film sees it. r is the distance from the centre on a 36 mm
// frame, f the lens focal length, both in mm: cos^4 = 1 / (1 + r^2/f^2)^2.
extern "C" float4 lensFalloff(coreimage::sample_t s, float2 center, float mmPerPixel,
                              float focal, coreimage::destination dest) {
    float2 d = (dest.coord() - center) * mmPerPixel / focal;
    float k = 1.0 + dot(d, d);
    return float4(s.rgb / (k * k), s.a);
}

// --- CCD texture -----------------------------------------------------------
// Measured on Imaging Resource's Sony DSC-T10 samples (see FilmRenderer):
// in-camera sharpening done on the encoded (sRGB) picture, then sensor noise.

// Puts sRGB-encoded values into the image, so blurs and sharpening act on
// the encoded picture, as a camera's JPEG engine does.
extern "C" float4 toEncoded(coreimage::sample_t s) {
    return float4(encode(s.rgb), s.a);
}

// base, near and wide are the encoded picture blurred by the lens/sensor
// sigma, and by the two unsharp-mask radii on top of it.
// lumaNoise.r and chromaNoise.rgb are unit-variance, already spatially
// correlated; chroma keeps only the difference between channels.
extern "C" float4 ccdTexture(coreimage::sample_t base, coreimage::sample_t near,
                             coreimage::sample_t wide, coreimage::sample_t lumaNoise,
                             coreimage::sample_t chromaNoise, float near_amount,
                             float wide_amount, float luma, float chroma) {
    float3 c = base.rgb + near_amount * (base.rgb - near.rgb) + wide_amount * (base.rgb - wide.rgb);
    float3 n = chromaNoise.rgb;
    float3 tint = (n - (n.r + n.g + n.b) / 3.0) * 1.2247449;   // 1/sqrt(2/3): unit variance
    c += lumaNoise.r * luma + tint * chroma;
    return float4(decode(clamp(c, 0.0, 1.0)), base.a);
}
