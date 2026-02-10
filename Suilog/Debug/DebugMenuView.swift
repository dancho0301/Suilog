//
//  DebugMenuView.swift
//  Suilog
//
//  Created by Claude on 2026/02/10.
//

#if DEBUG
import SwiftUI

struct DebugMenuView: View {
    @ObservedObject private var settings = DebugSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // マスタースイッチ
                Section {
                    Toggle("デバッグモードを有効にする", isOn: $settings.isDebugModeEnabled)
                } header: {
                    Text("デバッグモード")
                } footer: {
                    Text("ONにすると各デバッグ機能が有効になります")
                }

                if settings.isDebugModeEnabled {
                    // チェックイン設定
                    Section("チェックイン") {
                        Toggle("常時チェックイン可能", isOn: $settings.alwaysAllowCheckIn)

                        if !settings.alwaysAllowCheckIn {
                            Toggle("カスタム距離閾値を使用", isOn: $settings.useCustomRadius)

                            if settings.useCustomRadius {
                                VStack(alignment: .leading) {
                                    Text("距離閾値: \(formatDistance(settings.customRadius))")
                                        .font(.subheadline)
                                    Slider(
                                        value: $settings.customRadius,
                                        in: 100...100_000,
                                        step: 100
                                    )
                                }
                            }
                        }
                    }

                    // 位置偽装
                    Section("位置偽装") {
                        Toggle("位置を偽装する", isOn: $settings.useFakeLocation)

                        if settings.useFakeLocation {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("緯度: \(settings.fakeLatitude, specifier: "%.4f")")
                                    .font(.subheadline)
                                Text("経度: \(settings.fakeLongitude, specifier: "%.4f")")
                                    .font(.subheadline)
                            }

                            // プリセット選択
                            ForEach(DebugLocationPreset.presets) { preset in
                                Button {
                                    settings.fakeLatitude = preset.latitude
                                    settings.fakeLongitude = preset.longitude
                                } label: {
                                    HStack {
                                        Text(preset.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if settings.fakeLatitude == preset.latitude
                                            && settings.fakeLongitude == preset.longitude {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 現在の状態
                    Section("現在の状態") {
                        LabeledContent("常時チェックイン") {
                            statusBadge(settings.isAlwaysAllowCheckInActive)
                        }
                        LabeledContent("カスタム距離閾値") {
                            if settings.isCustomRadiusActive {
                                Text(formatDistance(settings.effectiveRadius))
                                    .foregroundStyle(.green)
                            } else {
                                Text("OFF")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("位置偽装") {
                            statusBadge(settings.isFakeLocationActive)
                        }
                    }
                }
            }
            .navigationTitle("デバッグメニュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }

    @ViewBuilder
    private func statusBadge(_ isActive: Bool) -> some View {
        Text(isActive ? "ON" : "OFF")
            .foregroundStyle(isActive ? .green : .secondary)
    }
}

#Preview {
    DebugMenuView()
}
#endif
