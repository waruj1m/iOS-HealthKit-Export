import Foundation
import HealthKit

// MARK: - Export Format

enum ExportFormat: String, CaseIterable, Identifiable {
    case json  = "JSON"
    case csv   = "CSV"
    case xlsx  = "Excel"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv:  return "csv"
        case .xlsx: return "xlsx"
        }
    }
}

struct ExportRecord: Equatable {
    let type: String
    let date: String
    let value: Double
    let unit: String
    let source: String
}

enum ExportDocumentBuilder {
    static func makeJSON(records: [ExportRecord], startDate: Date, endDate: Date) throws -> Data {
        var byType: [String: [[String: Any]]] = [:]
        for r in records {
            byType[r.type, default: []].append(["date": r.date, "value": r.value, "unit": r.unit, "source": r.source])
        }
        let payload: [String: Any] = [
            "exportDate":       ISO8601DateFormatter().string(from: endDate),
            "exportVersion":    "2.0",
            "deduplication":    "cumulative metrics use daily HealthKit statistics (Watch+iPhone deduplicated)",
            "dateRange":        ["start": ISO8601DateFormatter().string(from: startDate),
                                 "end":   ISO8601DateFormatter().string(from: endDate)],
            "dataTypes":        byType
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    static func makeCSV(records: [ExportRecord]) -> Data {
        var csv = "type,date,value,unit,source\n"
        for r in records.sorted(by: { $0.date < $1.date }) {
            func q(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            csv += "\(q(r.type)),\(q(r.date)),\(r.value),\(q(r.unit)),\(q(r.source))\n"
        }
        return csv.data(using: .utf8) ?? Data()
    }

    static func makeXLSX(records: [ExportRecord]) -> Data {
        let types = Array(Set(records.map { $0.type })).sorted()

        var overview: [[String]] = [["Type", "Date", "Value", "Unit", "Source"]]
        for r in records.sorted(by: { $0.date < $1.date }) {
            overview.append([r.type, r.date, String(r.value), r.unit, r.source])
        }

        var sheets: [(name: String, rows: [[String]])] = [("All Data", overview)]

        for type in types {
            let rows = [["Date", "Value", "Unit", "Source"]] +
                records.filter { $0.type == type }
                    .sorted { $0.date < $1.date }
                    .map { [$0.date, String($0.value), $0.unit, $0.source] }
            sheets.append((String(type.prefix(31)), rows))
        }

        return buildXLSX(sheets: sheets)
    }

    private static func buildXLSX(sheets: [(name: String, rows: [[String]])]) -> Data {
        var entries: [(name: String, data: Data)] = []

        var allStrings: [String] = []
        var stringIndex: [String: Int] = [:]
        func sid(_ s: String) -> Int {
            if let i = stringIndex[s] { return i }
            let i = allStrings.count; allStrings.append(s); stringIndex[s] = i; return i
        }

        var sheetXMLs: [Data] = []
        for sheet in sheets {
            var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
            xml += "<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData>"
            for (rowIdx, row) in sheet.rows.enumerated() {
                xml += "<row r=\"\(rowIdx + 1)\">"
                for (colIdx, cell) in row.enumerated() {
                    let ref = "\(xlsxCol(colIdx))\(rowIdx + 1)"
                    if let _ = Double(cell), !cell.isEmpty {
                        xml += "<c r=\"\(ref)\"><v>\(xmlEsc(cell))</v></c>"
                    } else {
                        xml += "<c r=\"\(ref)\" t=\"s\"><v>\(sid(cell))</v></c>"
                    }
                }
                xml += "</row>"
            }
            xml += "</sheetData></worksheet>"
            sheetXMLs.append(Data(xml.utf8))
        }

        var overrides = ""
        for (i, _) in sheets.enumerated() {
            overrides += "<Override PartName=\"/xl/worksheets/sheet\(i+1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        entries.append(("[Content_Types].xml", Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            \(overrides)
            <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
            <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
            </Types>
            """.utf8)))

        entries.append(("_rels/.rels", Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            </Relationships>
            """.utf8)))

        var sheetTags = ""
        for (i, s) in sheets.enumerated() { sheetTags += "<sheet name=\"\(xmlEsc(s.name))\" sheetId=\"\(i+1)\" r:id=\"rId\(i+1)\"/>" }
        entries.append(("xl/workbook.xml", Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <sheets>\(sheetTags)</sheets></workbook>
            """.utf8)))

        var wbRels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        for (i, _) in sheets.enumerated() {
            wbRels += "<Relationship Id=\"rId\(i+1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i+1).xml\"/>"
        }
        wbRels += "<Relationship Id=\"rId\(sheets.count+1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings\" Target=\"sharedStrings.xml\"/>"
        wbRels += "</Relationships>"
        entries.append(("xl/_rels/workbook.xml.rels", Data(wbRels.utf8)))

        for (i, data) in sheetXMLs.enumerated() { entries.append(("xl/worksheets/sheet\(i+1).xml", data)) }

        var ssXML = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"\(allStrings.count)\" uniqueCount=\"\(allStrings.count)\">"
        for s in allStrings { ssXML += "<si><t>\(xmlEsc(s))</t></si>" }
        ssXML += "</sst>"
        entries.append(("xl/sharedStrings.xml", Data(ssXML.utf8)))

        entries.append(("xl/styles.xml", Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
            <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
            <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
            <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
            <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
            </styleSheet>
            """.utf8)))

        return buildZIP(entries: entries)
    }

