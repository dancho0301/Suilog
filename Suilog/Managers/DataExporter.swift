//
//  DataExporter.swift
//  Suilog
//
//  訪問記録をJSONファイルとして書き出すエクスポータ。
//  写真データはサイズの都合で含めない。
//

import Foundation

struct DataExporter {
    private struct ExportedVisit: Codable {
        let aquariumName: String
        let region: String
        let visitDate: Date
        let checkInType: String
        let memo: String
        let photoCount: Int
    }

    private struct ExportFile: Codable {
        let appName: String
        let exportedAt: Date
        let recordCount: Int
        let visitRecords: [ExportedVisit]
    }

    /// 訪問記録をJSONファイルとして一時ディレクトリに書き出し、ファイルURLを返す
    static func exportVisitRecords(_ records: [VisitRecord]) throws -> URL {
        let visits = records
            .sorted { $0.visitDate > $1.visitDate }
            .map { record in
                ExportedVisit(
                    aquariumName: record.aquarium?.name ?? "不明",
                    region: record.aquarium?.region ?? "",
                    visitDate: record.visitDate,
                    checkInType: record.checkInType.rawValue,
                    memo: record.memo,
                    photoCount: record.allPhotosData.count
                )
            }

        let file = ExportFile(
            appName: "Suilog",
            exportedAt: Date(),
            recordCount: visits.count,
            visitRecords: visits
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "suilog-visits-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
