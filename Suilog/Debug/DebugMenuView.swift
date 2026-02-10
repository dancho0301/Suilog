//
//  DebugMenuView.swift
//  Suilog
//
//  Created by Claude on 2026/02/10.
//

#if DEBUG
import SwiftUI
import SwiftData
import CoreLocation

struct DebugMenuView: View {
    @ObservedObject private var settings = DebugSettings.shared
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var aquariums: [Aquarium]
    @Query private var visitRecords: [VisitRecord]

    @State private var showingDeleteConfirmation = false

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

                // ダッシュボード（常時表示）
                dashboardSection

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

                    // データ操作
                    Section("データ操作") {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("訪問記録を全て削除", systemImage: "trash")
                        }
                        .disabled(visitRecords.isEmpty)
                    }

                    // 現在の状態
                    Section("デバッグ設定の状態") {
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
            .alert("訪問記録を全て削除しますか？", isPresented: $showingDeleteConfirmation) {
                Button("削除", role: .destructive) {
                    deleteAllVisitRecords()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("\(visitRecords.count)件の訪問記録が完全に削除されます。この操作は取り消せません。")
            }
        }
    }

    // MARK: - ダッシュボード

    private var dashboardSection: some View {
        Section("ダッシュボード") {
            LabeledContent("水族館") {
                Text("\(aquariums.count)件")
            }
            LabeledContent("訪問記録") {
                Text("\(visitRecords.count)件")
            }
            LabeledContent("訪問済み水族館") {
                let visitedCount = aquariums.filter { !$0.safeVisits.isEmpty }.count
                Text("\(visitedCount) / \(aquariums.count)")
            }
            LabeledContent("データバージョン") {
                let version = UserDefaults.standard.integer(forKey: "AquariumDataVersion")
                Text("v\(version)")
            }
            LabeledContent("現在位置") {
                if let location = locationManager.currentLocation {
                    Text("\(location.coordinate.latitude, specifier: "%.4f"), \(location.coordinate.longitude, specifier: "%.4f")")
                        .font(.caption)
                } else {
                    Text("取得中...")
                        .foregroundStyle(.secondary)
                }
            }
            LabeledContent("位置情報権限") {
                Text(authorizationStatusText)
                    .font(.caption)
            }
        }
    }

    // MARK: - Actions

    private func deleteAllVisitRecords() {
        for record in visitRecords {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    private var authorizationStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "未設定"
        case .restricted: return "制限あり"
        case .denied: return "拒否"
        case .authorizedAlways: return "常に許可"
        case .authorizedWhenInUse: return "使用中のみ"
        @unknown default: return "不明"
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
        .modelContainer(for: Aquarium.self, inMemory: true)
        .environmentObject(LocationManager())
}
#endif