    private static func xlsxCol(_ index: Int) -> String {
        var result = ""; var n = index
        repeat { result = String(UnicodeScalar(65 + n % 26)!) + result; n = n / 26 - 1 } while n >= 0
        return result
    }

    private static func xmlEsc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func buildZIP(entries: [(name: String, data: Data)]) -> Data {
        var archive = Data(); var central = Data(); var offsets: [UInt32] = []

        for entry in entries {
            let nameBytes = Data(entry.name.utf8)
            let crc       = crc32(entry.data)
            offsets.append(UInt32(archive.count))

            archive += le32(0x04034b50); archive += le16(20);   archive += le16(0)
            archive += le16(0);          archive += le16(0);    archive += le16(0)
            archive += le32(crc);        archive += le32(UInt32(entry.data.count))
            archive += le32(UInt32(entry.data.count))
            archive += le16(UInt16(nameBytes.count)); archive += le16(0)
            archive += nameBytes; archive += entry.data
        }

        let cdOffset = UInt32(archive.count)
        for (i, entry) in entries.enumerated() {
            let nameBytes = Data(entry.name.utf8)
            let crc       = crc32(entry.data)
            central += le32(0x02014b50); central += le16(20); central += le16(20)
            central += le16(0);          central += le16(0);  central += le16(0); central += le16(0)
            central += le32(crc);        central += le32(UInt32(entry.data.count)); central += le32(UInt32(entry.data.count))
            central += le16(UInt16(nameBytes.count)); central += le16(0); central += le16(0)
            central += le16(0); central += le16(0); central += le32(0); central += le32(offsets[i])
            central += nameBytes
        }

        archive += central
        archive += le32(0x06054b50); archive += le16(0); archive += le16(0)
        archive += le16(UInt16(entries.count)); archive += le16(UInt16(entries.count))
        archive += le32(UInt32(central.count)); archive += le32(cdOffset)
        archive += le16(0)
        return archive
    }

    private static func le16(_ v: UInt16) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 2) }
    private static func le32(_ v: UInt32) -> Data { var x = v.littleEndian; return Data(bytes: &x, count: 4) }

    private static func crc32(_ data: Data) -> UInt32 {
        let table: [UInt32] = (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1 }
            return c
        }
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Service

