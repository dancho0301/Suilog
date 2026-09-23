//
//  TankShaders.metal
//  Suilog
//
//  マイ水槽用のシェーダー。
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// 生き物の体をうねらせる distortionEffect。
/// アセットはすべて右向き（左端が尾・右端が頭）なので、左ほど大きく動かす。
///
/// - bounds: ビューの矩形（.boundingRect）
/// - phase: 尾びれの位相（ラジアン）
/// - undulation: 縦方向の振幅（高さ比）
/// - sweep: 尾の左右スイープ量（幅比）
/// - wavelength: 体長あたりの波の数
[[ stitchable ]] float2 creatureSwim(float2 position,
                                     float4 bounds,
                                     float phase,
                                     float undulation,
                                     float sweep,
                                     float wavelength) {
    float2 size = bounds.zw;
    if (size.x <= 0.0 || size.y <= 0.0) {
        return position;
    }

    // 0: 尾（左端）〜 1: 頭（右端）
    float u = clamp((position.x - bounds.x) / size.x, 0.0, 1.0);
    // 頭側 3 割はほぼ動かさず、尾に向かって大きくする
    float weight = 1.0 - smoothstep(0.0, 0.72, u);
    weight *= weight;

    // 尾から頭へ伝わる進行波
    float wave = sin(phase - u * wavelength * 6.2831853);
    float dy = undulation * size.y * weight * wave;

    // 尾びれが手前・奥へ振れると、横からは尾が伸び縮みして見える
    float dx = sweep * size.x * weight * cos(phase);

    return float2(position.x + dx, position.y - dy);
}

/// 水面から差し込む光（コースティクス＋光の筋）を描く colorEffect。
/// plusLighter で背景に加算合成する前提で、乗算済みアルファの色を返す。
[[ stitchable ]] half4 tankLight(float2 position,
                                 half4 color,
                                 float4 bounds,
                                 float time,
                                 float intensity) {
    float2 size = bounds.zw;
    if (size.x <= 0.0 || size.y <= 0.0) {
        return half4(0.0h);
    }
    float2 local = position - bounds.xy;
    float v = local.y / size.y;                 // 0: 水面 〜 1: 底
    float2 uv = local / size.y;                 // 縦基準で正規化（横長でも模様が伸びない）

    // --- コースティクス（揺らめく網目状の光） ---
    const float tau = 6.2831853;
    float2 p = fmod(uv * tau * 0.9, float2(tau * 4.0)) - 250.0;
    float2 i = p;
    float c = 1.0;
    const float inten = 0.005;
    float t0 = time * 0.45 + 23.0;
    for (int n = 0; n < 4; n++) {
        float t = t0 * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + t) / inten),
                                 p.y / (cos(i.y + t) / inten)));
    }
    c /= 4.0;
    c = 1.17 - pow(c, 1.4);
    float caustic = clamp(pow(abs(c), 8.0), 0.0, 1.0);
    // 水面に近いほど強い
    caustic *= 1.0 - 0.7 * smoothstep(0.0, 1.0, v);

    // --- 光の筋（斜めに差し込み、ゆっくり揺れる） ---
    float x = uv.x + uv.y * 0.35;
    float rays = (0.5 + 0.5 * sin(x * 7.0 + time * 0.25))
               * (0.5 + 0.5 * sin(x * 3.1 - time * 0.17 + 1.3));
    rays = pow(rays, 3.0) * (1.0 - smoothstep(0.0, 0.85, v));

    float light = (caustic * 0.5 + rays * 0.45) * intensity;
    light = clamp(light, 0.0, 1.0);
    half3 tint = half3(0.9h, 0.97h, 1.0h);
    return half4(tint * half(light), half(light));
}