struct HealthExportService {
    private let healthStore: HKHealthStore
    private let exportFolderName       = "iOSHealthBridge"
    private let healthExportsSubfolder = "HealthExports"

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Public API

    func generateExportData(format: ExportFormat = .json) async throws -> (Data, String) {
        let endDate   = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        let records = await fetchAllRecords(from: startDate, to: endDate)

        let dateFormatter        = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName             = "health_export_\(dateFormatter.string(from: endDate)).\(format.fileExtension)"

        switch format {
        case .json:
            return (try ExportDocumentBuilder.makeJSON(records: records, startDate: startDate, endDate: endDate), fileName)
        case .csv:
            return (ExportDocumentBuilder.makeCSV(records: records), fileName)
        case .xlsx:
            return (ExportDocumentBuilder.makeXLSX(records: records), fileName)
        }
    }

    func exportToiCloud(format: ExportFormat = .json) async throws {
        let containerURL = await Task.detached {
            FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.PolyphasicDevs.iOS-Health-Bridge")
                ?? FileManager.default.url(forUbiquityContainerIdentifier: nil)
        }.value

        guard let containerURL else { throw HealthBridgeError.iCloudUnavailable }

        let (data, fileName) = try await generateExportData(format: format)
        let exportBaseURL = containerURL
            .appendingPathComponent("Documents")
            .appendingPathComponent(exportFolderName)
            .appendingPathComponent(healthExportsSubfolder)

        try FileManager.default.createDirectory(at: exportBaseURL, withIntermediateDirectories: true)
        try await coordinateWrite(to: exportBaseURL.appendingPathComponent(fileName), data: data)
    }

    func exportToFolder(_ folderURL: URL, format: ExportFormat = .json) async throws {
        let (data, fileName) = try await generateExportData(format: format)
        try await coordinateWrite(to: folderURL.appendingPathComponent(fileName), data: data)
    }

    // MARK: - Fetch (Deduplicated)

    private func fetchAllRecords(from startDate: Date, to endDate: Date) async -> [ExportRecord] {
        // Cumulative metrics: use daily HKStatisticsCollectionQuery.
        // This is the ONLY correct way to avoid Watch+iPhone double-counting —
        // HealthKit resolves overlapping sources internally before summing.
        async let steps    = queryDailyStats(.stepCount,              unit: .count(),                  options: .cumulativeSum,    label: "stepCount",              unitLabel: "steps",  start: startDate, end: endDate)
        async let distance = queryDailyStats(.distanceWalkingRunning, unit: .meter(),                  options: .cumulativeSum,    label: "distanceWalkingRunning", unitLabel: "m",      start: startDate, end: endDate)
        async let energy   = queryDailyStats(.activeEnergyBurned,     unit: .kilocalorie(),            options: .cumulativeSum,    label: "activeEnergyBurned",     unitLabel: "kcal",   start: startDate, end: endDate)

        // Discrete metrics: raw samples are safe (only one device records each measurement).
        async let hr        = queryRawSamples(.heartRate,        unit: HKUnit(from: "count/min"), label: "heartRate",        unitLabel: "bpm",  start: startDate, end: endDate)
        async let restingHR = queryRawSamples(.restingHeartRate, unit: HKUnit(from: "count/min"), label: "restingHeartRate", unitLabel: "bpm",  start: startDate, end: endDate)
        async let o2        = queryRawSamples(.oxygenSaturation, unit: .percent(),               label: "oxygenSaturation", unitLabel: "%",    start: startDate, end: endDate)
        async let resp      = queryRawSamples(.respiratoryRate,  unit: HKUnit(from: "count/min"), label: "respiratoryRate",  unitLabel: "brpm", start: startDate, end: endDate)
        async let mass      = queryRawSamples(.bodyMass,         unit: .gramUnit(with: .kilo),    label: "bodyMass",         unitLabel: "kg",   start: startDate, end: endDate)
        async let height    = queryRawSamples(.height,           unit: .meter(),                  label: "height",           unitLabel: "m",    start: startDate, end: endDate)

        async let sleep    = querySleepRecords(start: startDate, end: endDate)
        async let mindful  = queryMindfulRecords(start: startDate, end: endDate)
        async let workouts = queryWorkoutRecords(start: startDate, end: endDate)

        return await [steps, distance, energy, hr, restingHR, o2, resp, mass, height, sleep, mindful, workouts]
            .flatMap { $0 }
    }

    // MARK: - HealthKit Queries

    /// Daily statistics — HealthKit automatically deduplicates overlapping sources (e.g. Watch + iPhone steps)
    private func queryDailyStats(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        label: String,
        unitLabel: String,
        start: Date,
        end: Date
    ) async -> [ExportRecord] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }

        return await withCheckedContinuation { continuation in
            let predicate  = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let anchorDate = Calendar.current.startOfDay(for: end)

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results = results else { continuation.resume(returning: []); return }

                var records: [ExportRecord] = []
                results.enumerateStatistics(from: start, to: end) { stats, _ in
                    guard let qty = stats.sumQuantity() ?? stats.averageQuantity() else { return }
                    let value = qty.doubleValue(for: unit)
                    guard value > 0 else { return }
                    records.append(ExportRecord(
                        type:   label,
                        date:   ISO8601DateFormatter().string(from: stats.startDate),
                        value:  value,
                        unit:   unitLabel,
                        source: "HealthKit"
                    ))
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }

    /// Raw sample query for point-in-time discrete metrics
    private func queryRawSamples(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        label: String,
        unitLabel: String,
        start: Date,
        end: Date
    ) async -> [ExportRecord] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample] else { continuation.resume(returning: []); return }
                let records = samples.map {
                    ExportRecord(type: label, date: ISO8601DateFormatter().string(from: $0.startDate),
                                 value: $0.quantity.doubleValue(for: unit), unit: unitLabel,
                                 source: $0.sourceRevision.source.name)
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }

    private func querySleepRecords(start: Date, end: Date) async -> [ExportRecord] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: sleepType, predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else { continuation.resume(returning: []); return }
                let stageLabels: [Int: String] = [0: "inBed", 1: "asleepUnspecified", 2: "awake",
                                                   3: "asleepCore", 4: "asleepDeep", 5: "asleepREM"]
                let records = samples.map {
                    ExportRecord(type: "sleepAnalysis",
                                 date: ISO8601DateFormatter().string(from: $0.startDate),
                                 value: $0.endDate.timeIntervalSince($0.startDate) / 3600,
                                 unit: stageLabels[$0.value] ?? "unknown",
                                 source: $0.sourceRevision.source.name)
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }

    private func queryMindfulRecords(start: Date, end: Date) async -> [ExportRecord] {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return [] }

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: mindfulType, predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else { continuation.resume(returning: []); return }
                let records = samples.map {
                    ExportRecord(type: "mindfulSession",
                                 date: ISO8601DateFormatter().string(from: $0.startDate),
                                 value: $0.endDate.timeIntervalSince($0.startDate) / 60,
                                 unit: "minutes",
                                 source: $0.sourceRevision.source.name)
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }

    private func queryWorkoutRecords(start: Date, end: Date) async -> [ExportRecord] {
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(), predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else { continuation.resume(returning: []); return }
                let records = workouts.map {
                    ExportRecord(type: "workout",
                                 date: ISO8601DateFormatter().string(from: $0.startDate),
                                 value: $0.duration / 60,
                                 unit: "minutes",
                                 source: $0.sourceRevision.source.name)
                }
                continuation.resume(returning: records)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Coordinate Write

    private func coordinateWrite(to url: URL, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
                do    { try data.write(to: url); cont.resume() }
                catch { cont.resume(throwing: error) }
            }
            if let error = coordinationError { cont.resume(throwing: error) }
        }
    }
}
